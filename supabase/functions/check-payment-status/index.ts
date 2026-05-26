import {serve} from "https://deno.land/std@0.224.0/http/server.ts";

import {createClient} from "https://esm.sh/@supabase/supabase-js@2";

const MIDTRANS_SERVER_KEY = Deno
    .env
    .get("MIDTRANS_SERVER_KEY")!;

const MIDTRANS_BASE_URL = "https://api.sandbox.midtrans.com/v2";

serve(async (req) => {
    try {

        /**
     * Only allow POST
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
     * Authenticated Supabase client
     */
        const supabase = createClient(
            Deno.env.get("SUPABASE_URL")!,
            Deno.env.get("SUPABASE_ANON_KEY")!,
            {
                global: {
                    headers: {
                        Authorization: req
                            .headers
                            .get("Authorization",) ?? ""
                    }
                }
            },
        );

        /**
     * Validate authenticated user
     */
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

        /**
     * Parse request body
     */
        const body = await req.json();

        const orderId = body.order_id;

        if (!orderId) {
            return new Response(JSON.stringify({error: "order_id is required"}), {
                status: 400,
                headers: {
                    "Content-Type": "application/json"
                }
            },);
        }

        /**
     * Load order ownership
     */
        const {data: order, error: orderError} = await supabase
            .from("orders")
            .select(
                `
                id,
                user_id,
                order_number,
                payment:payments (
                    id,
                    provider_transaction_id,
                    status
                )
                `
            )
            .eq("id", orderId)
            .single();

        if (orderError || !order) {
            return new Response(JSON.stringify({error: "Order not found"}), {
                status: 404,
                headers: {
                    "Content-Type": "application/json"
                }
            },);
        }

        /**
     * Validate order ownership
     */
        if (order.user_id !== user.id) {
            return new Response(JSON.stringify({error: "Forbidden"}), {
                status: 403,
                headers: {
                    "Content-Type": "application/json"
                }
            },);
        }

        /**
     * Fetch Midtrans transaction status
     */
        const midtransResponse = await fetch(
            `${MIDTRANS_BASE_URL}/${order.order_number}/status`,
            {
                method: "GET",

                headers: {
                    Authorization: `Basic ${btoa(`${MIDTRANS_SERVER_KEY}:`,)}`,

                    "Content-Type": "application/json"
                }
            },
        );

        const midtransData = await midtransResponse.json();

        let paymentStatus = "pending";

        let orderStatus = "pending";

        switch (midtransData.transaction_status) {

            case "settlement":
                paymentStatus = "paid";
                orderStatus = "processing";
                break;

            case "expire":
                paymentStatus = "expired";
                orderStatus = "cancelled";
                break;

            case "cancel":
                paymentStatus = "failed";
                orderStatus = "cancelled";
                break;

            default:
                paymentStatus = "pending";
                orderStatus = "pending";
        }

        /**
     * READ ONLY
     *
     * No database mutation here.
     * Webhook is authoritative source
     * for transactional lifecycle.
     */
        return new Response(JSON.stringify({
            success: true,

            payment_status: paymentStatus,

            order_status: orderStatus,

            midtrans_status: midtransData.transaction_status,

            fraud_status: midtransData.fraud_status,

            raw: midtransData
        }), {
            status: 200,
            headers: {
                "Content-Type": "application/json"
            }
        },);
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