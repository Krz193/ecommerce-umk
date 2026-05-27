import {serve} from "https://deno.land/std@0.224.0/http/server.ts";
import {createClient} from "https://esm.sh/@supabase/supabase-js@2";
import {createMidtransTransaction} from "./midtrans.ts";

serve(async (req) => {
    try {
        // Only allow POST
        if (req.method !== "POST") {
            return new Response(JSON.stringify({error: "Method not allowed"}), {
                status: 405,
                headers: {
                    "Content-Type": "application/json"
                }
            },);
        }

        // Create Supabase client
        const supabase = createClient(
            Deno.env.get("SUPABASE_URL")!,
            Deno.env.get("SUPABASE_ANON_KEY")!,
            {
                global: {
                    headers: {
                        Authorization: req
                            .headers
                            .get("Authorization") ?? ""
                    }
                }
            },
        );

        // Get authenticated user
        const {data: {
                user
            }, error: authError} = await supabase
            .auth
            .getUser();

        if (authError || !user) {
            return new Response(JSON.stringify({error: "Unauthorized"}), {
                status: 401,
                headers: {
                    "Content-Type": "application/json"
                }
            },);
        }

        // Parse request body
        const body = await req.json();

        const {cart_id, address_id} = body;

        // Validate required fields
        if (!cart_id || !address_id) {
            return new Response(
                JSON.stringify({error: "cart_id and address_id are required"}),
                {
                    status: 400,
                    headers: {
                        "Content-Type": "application/json"
                    }
                },
            );
        }

        console.log("Authenticated user:", user.id);
        console.log("Requested cart:", cart_id);

        // Fetch cart
        const {data: cart, error: cartError} = await supabase
            .from("carts")
            .select(
                `
                id,
                user_id,
                store_id
            `
            )
            .eq("id", cart_id)
            .single();

        console.log("Cart query result:", cart);
        console.error("Cart query error:", cartError);

        if (cartError || !cart) {
            return new Response(JSON.stringify({error: "Cart not found"}), {
                status: 404,
                headers: {
                    "Content-Type": "application/json"
                }
            },);
        }

        // Validate cart ownership
        if (cart.user_id !== user.id) {
            return new Response(JSON.stringify({error: "Forbidden cart access"}), {
                status: 403,
                headers: {
                    "Content-Type": "application/json"
                }
            },);
        }

        // Prevent duplicate pending payment
        const now =
            new Date().toISOString();

        const {
            data: existingPendingPayment,
        } = await supabase
            .from('payments')
            .select(`
                id,
                order_id,
                status,
                expired_at,
                orders (
                    id
                )
            `)
            .eq('status', 'pending')
            .gt('expired_at', now)
            .order('created_at', {
                ascending: false,
            })
            .limit(1)
            .maybeSingle();

        if (
            existingPendingPayment &&
            existingPendingPayment.orders
        ) {

            return new Response(
                JSON.stringify({
                    error:
                        "You still have pending payment",

                    order_id:
                        existingPendingPayment
                            .orders
                            .id,
                }),
                {
                    status: 400,
                    headers: {
                        "Content-Type":
                            "application/json",
                    },
                },
            );
        }

        // Fetch cart items
        const {data: cartItems, error: cartItemsError} = await supabase
            .from(
                "cart_items"
            )
            .select(
                `
                id,
                quantity,
                product:products (
                    id,
                    name,
                    price,
                    stock,
                    status,
                    store_id,
                    product_images (
                        image_url,
                        sort_order
                    )
                )
            `
            )
            .eq("cart_id", cart.id);

        console.log("Cart items:", cartItems);
        console.error("Cart items error:", cartItemsError);

        if (cartItemsError) {
            return new Response(JSON.stringify({error: "Failed to fetch cart items"}), {
                status: 500,
                headers: {
                    "Content-Type": "application/json"
                }
            },);
        }

        // Validate empty cart
        if (!cartItems || cartItems.length === 0) {
            return new Response(JSON.stringify({error: "Cart is empty"}), {
                status: 400,
                headers: {
                    "Content-Type": "application/json"
                }
            },);
        }

        // Validate products
        for (const item of cartItems) {
            const product = item.product;

            if (!product) {
                return new Response(JSON.stringify({error: "Product not found"}), {
                    status: 400,
                    headers: {
                        "Content-Type": "application/json"
                    }
                },);
            }

            if (product.status !== "published") {
                return new Response(
                    JSON.stringify({error: `Product ${product.name} is unavailable`}),
                    {
                        status: 400,
                        headers: {
                            "Content-Type": "application/json"
                        }
                    },
                );
            }

            if (product.stock < item.quantity) {
                return new Response(
                    JSON.stringify({error: `Insufficient stock for ${product.name}`}),
                    {
                        status: 400,
                        headers: {
                            "Content-Type": "application/json"
                        }
                    },
                );
            }

            // Validate single-store consistency
            if (product.store_id !== cart.store_id) {
                return new Response(
                    JSON.stringify({error: "Cross-store checkout is not allowed"}),
                    {
                        status: 400,
                        headers: {
                            "Content-Type": "application/json"
                        }
                    },
                );
            }
        }

        // Calculate totals
        let subtotal = 0;

        for (const item of cartItems) {
            subtotal += Number(item.product.price) * item.quantity;
        }

        const shippingCost = 0;
        const applicationFee = 0;

        const totalAmount = subtotal + shippingCost + applicationFee;

        console.log("Subtotal:", subtotal);
        console.log("Shipping cost:", shippingCost);
        console.log("Application fee:", applicationFee);
        console.log("Total amount:", totalAmount);

        // Fetch address
        const {data: address, error: addressError} = await supabase
            .from("addresses")
            .select(
                `
                    id,
                    user_id,
                    recipient_name,
                    recipient_phone,
                    city,
                    postal_code,
                    full_address
                `
            )
            .eq("id", address_id)
            .single();

        console.log("Address:", address);
        console.error("Address error:", addressError);

        if (addressError || !address) {
            return new Response(JSON.stringify({error: "Address not found"}), {
                status: 404,
                headers: {
                    "Content-Type": "application/json"
                }
            },);
        }

        // Validate address ownership
        if (address.user_id !== user.id) {
            return new Response(JSON.stringify({error: "Forbidden address access"}), {
                status: 403,
                headers: {
                    "Content-Type": "application/json"
                }
            },);
        }

        // Generate temporary order number
        const orderNumber = `ORD-${Date.now()}`;

        console.log("Order number:", orderNumber);

        // Create order
        const {data: order, error: orderError} = await supabase
            .from("orders")
            .insert({
                user_id: user.id,
                store_id: cart.store_id,
                order_number: orderNumber,

                status: "pending",
                payment_status: "pending",

                subtotal: subtotal,
                shipping_cost: shippingCost,
                application_fee: applicationFee,
                total_amount: totalAmount,

                shipping_name: address.recipient_name,
                shipping_phone: address.recipient_phone,
                shipping_address: address.full_address,
                shipping_city: address.city,
                shipping_postal_code: address.postal_code
            })
            .select()
            .single();

        console.log("Order:", order);
        console.error("Order error:", orderError);

        if (orderError || !order) {
            return new Response(JSON.stringify({error: "Failed to create order"}), {
                status: 500,
                headers: {
                    "Content-Type": "application/json"
                }
            },);
        }

        // Create order items snapshot
        const orderItemsPayload =
            cartItems.map((item) => {

                const thumbnail =
                    item.product.product_images
                        ?.sort(
                            (a, b) =>
                                a.sort_order -
                                b.sort_order,
                        )?.[0]
                        ?.image_url ?? null;

                return {
                    order_id: order.id,
                    product_id: item.product.id,
                    product_name: item.product.name,
                    product_price: item.product.price,
                    quantity: item.quantity,
                    subtotal:
                        Number(
                            item.product.price,
                        ) * item.quantity,
                    product_thumbnail: thumbnail,
                };
            });

        console.log("Order items payload:", orderItemsPayload,);

        const {data: orderItems, error: orderItemsError} = await supabase
            .from(
                "order_items"
            )
            .insert(orderItemsPayload)
            .select();

        console.log("Order items:", orderItems);
        console.error("Order items error:", orderItemsError,);

        if (orderItemsError) {
            await supabase
                .from("orders")
                .delete()
                .eq("id", order.id);

            return new Response(JSON.stringify({error: "Failed to create order items"}), {
                status: 500,
                headers: {
                    "Content-Type": "application/json"
                }
            },);
        }

        // Create payment record
        const {data: payment, error: paymentError} = await supabase
            .from("payments")
            .insert({
                order_id: order.id,

                provider: "midtrans",

                status: "pending",

                amount: totalAmount,

                expired_at: new Date(Date.now() + 1000 * 60 * 15).toISOString()
            })
            .select()
            .single();

        console.log("Payment:", payment);
        console.error("Payment error:", paymentError,);

        if (paymentError || !payment) {
            await supabase
                .from("order_items")
                .delete()
                .eq("order_id", order.id);

            await supabase
                .from("orders")
                .delete()
                .eq("id", order.id);

            return new Response(
                JSON.stringify({
                    error: "Failed to create payment",
                }),
                {
                    status: 500,
                    headers: {
                        "Content-Type": "application/json",
                    },
                },
            );
        }

        const nowTime = new Date();
        const jakartaTime = new Date(
            nowTime.getTime() + (7 * 60 * 60 * 1000)
        );

        const formattedOrderTime =
            jakartaTime
                .toISOString()
                    .replace('T', ' ')
                    .replace(/\.\d{3}Z$/, ' +0700');

        console.log("midtrans payload order time:", formattedOrderTime);

        const paymentPayload = {
            payment_type: "bank_transfer",

            transaction_details: {
                order_id: order.order_number,
                gross_amount: Number(order.total_amount)
            },

            custom_expiry: {
                order_time: formattedOrderTime,

                expiry_duration: 60,

                unit: 'minute',
            },

            customer_details: {
                first_name: address.recipient_name,
                phone: address.recipient_phone
            },

            item_details: cartItems.map((item) => ({
                id: item.product.id,
                name: item.product.name,
                price: Number(item.product.price),
                quantity: item.quantity
            }))
        };

        console.log(
            JSON.stringify(
                paymentPayload,
                null,
                2,
            ),
        );

        const midtransResult = await createMidtransTransaction(paymentPayload);

        console.log("Midtrans response:", midtransResult);

        if (!midtransResult.ok) {

            await supabase
                .from("payments")
                .update({
                    status: "failed",
                })
                .eq("id", payment.id);

            await supabase
                .from("orders")
                .update({
                    status: "cancelled",
                    payment_status: "failed",
                })
                .eq("id", order.id);

            return new Response(
                JSON.stringify({
                    error: "Failed to create Midtrans transaction",
                    midtrans: midtransResult.data,
                }),
                {
                    status: 500,
                    headers: {
                        "Content-Type": "application/json",
                    },
                },
            );
        }

        const {
            transaction_id,
            expiry_time,
        } = midtransResult.data;

        const {
            data: updatedPayment,
            error: paymentUpdateError,
        } = await supabase
            .from("payments")
            .update({
                provider_transaction_id: transaction_id,
                raw_response: midtransResult.data,
                expired_at: expiry_time,
            })
            .eq("id", payment.id)
            .select()
            .single();

        console.log(
            "Updated payment:",
            updatedPayment,
        );

        console.error(
            "Payment update error:",
            paymentUpdateError,
        );

        if (paymentUpdateError || !updatedPayment) {

            await supabase
                .from("payments")
                .update({
                    status: "failed",
                })
                .eq("id", payment.id);

            await supabase
                .from("orders")
                .update({
                    status: "cancelled",
                    payment_status: "failed",
                })
                .eq("id", order.id);

            return new Response(
                JSON.stringify({
                    error: "Failed to update payment transaction",
                }),
                {
                    status: 500,
                    headers: {
                        "Content-Type": "application/json",
                    },
                },
            );
        }

        return new Response(
            JSON.stringify({
                success: true,
                order,
                payment: updatedPayment,
                midtrans: midtransResult.data,
            }),
            {
                status: 200,
                headers: {
                    "Content-Type": "application/json",
                },
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