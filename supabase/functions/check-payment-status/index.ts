import {serve} from "https://deno.land/std@0.224.0/http/server.ts";
import {createClient} from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(data: unknown, status = 200) {
    return new Response(JSON.stringify(data), {
        status,
        headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
        },
    });
}

const MIDTRANS_SERVER_KEY = Deno.env.get("MIDTRANS_SERVER_KEY")!;
const MIDTRANS_IS_PRODUCTION = Deno.env.get("MIDTRANS_IS_PRODUCTION") === "true";
const MIDTRANS_BASE_URL = MIDTRANS_IS_PRODUCTION
    ? "https://api.midtrans.com/v2"
    : "https://api.sandbox.midtrans.com/v2";

serve(async (req) => {
    if (req.method === "OPTIONS") {
        return new Response("ok", { headers: corsHeaders });
    }

    try {
        /**
         * Only allow POST
         */
        if (req.method !== "POST") {
            return jsonResponse({error: "Method not allowed"}, 405);
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
                        Authorization: req.headers.get("Authorization") ?? ""
                    }
                }
            },
        );

        /**
         * Validate authenticated user
         */
        const {data: {user}, error: authError} = await supabase.auth.getUser();

        if (authError || !user) {
            return jsonResponse({error: "Unauthorized"}, 401);
        }

        /**
         * Parse request body
         */
        const body = await req.json();
        const orderId = body.order_id;
        const donationId = body.donation_id;

        if (!orderId && !donationId) {
            return jsonResponse({error: "order_id or donation_id is required"}, 400);
        }

        /**
         * Donation Payment Status Sync Mode (idempotent backup for webhook)
         */
        if (donationId) {
            const supabaseAdmin = createClient(
                Deno.env.get("SUPABASE_URL")!,
                Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
            );

            const {data: donation, error: donationError} = await supabaseAdmin
                .from("donations")
                .select("*, stores(name), store_contents(title)")
                .eq("id", donationId)
                .maybeSingle();

            if (donationError || !donation) {
                return jsonResponse({error: "Donation not found"}, 404);
            }

            if (donation.user_id !== user.id) {
                return jsonResponse({error: "Forbidden"}, 403);
            }

            if (
                donation.status === "distributed" ||
                donation.status === "paid" ||
                !donation.donation_number
            ) {
                return jsonResponse({
                    success: true,
                    payment_status: donation.status,
                    donation_status: donation.status,
                    midtrans_status: donation.status,
                    donation,
                });
            }

            const midtransResponse = await fetch(
                `${MIDTRANS_BASE_URL}/${donation.donation_number}/status`,
                {
                    method: "GET",
                    headers: {
                        Authorization: `Basic ${btoa(`${MIDTRANS_SERVER_KEY}:`)}`,
                        "Content-Type": "application/json",
                    },
                    signal: AbortSignal.timeout(10000),
                },
            );

            const midtransData = await midtransResponse.json();
            const txStatus = String(midtransData.transaction_status ?? "");

            let newStatus = String(donation.status ?? "pending");
            if (
                txStatus === "settlement" ||
                (txStatus === "capture" && midtransData.fraud_status !== "deny")
            ) {
                newStatus = "paid";
            } else if (txStatus === "expire") {
                newStatus = "expired";
            } else if (txStatus === "cancel" || txStatus === "deny") {
                newStatus = "failed";
            }

            let latestDonation = donation;
            if (
                donation.status !== "distributed" &&
                newStatus !== "pending" &&
                donation.status !== newStatus
            ) {
                const {data: updatedDonation, error: updateErr} = await supabaseAdmin
                    .from("donations")
                    .update({
                        status: newStatus,
                        paid_at: newStatus === "paid"
                            ? (donation.paid_at ?? new Date().toISOString())
                            : donation.paid_at,
                        payment_raw_response: midtransData,
                        updated_at: new Date().toISOString(),
                    })
                    .eq("id", donation.id)
                    .select("*, stores(name), store_contents(title)")
                    .single();

                if (!updateErr && updatedDonation) {
                    latestDonation = updatedDonation;
                }
            }

            return jsonResponse({
                success: true,
                payment_status: latestDonation.status,
                donation_status: latestDonation.status,
                midtrans_status: midtransData.transaction_status ?? latestDonation.status,
                fraud_status: midtransData.fraud_status ?? null,
                donation: latestDonation,
            });
        }

        /**
         * Order Payment Status Mode (READ ONLY — Webhook is authoritative source for orders)
         */
        const {data: order, error: orderError} = await supabase
            .from("orders")
            .select(`
                id,
                user_id,
                order_number,
                payment:payments (
                    id,
                    provider_transaction_id,
                    status
                )
            `)
            .eq("id", orderId)
            .single();

        if (orderError || !order) {
            return jsonResponse({error: "Order not found"}, 404);
        }

        /**
         * Validate order ownership
         */
        if (order.user_id !== user.id) {
            return jsonResponse({error: "Forbidden"}, 403);
        }

        /**
         * Fetch Midtrans transaction status
         */
        const midtransResponse = await fetch(
            `${MIDTRANS_BASE_URL}/${order.order_number}/status`,
            {
                method: "GET",
                headers: {
                    Authorization: `Basic ${btoa(`${MIDTRANS_SERVER_KEY}:`)}`,
                    "Content-Type": "application/json",
                },
                signal: AbortSignal.timeout(10000),
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
        return jsonResponse({
            success: true,
            payment_status: paymentStatus,
            order_status: orderStatus,
            midtrans_status: midtransData.transaction_status,
            fraud_status: midtransData.fraud_status,
            raw: midtransData,
        });
    } catch (error) {
        console.error(error);
        return jsonResponse({error: "Internal server error"}, 500);
    }
});
