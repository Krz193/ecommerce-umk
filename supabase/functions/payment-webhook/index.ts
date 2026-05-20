import {serve} from "https://deno.land/std@0.224.0/http/server.ts";
import {createClient} from "https://esm.sh/@supabase/supabase-js@2";

/**
 * Generate Midtrans webhook signature
 */
async function generateSignature(
    orderId : string,
    statusCode : string,
    grossAmount : string,
    serverKey : string,
) {
    const input = orderId + statusCode + grossAmount + serverKey;

    const encoded = new TextEncoder().encode(input);

    const hashBuffer = await crypto
        .subtle
        .digest("SHA-512", encoded,);

    return Array
        .from(new Uint8Array(hashBuffer))
        .map((b) => b.toString(16).padStart(2, "0"))
        .join("");
}

serve(async (req) => {
    try {
        /**
         * Only allow POST webhook requests
         */
        if (req.method !== "POST") {
            return new Response(JSON.stringify({error: "Method not allowed"}), {
                status: 405,
                headers: {
                    "Content-Type": "application/json"
                }
            },);
        }

        /**
         * Environment configuration
         */
        const MIDTRANS_SERVER_KEY = Deno
            .env
            .get("MIDTRANS_SERVER_KEY",)!;

        /**
         * Service-role Supabase client
         *
         * Webhook must bypass user-scoped RLS
         * because payment settlement is trusted
         * server-side infrastructure.
         */
        const supabase = createClient(
            Deno.env.get("SUPABASE_URL")!,
            Deno.env.get("SUPABASE_SERVICE_ROLE_KEY",)!,
        );

        /**
         * Parse webhook payload
         */
        const body = await req.json();

        const {order_id, transaction_id, status_code, gross_amount, signature_key} = body;

        console.log(
            "Has service role key:",
            !!Deno.env.get("SUPABASE_SERVICE_ROLE_KEY",),
        );

        console.log("Webhook payload:", body,);

        /**
         * Required webhook payload validation
         *
         * Prevent malformed or incomplete
         * webhook payloads from entering
         * transactional lifecycle flow.
         */
        if (!order_id || !transaction_id || !status_code || !gross_amount || !signature_key) {
            return new Response(JSON.stringify({error: "Invalid payload"}), {
                status: 400,
                headers: {
                    "Content-Type": "application/json"
                }
            },);
        }

        /**
         * Generate webhook signature
         */
        const generatedSignature = await generateSignature(
            order_id,
            status_code,
            gross_amount,
            MIDTRANS_SERVER_KEY,
        );

        /**
         * Verify Midtrans webhook signature
         *
         * Reject spoofed or tampered
         * webhook payloads before
         * transactional mutation flow.
         */
        if (generatedSignature !== signature_key) {
            return new Response(JSON.stringify({error: "Invalid signature"}), {
                status: 401,
                headers: {
                    "Content-Type": "application/json"
                }
            },);
        }

        console.log("Signature verified",);

        /**
         * Lookup payment transaction
         */
        const {data: payment, error: paymentError} = await supabase
            .from("payments")
            .select(
                `
                *,
                order:orders (
                    *
                )
            `
            )
            .eq("provider_transaction_id", transaction_id,)
            .single();

        console.log("Webhook payment:", payment,);
        if (paymentError) {
            console.error("Webhook payment error:", paymentError,);
        }

        if (!payment) {
            return new Response(JSON.stringify({error: "Payment not found"}), {
                status: 404,
                headers: {
                    "Content-Type": "application/json"
                }
            },);
        }

        /**
         * Idempotency guard
         *
         * Prevent duplicate settlement replay
         * from mutating payment/order/stock
         * multiple times.
         */
        if (payment.status === "paid" && body.transaction_status === "settlement") {
            console.log("Skipping duplicate settlement webhook",);

            return new Response(
                JSON.stringify({success: true, message: "Duplicate settlement ignored"}),
                {
                    status: 200,
                    headers: {
                        "Content-Type": "application/json"
                    }
                },
            );
        }

        console.log("Midtrans transaction status:", body.transaction_status,);

        /**
         * Load immutable order snapshot items
         *
         * Inventory lifecycle MUST use
         * order_items instead of cart_items.
         */
        const {data: orderItems, error: orderItemsError} = await supabase
            .from(
                "order_items"
            )
            .select(`
                *
            `)
            .eq("order_id", payment.order.id,);

        console.log("Webhook order items:", orderItems,);
        if (orderItemsError) {
            console.error("Webhook order items error:", orderItemsError,);
        }

        if (!orderItems || orderItems.length === 0) {
            return new Response(JSON.stringify({error: "Order items not found"}), {
                status: 404,
                headers: {
                    "Content-Type": "application/json"
                }
            },);
        }

        /**
         * Payment lifecycle mapping
         */
        let paymentStatus = payment.status;

        let orderPaymentStatus = payment.order.payment_status;

        let orderStatus = payment.order.status;

        if (body.transaction_status === "settlement") {
            paymentStatus = "paid";
            orderPaymentStatus = "paid";
            orderStatus = "processing";
        }

        if (body.transaction_status === "expire") {
            paymentStatus = "expired";
            orderPaymentStatus = "expired";
            orderStatus = "cancelled";
        }

        if (body.transaction_status === "cancel") {
            paymentStatus = "failed";
            orderPaymentStatus = "failed";
            orderStatus = "cancelled";
        }

        /**
         * Inventory deduction lifecycle
         *
         * Only deduct inventory after
         * successful settlement.
         */
        if (body.transaction_status === "settlement") {
            for (const item of orderItems) {
                const {data: product, error: productError} = await supabase
                    .from("products")
                    .select(
                        `
                        id,
                        stock
                    `
                    )
                    .eq("id", item.product_id,)
                    .single();

                console.log("Webhook product:", product,);
                if (productError) {
                    console.error("Webhook product error:", productError,);
                }

                if (!product) {
                    continue;
                }

                if (product.stock < item.quantity) {
                    console.warn("Insufficient stock during webhook settlement", {
                        product_id: product.id,
                        current_stock: product.stock,
                        requested_quantity: item.quantity
                    },);

                    continue;
                }

                const newStock = product.stock - item.quantity;

                const {data: updatedProduct, error: updatedProductError} = await supabase
                    .from(
                        "products"
                    )
                    .update({stock: newStock})
                    .eq("id", product.id,)
                    .select()
                    .single();

                console.log("Updated product stock:", updatedProduct,);

                if (updatedProductError) {
                    console.error("Updated product stock error:", updatedProductError,);
                }
            }

            /**
             * Cleanup cart items
             *
             * Cart container survives.
             * Only purchased cart_items
             * are removed after settlement.
             */
            const {data: cart, error: cartError} = await supabase
                .from("carts")
                .select(`
                    id
                `)
                .eq("user_id", payment.order.user_id,)
                .eq("store_id", payment.order.store_id,)
                .single();

            console.log("Webhook cart:", cart,);
            if (cartError) {
                console.error("Webhook cart error:", cartError,);
            }

            if (cart) {
                const {error: deleteCartItemsError} = await supabase
                    .from("cart_items")
                    .delete()
                    .eq("cart_id", cart.id,);

                if (deleteCartItemsError) {
                    console.error("Delete cart items error:", deleteCartItemsError,);
                }
            }
        }

        /**
         * Update payment lifecycle state
         */
        const {data: updatedPayment, error: updatedPaymentError} = await supabase
            .from(
                "payments"
            )
            .update({
                status: paymentStatus,

                paid_at: paymentStatus === "paid"
                    ? new Date().toISOString()
                    : null,

                raw_response: body
            })
            .eq("id", payment.id)
            .select()
            .single();

        console.log("Updated webhook payment:", updatedPayment,);
        if (updatedPaymentError) {
            console.error("Updated webhook payment error:", updatedPaymentError,);
        }

        /**
         * Update order payment state
         */
        const {data: updatedOrder, error: updatedOrderError} = await supabase
            .from(
                "orders"
            )
            .update({
                status: orderStatus,

                payment_status: orderPaymentStatus,

                paid_at: paymentStatus === "paid"
                    ? new Date().toISOString()
                    : null
            })
            .eq("id", payment.order.id,)
            .select()
            .single();

        console.log("Updated webhook order:", updatedOrder,);
        if (updatedOrderError) {
            console.error("Updated webhook order error:", updatedOrderError,);
        }

        /**
         * Webhook success response
         */
        return new Response(
            JSON.stringify({success: true, payment: updatedPayment, order: updatedOrder}),
            {
                status: 200,
                headers: {
                    "Content-Type": "application/json"
                }
            },
        );
    } catch (error) {
        console.error(error);

        return new Response(JSON.stringify({error: "Internal server error"}), {
            status: 500,
            headers: {
                "Content-Type": "application/json"
            }
        },);
    }
});