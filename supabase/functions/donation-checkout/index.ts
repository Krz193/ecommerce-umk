import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const VALID_CHANNELS = new Set([
  "bca",
  "bni",
  "bri",
  "mandiri",
  "permata",
  "cimb",
  "qris",
  "gopay",
  "shopeepay",
]);

function jsonResponse(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function getMidtransBaseUrl() {
  return Deno.env.get("MIDTRANS_IS_PRODUCTION") === "true"
    ? "https://api.midtrans.com"
    : "https://api.sandbox.midtrans.com";
}

function formatWibOrderTime(date: Date): string {
  const formatter = new Intl.DateTimeFormat("sv-SE", {
    timeZone: "Asia/Jakarta",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hour12: false,
  });

  const formatted = formatter.format(date).replace(",", "");
  return `${formatted} +0700`;
}

function buildMidtransChannelPayload(
  paymentChannel: string,
  storeName: string,
): { paymentType: string; payloadPart: Record<string, unknown> } {
  switch (paymentChannel) {
    case "bca":
    case "bni":
    case "bri":
    case "cimb":
      return {
        paymentType: "bank_transfer",
        payloadPart: {
          payment_type: "bank_transfer",
          bank_transfer: { bank: paymentChannel },
        },
      };
    case "permata":
      return {
        paymentType: "permata",
        payloadPart: {
          payment_type: "permata",
        },
      };
    case "mandiri":
      return {
        paymentType: "echannel",
        payloadPart: {
          payment_type: "echannel",
          echannel: {
            bill_info1: "Donasi UMK:",
            bill_info2: storeName.slice(0, 20) || "Toko UMK",
          },
        },
      };
    case "qris":
      return {
        paymentType: "qris",
        payloadPart: {
          payment_type: "qris",
          qris: { acquirer: "gopay" },
        },
      };
    case "gopay":
      return {
        paymentType: "gopay",
        payloadPart: {
          payment_type: "gopay",
          gopay: {
            enable_callback: true,
            callback_url: "umk://donations/pay",
          },
        },
      };
    case "shopeepay":
      return {
        paymentType: "shopeepay",
        payloadPart: {
          payment_type: "shopeepay",
          shopeepay: {
            callback_url: "umk://donations/pay",
          },
        },
      };
    default:
      throw new Error(`Unsupported payment channel: ${paymentChannel}`);
  }
}

function extractPaymentArtifacts(data: Record<string, unknown>) {
  const vaNumbers = Array.isArray(data.va_numbers)
    ? (data.va_numbers as Array<Record<string, unknown>>)
    : [];
  const actions = Array.isArray(data.actions)
    ? (data.actions as Array<Record<string, unknown>>)
    : [];

  const vaNumber =
    (vaNumbers[0]?.va_number as string | undefined) ??
    (data.permata_va_number as string | undefined) ??
    (data.bill_key as string | undefined) ??
    null;

  const billerCode = (data.biller_code as string | undefined) ?? null;

  const qrAction = actions.find(
    (a) => a.name === "generate-qr-code" || a.name === "generate-qr-code-v2",
  );
  const deeplinkAction = actions.find((a) => a.name === "deeplink-redirect");

  const qrUrl =
    (qrAction?.url as string | undefined) ??
    (data.qr_string as string | undefined) ??
    null;
  const deeplinkUrl = (deeplinkAction?.url as string | undefined) ?? null;

  let expiredAtUtc: string;
  if (typeof data.expiry_time === "string" && data.expiry_time.trim().length > 0) {
    const parsed = new Date(`${data.expiry_time.trim()} +0700`);
    expiredAtUtc = Number.isNaN(parsed.getTime())
      ? new Date(Date.now() + 30 * 60 * 1000).toISOString()
      : parsed.toISOString();
  } else {
    expiredAtUtc = new Date(Date.now() + 30 * 60 * 1000).toISOString();
  }

  return { vaNumber, billerCode, qrUrl, deeplinkUrl, expiredAtUtc };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method !== "POST") {
      return jsonResponse({ error: "Method not allowed" }, 405);
    }

    const midtransServerKey = Deno.env.get("MIDTRANS_SERVER_KEY");
    if (!midtransServerKey) {
      return jsonResponse({ error: "Midtrans configuration is missing" }, 500);
    }

    const supabaseUserClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      {
        global: {
          headers: {
            Authorization: req.headers.get("Authorization") ?? "",
          },
        },
      },
    );

    const {
      data: { user },
      error: authError,
    } = await supabaseUserClient.auth.getUser();

    if (authError || !user) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }

    const body = await req.json();
    const donationId = typeof body.donation_id === "string" && body.donation_id.trim().length > 0
      ? body.donation_id.trim()
      : null;
    const storeId = typeof body.store_id === "string" ? body.store_id.trim() : "";
    const contentId = typeof body.content_id === "string" && body.content_id.trim().length > 0
      ? body.content_id.trim()
      : null;
    const amount = Math.round(Number(body.amount ?? 0));
    const paymentChannel = typeof body.payment_channel === "string"
      ? body.payment_channel.trim().toLowerCase()
      : "";
    const rawDonorName = typeof body.donor_name === "string" ? body.donor_name.trim() : "";
    const donorName = rawDonorName.length > 0 ? rawDonorName.slice(0, 255) : "Hamba Allah (Anonim)";
    const rawNote = typeof body.note === "string" ? body.note.trim() : "";
    const note = rawNote.length > 0 ? rawNote.slice(0, 500) : null;

    if (!storeId) {
      return jsonResponse({ error: "store_id is required" }, 400);
    }

    if (!Number.isFinite(amount) || amount < 1000) {
      return jsonResponse({ error: "Nominal donasi minimal Rp 1.000" }, 400);
    }

    if (!VALID_CHANNELS.has(paymentChannel)) {
      return jsonResponse({ error: "Metode pembayaran tidak valid" }, 400);
    }

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Fetch store
    const { data: store, error: storeError } = await supabaseAdmin
      .from("stores")
      .select("id, name")
      .eq("id", storeId)
      .maybeSingle();

    if (storeError || !store) {
      return jsonResponse({ error: "Toko UMK tidak ditemukan" }, 404);
    }

    // Validate content if provided
    let resolvedContentId: string | null = null;
    if (contentId) {
      const { data: contentRow } = await supabaseAdmin
        .from("store_contents")
        .select("id, store_id")
        .eq("id", contentId)
        .maybeSingle();

      if (contentRow && contentRow.store_id === storeId) {
        resolvedContentId = contentRow.id;
      }
    }

    // Check existing donation ownership & state if regenerating VA
    let existingDonation: Record<string, unknown> | null = null;
    if (donationId) {
      const { data: existing, error: existingErr } = await supabaseAdmin
        .from("donations")
        .select("*")
        .eq("id", donationId)
        .maybeSingle();

      if (existingErr || !existing) {
        return jsonResponse({ error: "Data donasi tidak ditemukan" }, 404);
      }

      if (existing.user_id !== user.id) {
        return jsonResponse({ error: "Forbidden donation access" }, 403);
      }

      if (!["pending", "expired", "failed"].includes(String(existing.status))) {
        return jsonResponse(
          { error: "Donasi yang sudah lunas atau disalurkan tidak dapat dibuat ulang VA-nya" },
          400,
        );
      }

      existingDonation = existing;
      if (!resolvedContentId && typeof existing.content_id === "string") {
        resolvedContentId = existing.content_id;
      }
    }

    // Fetch donor profile details from public.users for audit completeness
    const { data: userProfile } = await supabaseAdmin
      .from("users")
      .select("full_name, phone")
      .eq("id", user.id)
      .maybeSingle();

    const donorPhone = typeof userProfile?.phone === "string" && userProfile.phone.trim().length > 0
      ? userProfile.phone.trim()
      : null;
    const donorEmail = user.email ?? null;

    const donationNumber = `DON-${Date.now()}-${Math.floor(100 + Math.random() * 900)}`;
    const { paymentType, payloadPart } = buildMidtransChannelPayload(
      paymentChannel,
      String(store.name ?? "Toko UMK"),
    );

    const midtransPayload = {
      ...payloadPart,
      transaction_details: {
        order_id: donationNumber,
        gross_amount: amount,
      },
      custom_expiry: {
        order_time: formatWibOrderTime(new Date()),
        expiry_duration: 30,
        unit: "minute",
      },
      customer_details: {
        first_name: donorName.slice(0, 50),
        email: donorEmail ?? undefined,
        phone: donorPhone ?? undefined,
      },
      item_details: [
        {
          id: resolvedContentId ?? storeId,
          name: `Donasi UMK - ${String(store.name ?? "Toko")}`.slice(0, 50),
          price: amount,
          quantity: 1,
        },
      ],
    };

    const authString = btoa(`${midtransServerKey}:`);
    const midtransRes = await fetch(`${getMidtransBaseUrl()}/v2/charge`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Basic ${authString}`,
      },
      body: JSON.stringify(midtransPayload),
      signal: AbortSignal.timeout(10000),
    });

    const midtransData = (await midtransRes.json()) as Record<string, unknown>;
    const midtransStatusCode = String(midtransData.status_code ?? "");

    if (!midtransRes.ok || (midtransStatusCode !== "201" && midtransStatusCode !== "200")) {
      return jsonResponse(
        {
          error:
            (midtransData.status_message as string | undefined) ??
            "Gagal membuat pembayaran Midtrans",
          midtrans: midtransData,
        },
        502,
      );
    }

    const { vaNumber, billerCode, qrUrl, deeplinkUrl, expiredAtUtc } =
      extractPaymentArtifacts(midtransData);

    const providerTransactionId =
      typeof midtransData.transaction_id === "string"
        ? midtransData.transaction_id
        : null;

    const recordPayload = {
      user_id: user.id,
      store_id: storeId,
      content_id: resolvedContentId,
      donation_number: donationNumber,
      amount,
      donor_name: donorName,
      donor_email: donorEmail,
      donor_phone: donorPhone,
      note,
      status: "pending",
      payment_type: paymentType,
      payment_channel: paymentChannel,
      va_number: vaNumber,
      biller_code: billerCode,
      qr_url: qrUrl,
      deeplink_url: deeplinkUrl,
      provider_transaction_id: providerTransactionId,
      payment_raw_response: midtransData,
      expired_at: expiredAtUtc,
      paid_at: null,
      updated_at: new Date().toISOString(),
    };

    let savedDonation: Record<string, unknown> | null = null;
    let dbError: unknown = null;

    if (existingDonation) {
      const { data, error } = await supabaseAdmin
        .from("donations")
        .update(recordPayload)
        .eq("id", existingDonation.id)
        .select("*, stores(name), store_contents(title)")
        .single();
      savedDonation = data;
      dbError = error;
    } else {
      const { data, error } = await supabaseAdmin
        .from("donations")
        .insert(recordPayload)
        .select("*, stores(name), store_contents(title)")
        .single();
      savedDonation = data;
      dbError = error;
    }

    if (dbError || !savedDonation) {
      console.error("Failed to save donation record:", dbError);
      return jsonResponse({ error: "Gagal menyimpan catatan donasi" }, 500);
    }

    return jsonResponse({
      success: true,
      donation: savedDonation,
      midtrans: midtransData,
    });
  } catch (error) {
    console.error("donation-checkout error:", error);
    return jsonResponse({ error: "Internal server error" }, 500);
  }
});
