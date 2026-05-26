import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

import { createClient } from "@supabase/supabase-js";

const MIDTRANS_SERVER_KEY =
  Deno.env.get("MIDTRANS_SERVER_KEY")!;

const MIDTRANS_BASE_URL =
  "https://api.sandbox.midtrans.com/v2";

serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return new Response(
        JSON.stringify({
          error: "Method not allowed",
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

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      {
        global: {
          headers: {
            Authorization:
              req.headers.get(
                "Authorization",
              ) ?? "",
          },
        },
      },
    );

    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !user) {
      return new Response(
        JSON.stringify({
          error: "Unauthorized",
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

    const body = await req.json();

    const orderId = body.order_id;

    if (!orderId) {
      return new Response(
        JSON.stringify({
          error:
              "order_id is required",
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

    const {
      data: order,
      error: orderError,
    } = await supabase
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
      return new Response(
        JSON.stringify({
          error: "Order not found",
        }),
        {
          status: 404,
          headers: {
            "Content-Type":
                "application/json",
          },
        },
      );
    }

    if (order.user_id !== user.id) {
      return new Response(
        JSON.stringify({
          error: "Forbidden",
        }),
        {
          status: 403,
          headers: {
            "Content-Type":
                "application/json",
          },
        },
      );
    }

    const midtransResponse =
      await fetch(
        `${MIDTRANS_BASE_URL}/${order.order_number}/status`,
        {
          method: "GET",

          headers: {
            Authorization:
              `Basic ${btoa(
                `${MIDTRANS_SERVER_KEY}:`,
              )}`,
            "Content-Type":
                "application/json",
          },
        },
      );

    const midtransData =
      await midtransResponse.json();

    const transactionStatus = midtransData.transaction_status;

    if (transactionStatus === "settlement") {
        await supabase
            .from("payments")
            .update({
            status: "paid",
            paid_at: new Date().toISOString(),
            raw_response: midtransData,
            })
            .eq(
            "order_id",
            order.id,
            );

        await supabase
            .from("orders")
            .update({
            payment_status: "paid",
            status: "processing",
            paid_at: new Date().toISOString(),
            })
            .eq(
            "id",
            order.id,
            );
        }

    return new Response(
      JSON.stringify({
        success: true,
        transaction_status: transactionStatus,
        fraud_status:
          midtransData.fraud_status,
        raw: midtransData,
      }),
      {
        status: 200,
        headers: {
          "Content-Type":
              "application/json",
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