import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const payload = await req.json();
    console.log("Biteship Webhook Received:", JSON.stringify(payload));

    const {
      event,
      order_id,
      status,
      courier_tracking_id,
      courier_waybill_id,
      courier_driver_name,
      courier_driver_phone,
      courier_link,
    } = payload;

    if (!order_id) {
      return new Response(JSON.stringify({ error: "order_id missing" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Find order by order_number or biteship_order_id or id
    const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(order_id);
    let query = supabase.from("orders").select("id, status, tracking_status, tracking_history");
    if (isUuid) {
      query = query.or(`id.eq.${order_id},biteship_order_id.eq.${order_id}`);
    } else {
      query = query.or(`order_number.eq.${order_id},biteship_order_id.eq.${order_id}`);
    }

    const { data: order, error: orderError } = await query.maybeSingle();

    if (orderError) {
      console.error("Order lookup error:", orderError);
    }

    if (!order) {
      console.warn("Order not found for Biteship webhook:", order_id);
      return new Response(JSON.stringify({ success: true, message: "Order not tracked yet" }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

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

    if (courier_waybill_id) {
      updateFields.waybill_id = courier_waybill_id;
      updateFields.tracking_number = courier_waybill_id;
    }
    if (courier_driver_name) {
      updateFields.driver_name = courier_driver_name;
    }
    if (courier_driver_phone) {
      updateFields.driver_phone = courier_driver_phone;
    }

    // Advance order status accordingly
    if (status === "picking_up" || status === "allocated" || status === "dropping_off") {
      if (order.status === "processing") {
        updateFields.status = "shipped";
        updateFields.shipped_at = new Date().toISOString();
      }
    } else if (status === "delivered") {
      updateFields.status = "completed";
      updateFields.completed_at = new Date().toISOString();
    }

    const { error: updateError } = await supabase
      .from("orders")
      .update(updateFields)
      .eq("id", order.id);

    if (updateError) {
      console.error("Failed to update order tracking:", updateError);
      return new Response(JSON.stringify({ error: updateError.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(
      JSON.stringify({
        success: true,
        order_id: order.id,
        tracking_status: status || event,
        order_status: updateFields.status ?? order.status,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (error: any) {
    console.error("Webhook processing error:", error);
    return new Response(JSON.stringify({ error: error.message || "Internal error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
