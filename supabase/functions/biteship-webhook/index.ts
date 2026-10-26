import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-biteship-signature, x-signature",
};

/**
 * [WHK-001] HMAC SHA256 Signature Verification Middleware
 * Extracts signature header, hashes raw payload with secret key, and compares using timing-safe comparison.
 */
async function verifyHmacSha256Signature(secret: string, payload: string, signature: string): Promise<boolean> {
  try {
    const encoder = new TextEncoder();
    const key = await crypto.subtle.importKey(
      "raw",
      encoder.encode(secret),
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["sign"]
    );
    const signatureBuffer = await crypto.subtle.sign("HMAC", key, encoder.encode(payload));
    const computedSignature = Array.from(new Uint8Array(signatureBuffer))
      .map((b) => b.toString(16).padStart(2, "0"))
      .join("");

    // Constant-time string comparison to prevent timing attacks
    if (computedSignature.length !== signature.length) return false;
    let mismatch = 0;
    for (let i = 0; i < computedSignature.length; i++) {
      mismatch |= computedSignature.charCodeAt(i) ^ signature.charCodeAt(i);
    }
    return mismatch === 0;
  } catch (err) {
    console.error("[WHK-001] Signature computation error:", err);
    return false;
  }
}

/**
 * [FIN-001] Webhook Discrepancy Handler
 * Updates actual shipping cost in database and adjusts seller store balance based on courier difference.
 */
async function processDiscrepancy(supabase: SupabaseClient, payload: any) {
  const {
    order_id,
    original_price,
    final_price,
    price_discrepancy,
    original_weight,
    final_weight,
    discrepancy_reason,
  } = payload;

  console.log("[FIN-001] Processing discrepancy webhook for order:", order_id);

  // 1. Locate the order
  const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(order_id);
  let query = supabase.from("orders").select("id, store_id, shipping_cost, total_amount");
  if (isUuid) {
    query = query.or(`id.eq.${order_id},biteship_order_id.eq.${order_id}`);
  } else {
    query = query.or(`order_number.eq.${order_id},biteship_order_id.eq.${order_id}`);
  }

  const { data: order, error: orderError } = await query.maybeSingle();
  if (orderError || !order) {
    console.warn("[FIN-001] Order not found for discrepancy update:", order_id);
    return;
  }

  const origCost = Number(original_price ?? order.shipping_cost);
  const actualCost = Number(final_price ?? (origCost + Number(price_discrepancy ?? 0)));
  const diff = Number(price_discrepancy ?? (actualCost - origCost));

  // 2. Call PostgreSQL RPC apply_shipping_discrepancy (ACID)
  const { data: rpcResult, error: rpcError } = await supabase.rpc("apply_shipping_discrepancy", {
    p_order_id: order.id,
    p_actual_shipping_cost: actualCost,
    p_discrepancy_amount: diff,
    p_original_weight: original_weight ? Number(original_weight) : null,
    p_actual_weight: final_weight ? Number(final_weight) : null,
    p_notes: discrepancy_reason || "Biteship price/weight discrepancy adjustment",
  });

  if (rpcError) {
    console.error("[FIN-001] RPC discrepancy error, falling back to direct table update:", rpcError);

    // Fallback: direct update
    await supabase.from("orders").update({
      actual_shipping_cost: actualCost,
      shipping_discrepancy: diff,
      updated_at: new Date().toISOString(),
    }).eq("id", order.id);

    // Adjust seller store balance
    try {
      const { error: rpcErr } = await supabase.rpc("decrement_store_balance", {
        p_store_id: order.store_id,
        p_amount: diff,
      });
      if (rpcErr) throw rpcErr;
    } catch {
      // Direct stores balance update if RPC not present
      const { data: store } = await supabase.from("stores").select("balance").eq("id", order.store_id).single();
      const currentBalance = Number(store?.balance ?? 0);
      await supabase.from("stores").update({
        balance: currentBalance - diff,
        updated_at: new Date().toISOString(),
      }).eq("id", order.store_id);
    }

    // Record discrepancy log
    await supabase.from("biteship_discrepancies").insert({
      order_id: order.id,
      original_shipping_cost: origCost,
      actual_shipping_cost: actualCost,
      discrepancy_amount: diff,
      original_weight: original_weight ? Number(original_weight) : null,
      actual_weight: final_weight ? Number(final_weight) : null,
      seller_balance_adjusted: true,
      notes: discrepancy_reason || "Direct fallback discrepancy update",
    });
  }

  console.log("[FIN-001] Discrepancy successfully recorded & seller balance adjusted for order:", order.id);
}

/**
 * Worker function processing queued webhook jobs asynchronously
 */
async function processQueuedWebhookJob(supabase: SupabaseClient, jobId: string, payload: any) {
  try {
    const {
      event,
      status,
      order_id,
      courier_tracking_id,
      courier_waybill_id,
      courier_driver_name,
      courier_driver_phone,
      courier_link,
    } = payload;

    // Check if this is a price or weight discrepancy event [FIN-001]
    const isDiscrepancy =
      event === "order.price_discrepancy" ||
      event === "order.weight_discrepancy" ||
      status === "discrepancy" ||
      payload.price_discrepancy !== undefined;

    if (isDiscrepancy) {
      await processDiscrepancy(supabase, payload);
    }

    const referenceId = payload.reference_id || payload.metadata?.reference_id;
    const waybillId = courier_waybill_id || courier_tracking_id || payload.waybill_id || payload.tracking_id;

    // Locate the target order across all possible identifiers
    const orFilters: string[] = [];
    if (order_id) {
      orFilters.push(`biteship_order_id.eq.${order_id}`);
      if (/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(order_id)) {
        orFilters.push(`id.eq.${order_id}`);
      } else {
        orFilters.push(`order_number.eq.${order_id}`);
      }
    }
    if (referenceId) {
      orFilters.push(`order_number.eq.${referenceId}`);
    }
    if (waybillId) {
      orFilters.push(`waybill_id.eq.${waybillId}`);
      orFilters.push(`tracking_number.eq.${waybillId}`);
    }

    if (orFilters.length > 0) {
      const { data: order, error: findError } = await supabase
        .from("orders")
        .select("id, status, biteship_order_id, tracking_status, tracking_history")
        .or(orFilters.join(","))
        .maybeSingle();

      if (findError) {
        console.warn("[WHK-002] Error looking up order for webhook:", findError);
      }

      if (order) {
        console.log(`[WHK-002] Successfully matched order ${order.id} for event: ${event || status}`);
        const history = Array.isArray(order.tracking_history) ? order.tracking_history : [];
        history.push({
          status: status || event,
          driver_name: courier_driver_name,
          timestamp: new Date().toISOString(),
          tracking_url: courier_link,
        });

        const updateFields: Record<string, any> = {
          tracking_status: status || event,
          tracking_history: history,
          updated_at: new Date().toISOString(),
        };

        if (order_id && !order.biteship_order_id) {
          updateFields.biteship_order_id = order_id;
        }

        if (waybillId) {
          updateFields.waybill_id = waybillId;
          updateFields.tracking_number = waybillId;
        }
        if (courier_driver_name) updateFields.driver_name = courier_driver_name;
        if (courier_driver_phone) updateFields.driver_phone = courier_driver_phone;

        if (status === "picking_up" || status === "allocated" || status === "dropping_off" || status === "picked") {
          if (order.status === "processing") {
            updateFields.status = "shipped";
            updateFields.shipped_at = new Date().toISOString();
          }
        } else if (status === "delivered") {
          updateFields.status = "completed";
          updateFields.completed_at = new Date().toISOString();
        }

        const { error: updateErr } = await supabase.from("orders").update(updateFields).eq("id", order.id);
        if (updateErr) {
          console.error("[WHK-002] Failed to update order from webhook:", updateErr);
        } else {
          console.log(`[WHK-002] Successfully updated order ${order.id} status to ${status || event}`);
        }
      } else {
        console.warn("[WHK-002] Webhook received but no matching order found for identifiers:", orFilters);
      }
    }

    // Mark job completed in queue [WHK-002]
    await supabase.from("webhook_jobs").update({
      status: "completed",
      processed_at: new Date().toISOString(),
    }).eq("id", jobId);

  } catch (err: any) {
    console.error("[WHK-002] Worker error executing job:", err);
    await supabase.from("webhook_jobs").update({
      status: "failed",
      error_message: err.message || "Failed processing webhook job",
      attempts: 1,
    }).eq("id", jobId);
  }
}

serve(async (req) => {
  const startTime = Date.now();
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  let rawBody = "";
  let payload: any = {};

  try {
    rawBody = await req.text();
    payload = JSON.parse(rawBody || "{}");
  } catch (e) {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // Accept empty request body / ping upon Biteship webhook installation
  if (!rawBody || Object.keys(payload).length === 0 || req.method === "GET") {
    return new Response(
      JSON.stringify({
        success: true,
        message: "Webhook endpoint reachable and ready for installation",
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }

  // =========================================================================
  // [WHK-001] Validasi Webhook Signature (HMAC SHA256)
  // Extracts signature from header and verifies against project secret key
  // =========================================================================
  const signatureHeader =
    req.headers.get("x-biteship-signature") ||
    req.headers.get("x-signature") ||
    req.headers.get("signature");

  const secretKey = Deno.env.get("BITESHIP_WEBHOOK_SECRET");

  if (secretKey) {
    const isValid = await verifyHmacSha256Signature(secretKey, rawBody, signatureHeader ?? "");
    if (!isValid) {
      console.warn("[WHK-001] Rejected webhook: Invalid HMAC SHA256 signature");

      // [OBS-001] Log rejected signature attempt
      try {
        await supabase.from("biteship_api_logs").insert({
          url: req.url,
          method: req.method,
          request_body: payload,
          status_code: 401,
          response_body: { error: "Unauthorized: Invalid webhook signature" },
          duration_ms: Date.now() - startTime,
          error_message: "Signature verification failed",
        });
      } catch {
        // ignore log error
      }

      return new Response(
        JSON.stringify({ error: "Unauthorized: Invalid webhook signature" }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }
  }

  // =========================================================================
  // [WHK-002] Pemrosesan Webhook Asynchronous via Message Queue
  // Dispatches payload to queue table and returns HTTP 200 OK (< 500ms)
  // =========================================================================
  const eventType = payload.event || payload.status || "webhook_event";

  const { data: job, error: queueError } = await supabase
    .from("webhook_jobs")
    .insert({
      source: "biteship",
      event_type: eventType,
      payload: payload,
      status: "pending",
    })
    .select("id")
    .single();

  const durationMs = Date.now() - startTime;

  // [OBS-001] Pencatatan Raw Request & Response to centralized database log
  try {
    await supabase.from("biteship_api_logs").insert({
      url: req.url,
      method: req.method,
      request_body: payload,
      status_code: 200,
      response_body: { success: true, queued: true, job_id: job?.id },
      duration_ms: durationMs,
    });
  } catch (e: unknown) {
    console.warn("Failed to log webhook API call:", e);
  }

  // Asynchronously execute worker in background (non-blocking)
  if (job?.id) {
    // EdgeRuntime.waitUntil if available, or direct unawaited promise
    const backgroundTask = processQueuedWebhookJob(supabase, job.id, payload);
    // @ts-ignore
    if (typeof EdgeRuntime !== "undefined" && typeof EdgeRuntime.waitUntil === "function") {
      // @ts-ignore
      EdgeRuntime.waitUntil(backgroundTask);
    }
  }

  // Instant response within < 500ms
  return new Response(
    JSON.stringify({
      success: true,
      message: "Webhook accepted and queued for asynchronous processing",
      job_id: job?.id ?? null,
      processing_time_ms: durationMs,
    }),
    {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    }
  );
});
