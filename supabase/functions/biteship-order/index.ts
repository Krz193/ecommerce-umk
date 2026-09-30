import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, idempotency-key",
};

/**
 * [OBS-001] HTTP Logger for Raw Request & Response
 * Records URL, Method, Request Body, Status Code, Response Body, and Duration into database.
 */
async function logApiCall(
  supabase: SupabaseClient,
  params: {
    url: string;
    method: string;
    requestBody?: any;
    statusCode?: number;
    responseBody?: any;
    durationMs?: number;
    errorMessage?: string;
  }
) {
  try {
    await supabase.from("biteship_api_logs").insert({
      url: params.url,
      method: params.method,
      request_body: params.requestBody,
      status_code: params.statusCode,
      response_body: params.responseBody,
      duration_ms: params.durationMs,
      error_message: params.errorMessage,
    });
  } catch (e) {
    console.error("[OBS-001] Logging failed:", e);
  }
}

/**
 * [FIN-002] Sistem Notifikasi Saldo Kritis / Insufficient Balance
 * Triggers alerts to Slack, Telegram, or Email webhooks when balance is insufficient or below threshold.
 */
async function sendCriticalBalanceAlert(details: {
  orderId?: string;
  currentBalance?: number;
  threshold?: number;
  errorMessage?: string;
}) {
  const alertText = `🚨 [BITESHIP CRITICAL ALERT] Insufficient Balance Detected!
- Order ID: ${details.orderId || "N/A"}
- Error Message: ${details.errorMessage || "Account balance is insufficient to process courier pickup."}
- Current Balance: ${details.currentBalance !== undefined ? `Rp ${details.currentBalance.toLocaleString("id-ID")}` : "Insufficient"}
- Action Required: Please top up Biteship logistics account immediately!
- Time: ${new Date().toISOString()}`;

  console.error(alertText);

  // 1. Slack Webhook integration
  const slackUrl = Deno.env.get("SLACK_WEBHOOK_URL");
  if (slackUrl) {
    fetch(slackUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ text: alertText }),
    }).catch((err) => console.error("[FIN-002] Slack alert failed:", err));
  }

  // 2. Telegram Bot integration
  const tgToken = Deno.env.get("TELEGRAM_BOT_TOKEN");
  const tgChatId = Deno.env.get("TELEGRAM_CHAT_ID");
  if (tgToken && tgChatId) {
    fetch(`https://api.telegram.org/bot${tgToken}/sendMessage`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ chat_id: tgChatId, text: alertText }),
    }).catch((err) => console.error("[FIN-002] Telegram alert failed:", err));
  }

  // 3. Email Webhook notification
  const emailUrl = Deno.env.get("ALERT_EMAIL_WEBHOOK_URL");
  if (emailUrl) {
    fetch(emailUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        subject: "[CRITICAL] Biteship Insufficient Balance",
        body: alertText,
      }),
    }).catch((err) => console.error("[FIN-002] Email alert failed:", err));
  }
}

/**
 * [RES-002] Mekanisme Exponential Backoff
 * Automatically retries courier pickup or sync request on network or HTTP 5xx errors with increasing delays:
 * Delays: 2s (2000ms), 4s (4000ms), 8s (8000ms).
 */
async function callBiteshipWithExponentialBackoff(
  url: string,
  options: RequestInit,
  supabase: SupabaseClient,
  delays: number[] = [2000, 4000, 8000]
): Promise<{ ok: boolean; status: number; data: any }> {
  let lastError: any = null;
  const startTime = Date.now();

  for (let attempt = 0; attempt <= delays.length; attempt++) {
    const attemptStart = Date.now();
    try {
      const res = await fetch(url, options);
      const resData = await res.json().catch(() => ({}));

      // Log the attempt [OBS-001]
      await logApiCall(supabase, {
        url,
        method: options.method || "POST",
        requestBody: options.body ? JSON.parse(options.body as string) : null,
        statusCode: res.status,
        responseBody: resData,
        durationMs: Date.now() - attemptStart,
      });

      // If HTTP 5xx server error and we have retry attempts left, do exponential backoff
      if (res.status >= 500 && attempt < delays.length) {
        const waitMs = delays[attempt];
        console.warn(
          `[RES-002] Server error ${res.status}. Retry attempt ${attempt + 1}/${delays.length} in ${waitMs}ms...`
        );
        await new Promise((resolve) => setTimeout(resolve, waitMs));
        continue;
      }

      // Check for Insufficient Balance error [FIN-002]
      if (
        res.status === 402 ||
        (res.status === 400 && JSON.stringify(resData).toLowerCase().includes("insufficient"))
      ) {
        await sendCriticalBalanceAlert({
          errorMessage: resData.error || resData.message || "Insufficient Biteship balance",
        });
      }

      return {
        ok: res.ok,
        status: res.status,
        data: resData,
      };
    } catch (netErr: any) {
      lastError = netErr;
      if (attempt < delays.length) {
        const waitMs = delays[attempt];
        console.warn(
          `[RES-002] Network error: ${netErr.message}. Retrying in ${waitMs}ms (attempt ${attempt + 1}/${delays.length})...`
        );
        await new Promise((resolve) => setTimeout(resolve, waitMs));
      }
    }
  }

  // Final failure logging [OBS-001]
  await logApiCall(supabase, {
    url,
    method: options.method || "POST",
    requestBody: options.body ? JSON.parse(options.body as string) : null,
    statusCode: 500,
    durationMs: Date.now() - startTime,
    errorMessage: `[RES-002] Exponential backoff exhausted (${delays.length} retries): ${lastError?.message}`,
  });

  throw lastError || new Error("[RES-002] Courier request failed after exponential backoff retries");
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // =========================================================================
    // Optional Mode: [FIN-002] Balance check cron job endpoint
    // =========================================================================
    const url = new URL(req.url);
    if (url.searchParams.get("action") === "check_balance") {
      const apiKey = Deno.env.get("BITESHIP_API_KEY");
      if (!apiKey) {
        return new Response(JSON.stringify({ error: "BITESHIP_API_KEY not set" }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const balRes = await fetch("https://api.biteship.com/v1/couriers", {
        headers: { authorization: apiKey },
      });
      const balData = await balRes.json().catch(() => ({}));
      const balance = balData.balance ?? balData.credit ?? null;
      const criticalThreshold = 50000; // Rp 50.000 minimum threshold

      if (balance !== null && balance < criticalThreshold) {
        await sendCriticalBalanceAlert({
          currentBalance: balance,
          threshold: criticalThreshold,
          errorMessage: `Biteship balance is below critical threshold (Rp ${balance.toLocaleString("id-ID")})`,
        });
      }

      return new Response(JSON.stringify({ success: true, balance }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = await req.json();
    const { order_id } = body;

    if (!order_id) {
      return new Response(JSON.stringify({ error: "order_id is required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Load order details
    const { data: order, error: orderError } = await supabase
      .from("orders")
      .select("*, store:stores(id, name, address, postal_code, latitude, longitude)")
      .eq("id", order_id)
      .single();

    if (orderError || !order) {
      return new Response(JSON.stringify({ error: "Order not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // =========================================================================
    // [LOG-001] Implementasi Idempotency Key
    // Generate unique idempotency parameter (order ID + store ID) sent via Header and Payload
    // =========================================================================
    const idempotencyKey = `biteship-${order.id}-${order.order_number}`;

    const biteshipOrderPayload = {
      // Unique reference parameter in payload [LOG-001]
      reference_id: order.order_number,
      idempotency_key: idempotencyKey,
      shipper_contact_name: order.store?.name || "UMK Merchant",
      shipper_contact_phone: "08123456789",
      origin_contact_name: order.store?.name || "UMK Merchant",
      origin_contact_phone: "08123456789",
      origin_address: order.store?.address || "Alamat Toko UMK",
      origin_postal_code: Number(order.store?.postal_code || 12430),
      origin_coordinate: {
        latitude: order.store?.latitude || -6.303112,
        longitude: order.store?.longitude || 106.779493,
      },
      destination_contact_name: order.shipping_name,
      destination_contact_phone: order.shipping_phone,
      destination_address: order.shipping_address,
      destination_postal_code: Number(order.shipping_postal_code || 12950),
      courier_company: order.courier_code || "jne",
      courier_type: order.courier_service_code || "reg",
      delivery_type: "now",
      items: [
        {
          name: "Paket Belanja UMK",
          description: "Paket Belanja UMK",
          value: Number(order.subtotal || 50000),
          length: 10,
          width: 10,
          height: 10,
          weight: 500,
          quantity: 1,
        },
      ],
    };

    const apiKey = Deno.env.get("BITESHIP_API_KEY");
    const useLive = Deno.env.get("BITESHIP_USE_LIVE") === "true";

    if (!useLive || !apiKey) {
      return new Response(
        JSON.stringify({ error: "Layanan Biteship belum dikonfigurasi di server." }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Call POST /v1/orders with Idempotency Key Header & Payload [LOG-001] + Exponential Backoff [RES-002]
    const biteshipResponse = await callBiteshipWithExponentialBackoff(
      "https://api.biteship.com/v1/orders",
      {
        method: "POST",
        headers: {
          "authorization": apiKey,
          "content-type": "application/json",
          // Unique idempotency header parameter [LOG-001]
          "Idempotency-Key": idempotencyKey,
          "X-Idempotency-Key": idempotencyKey,
        },
        body: JSON.stringify(biteshipOrderPayload),
      },
      supabase,
      [2000, 4000, 8000] // Exponential backoff intervals [RES-002]
    );

    if (!biteshipResponse.ok || !biteshipResponse.data?.id) {
      const errData = biteshipResponse.data;
      const rawMsg = (errData?.error || errData?.message || "").toLowerCase();
      let friendlyError = `Gagal memproses pesanan ke Biteship: ${errData?.error || errData?.message || "Layanan ekspedisi bermasalah"}`;
      if (rawMsg.includes("balance") || rawMsg.includes("saldo")) {
        friendlyError = "Saldo deposit Biteship tidak mencukupi untuk memesan kurir. Silakan top-up saldo akun Biteship Anda.";
      } else if (rawMsg.includes("coordinate") || rawMsg.includes("koordinat")) {
        friendlyError = "Titik koordinat penjemputan toko atau tujuan tidak valid untuk kurir instan.";
      } else if (rawMsg.includes("postal_code") || rawMsg.includes("kode pos")) {
        friendlyError = "Kode pos pengirim atau penerima tidak valid.";
      }
      return new Response(
        JSON.stringify({
          error: friendlyError,
          details: biteshipResponse.data,
        }),
        {
          status: biteshipResponse.status || 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const biteshipOrderId = biteshipResponse.data.id;
    const waybillId = biteshipResponse.data.courier?.waybill_id || biteshipResponse.data.courier?.tracking_id || "";
    const driverName = biteshipResponse.data.courier?.driver_name || null;
    const driverPhone = biteshipResponse.data.courier?.driver_phone || null;

    // =========================================================================
    // [LOG-002] Implementasi Database Transaction (ACID)
    // Atomic execution of order record update, internal store balance deduction,
    // and status transition wrapped in BEGIN TRANSACTION, COMMIT, and ROLLBACK
    // =========================================================================
    console.log("[LOG-002] BEGIN TRANSACTION: Executing atomic order & balance update");

    const { data: txResult, error: txError } = await supabase.rpc(
      "execute_order_biteship_transaction",
      {
        p_order_id: order.id,
        p_store_id: order.store_id,
        p_biteship_order_id: biteshipOrderId,
        p_waybill_id: waybillId,
        p_shipping_cost: Number(order.shipping_cost || 0),
        p_idempotency_key: idempotencyKey,
        p_driver_name: driverName || null,
        p_driver_phone: driverPhone || null,
      }
    );

    if (txError) {
      console.error("[LOG-002] Transaction rolled back due to error:", txError);
      return new Response(
        JSON.stringify({
          error: "Database transaction failed (ACID ROLLBACK)",
          details: txError.message,
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    console.log("[LOG-002] COMMIT: Transaction succeeded atomically", txResult);

    return new Response(
      JSON.stringify({
        success: true,
        message: "Order successfully booked and updated with ACID guarantee",
        idempotency_key: idempotencyKey,
        biteship_order_id: biteshipOrderId,
        waybill_id: waybillId,
        transaction_result: txResult,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error: any) {
    console.error("Biteship order execution error:", error);
    return new Response(
      JSON.stringify({ error: error.message || "Internal server error" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
