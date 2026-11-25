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
    const input =
        orderId +
        statusCode +
        grossAmount +
        serverKey;

    const encoded =
        new TextEncoder().encode(input);

    const hashBuffer = await crypto
        .subtle
        .digest("SHA-512", encoded);

    return Array
        .from(
            new Uint8Array(hashBuffer),
        )
        .map(
            (b) =>
                b
                    .toString(16)
                    .padStart(2, "0"),
        )
        .join("");
}

serve(async (req) => {
    try {

        /**
         * Only allow POST webhook requests
         */
        if (req.method !== "POST") {
            return new Response(
                JSON.stringify({
                    error:
                        "Method not allowed",
                }),
                {
                    status: 405,
                    headers: {
                        "Content-Type":
                            "application/json",
                    },
                },
            );
        }

        /**
         * Environment configuration
         */
        const MIDTRANS_SERVER_KEY =
            Deno
                .env
                .get(
                    "MIDTRANS_SERVER_KEY",
                )!;

        /**
         * Service-role Supabase client
         *
         * Webhook must bypass user-scoped RLS
         * because payment settlement is trusted
         * server-side infrastructure.
         */
        const supabase = createClient(
            Deno.env.get(
                "SUPABASE_URL",
            )!,
            Deno.env.get(
                "SUPABASE_SERVICE_ROLE_KEY",
            )!,
        );

        /**
         * Parse webhook payload
         */
        const body = await req.json();

        const {
            order_id,
            transaction_id,
            status_code,
            gross_amount,
            signature_key,
        } = body;

        console.log("Midtrans webhook received:", {
            order_id,
            transaction_status: body.transaction_status,
        });

        /**
         * Required webhook payload validation
         */
        if (
            !order_id ||
            !transaction_id ||
            !status_code ||
            !gross_amount ||
            !signature_key
        ) {
            return new Response(
                JSON.stringify({
                    error:
                        "Invalid payload",
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

        /**
         * Generate webhook signature
         */
        const generatedSignature =
            await generateSignature(
                order_id,
                status_code,
                gross_amount,
                MIDTRANS_SERVER_KEY,
            );

        /**
         * Verify Midtrans webhook signature
         */
        if (
            generatedSignature !==
            signature_key
        ) {
            return new Response(
                JSON.stringify({
                    error:
                        "Invalid signature",
                }),
                {
                    status: 401,
                    headers: {
                        "Content-Type":
                            "application/json",
                    },
                },
            );
        }

        console.log(
            "Signature verified",
        );

        /**
         * Handle UMK Donation Payment Webhook (DON-*)
         */
        if (String(order_id).startsWith("DON-")) {
            const { data: donation, error: donationError } = await supabase
                .from("donations")
                .select("*")
                .eq("donation_number", order_id)
                .maybeSingle();

            if (donationError) {
                console.error("Webhook donation error:", donationError);
            }

            if (!donation) {
                return new Response(
                    JSON.stringify({
                        error: "Donation not found",
                    }),
                    {
                        status: 404,
                        headers: {
                            "Content-Type": "application/json",
                        },
                    },
                );
            }

            if (Math.round(Number(gross_amount)) !== Math.round(Number(donation.amount))) {
                return new Response(
                    JSON.stringify({
                        error: "Donation gross amount mismatch",
                    }),
                    {
                        status: 400,
                        headers: {
                            "Content-Type": "application/json",
                        },
                    },
                );
            }

            const txStatus = String(body.transaction_status ?? "");
            let nextDonationStatus = String(donation.status ?? "pending");

            if (
                txStatus === "settlement" ||
                (txStatus === "capture" && body.fraud_status !== "deny")
            ) {
                nextDonationStatus = "paid";
            } else if (txStatus === "expire") {
                nextDonationStatus = "expired";
            } else if (txStatus === "cancel" || txStatus === "deny") {
                nextDonationStatus = "failed";
            }

            if (donation.status === "distributed" || donation.status === "paid") {
                return new Response(
                    JSON.stringify({
                        success: true,
                        message: "Paid or distributed donation preserved",
                        donation,
                    }),
                    {
                        status: 200,
                        headers: {
                            "Content-Type": "application/json",
                        },
                    },
                );
            }

            const { data: updatedDonation, error: updateDonationError } =
                await supabase
                    .from("donations")
                    .update({
                        status: nextDonationStatus,
                        paid_at:
                            nextDonationStatus === "paid"
                                ? (donation.paid_at ?? new Date().toISOString())
                                : donation.paid_at,
                        payment_raw_response: body,
                        updated_at: new Date().toISOString(),
                    })
                    .eq("id", donation.id)
                    .select()
                    .single();

            if (updateDonationError) {
                console.error(
                    "Updated webhook donation error:",
                    updateDonationError,
                );
                return new Response(
                    JSON.stringify({
                        error: "Failed to update donation status",
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
                    donation: updatedDonation,
                }),
                {
                    status: 200,
                    headers: {
                        "Content-Type": "application/json",
                    },
                },
            );
        }

        /**
         * Atomic order settlement / expiration / failure via PostgreSQL RPC
         */
        const { data: settlementResult, error: settlementError } = await supabase.rpc(
            "process_order_payment_webhook",
            {
                p_order_number: String(order_id),
                p_transaction_status: String(body.transaction_status ?? ""),
                p_fraud_status: body.fraud_status ? String(body.fraud_status) : null,
                p_gross_amount: Number(gross_amount),
                p_raw_response: body,
            },
        );

        if (settlementError) {
            console.error("Order webhook RPC error:", settlementError);
            return new Response(
                JSON.stringify({
                    error: "Failed to process payment webhook",
                }),
                {
                    status: 500,
                    headers: {
                        "Content-Type": "application/json",
                    },
                },
            );
        }

        if (!settlementResult || settlementResult.ok !== true) {
            const code = String(settlementResult?.code ?? "");
            const statusCode =
                code === "not_found" || code === "order_items_not_found" ? 404 : 400;

            return new Response(
                JSON.stringify({
                    error: settlementResult?.error ?? "Webhook rejected",
                }),
                {
                    status: statusCode,
                    headers: {
                        "Content-Type": "application/json",
                    },
                },
            );
        }

        return new Response(
            JSON.stringify({
                success: true,
                ignored: Boolean(settlementResult.ignored),
                message: settlementResult.message ?? undefined,
                payment: settlementResult.payment ?? null,
                order: settlementResult.order ?? null,
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

        return new Response(
            JSON.stringify({
                error:
                    "Internal server error",
            }),
            {
                status: 500,
                headers: {
                    "Content-Type":
                        "application/json",
                },
            },
        );
    }
});