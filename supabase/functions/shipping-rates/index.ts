import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface ShippingItem {
  name: string;
  description?: string;
  value: number;
  weight: number;
  quantity: number;
  length?: number;
  width?: number;
  height?: number;
}

interface CartItemProduct {
  id?: string;
  name?: string;
  price?: number;
  weight?: number;
  length?: number;
  width?: number;
  height?: number;
}

interface CartItemRow {
  id: string;
  quantity: number;
  product?: CartItemProduct | CartItemProduct[] | null;
}

function toFriendlyRatesError(data: Record<string, unknown> | null | undefined, _status?: number): string {
  const raw = String(data?.error || data?.message || "").toLowerCase();
  if (raw.includes("balance") || raw.includes("saldo")) {
    return "Saldo Biteship tidak mencukupi untuk memproses tarif kurir.";
  }
  if (raw.includes("postal_code") || raw.includes("postal code") || raw.includes("kode pos")) {
    return "Kode pos alamat pengiriman atau toko tidak valid.";
  }
  if (raw.includes("coordinate") || raw.includes("koordinat")) {
    return "Titik koordinat penjemputan atau tujuan tidak valid untuk kurir instan.";
  }
  if (raw.includes("weight") || raw.includes("berat")) {
    return "Total berat barang tidak memenuhi syarat pengiriman.";
  }
  return `Layanan kurir tidak tersedia untuk rute ini (${data?.error || data?.message || "Periksa alamat pengiriman"}).`;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ error: "Method not allowed" }), {
        status: 405,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const adminSupabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const supabase = adminSupabase;

    const body = await req.json();
    const { cart_id, address_id, store_id } = body;

    if (!address_id) {
      return new Response(JSON.stringify({ error: "address_id is required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 1. Fetch Destination Address
    const { data: address, error: addressError } = await supabase
      .from("addresses")
      .select("id, recipient_name, recipient_phone, city, province, postal_code, latitude, longitude, full_address")
      .eq("id", address_id)
      .single();

    if (addressError || !address) {
      console.error("Address fetch error:", addressError);
      return new Response(JSON.stringify({ error: "Address not found", details: addressError }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 2. Determine Store & Items
    let targetStoreId = store_id;
    let itemsToShip: ShippingItem[] = [];

    if (cart_id) {
      const { data: cart } = await supabase
        .from("carts")
        .select("id, store_id")
        .eq("id", cart_id)
        .single();

      if (cart) {
        targetStoreId = cart.store_id;
        const { data: cartItems } = await supabase
          .from("cart_items")
          .select("id, quantity, product:products(id, name, price, weight, length, width, height)")
          .eq("cart_id", cart_id);

        if (cartItems && cartItems.length > 0) {
          itemsToShip = (cartItems as unknown as CartItemRow[]).map((ci) => {
            const prod = Array.isArray(ci.product) ? ci.product[0] : ci.product;
            return {
              name: prod?.name ?? "Produk UMK",
              description: prod?.name ?? "Produk UMK",
              value: Number(prod?.price ?? 10000),
              length: Number(prod?.length ?? 10),
              width: Number(prod?.width ?? 10),
              height: Number(prod?.height ?? 10),
              weight: Math.max(100, Number(prod?.weight ?? 250)),
              quantity: ci.quantity,
            };
          });
        }
      }
    }

    if (itemsToShip.length === 0) {
      itemsToShip = [
        {
          name: "Paket Belanja UMK",
          description: "Paket Belanja UMK",
          value: 50000,
          length: 10,
          width: 10,
          height: 10,
          weight: 500,
          quantity: 1,
        },
      ];
    }

    // 3. Fetch Store Origin Address
    let originPostalCode = "12430";
    let originLat = -6.303112;
    let originLng = 106.779493;

    if (targetStoreId) {
      const { data: store } = await supabase
        .from("stores")
        .select("id, name, address, postal_code, latitude, longitude")
        .eq("id", targetStoreId)
        .single();

      if (store) {
        if (store.postal_code) originPostalCode = store.postal_code;
        if (store.latitude) originLat = store.latitude;
        if (store.longitude) originLng = store.longitude;
      }
    }

    const destPostalCode = address.postal_code || "12950";
    const destLat = address.latitude || -6.244179;
    const destLng = address.longitude || 106.783529;

    const apiKey = Deno.env.get("BITESHIP_API_KEY");
    const useLive = Deno.env.get("BITESHIP_USE_LIVE") === "true";

    // 4. Query Live Biteship API
    if (useLive && apiKey) {
      const biteshipPayload = {
        origin_latitude: originLat,
        origin_longitude: originLng,
        origin_postal_code: Number(originPostalCode) || 12430,
        destination_latitude: destLat,
        destination_longitude: destLng,
        destination_postal_code: Number(destPostalCode) || 12950,
        couriers: "gojek,grab,jne,sicepat,jnt,anteraja",
        items: itemsToShip,
      };

      const startTime = Date.now();
      const timeoutMs = 4000;
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), timeoutMs);

      try {
        const biteshipRes = await fetch("https://api.biteship.com/v1/rates/couriers", {
          method: "POST",
          headers: {
            "authorization": apiKey,
            "content-type": "application/json",
          },
          body: JSON.stringify(biteshipPayload),
          signal: controller.signal,
        });

        clearTimeout(timeoutId);
        const durationMs = Date.now() - startTime;
        const liveData = (await biteshipRes.json().catch(() => ({}))) as Record<string, unknown>;

        // Log Request & Response
        try {
          await supabase.from("biteship_api_logs").insert({
            url: "https://api.biteship.com/v1/rates/couriers",
            method: "POST",
            request_body: biteshipPayload,
            status_code: biteshipRes.status,
            response_body: liveData,
            duration_ms: durationMs,
          });
        } catch (logErr) {
          console.warn("Log insert error:", logErr);
        }

        if (biteshipRes.ok && liveData.success && Array.isArray(liveData.pricing) && liveData.pricing.length > 0) {
          return new Response(JSON.stringify(liveData), {
            status: 200,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          });
        }

        const friendlyMsg = toFriendlyRatesError(liveData, biteshipRes.status);
        return new Response(
          JSON.stringify({ error: friendlyMsg, details: liveData }),
          {
            status: biteshipRes.status || 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      } catch (err: unknown) {
        clearTimeout(timeoutId);
        const durationMs = Date.now() - startTime;
        const errObj = err as Error;
        const isTimeout = errObj.name === "AbortError" || errObj.message?.includes("abort");

        try {
          await supabase.from("biteship_api_logs").insert({
            url: "https://api.biteship.com/v1/rates/couriers",
            method: "POST",
            request_body: biteshipPayload,
            status_code: isTimeout ? 408 : 500,
            response_body: null,
            duration_ms: durationMs,
            error_message: isTimeout
              ? `TimeoutException: Request exceeded ${timeoutMs}ms limit`
              : errObj.message || "Biteship rates request failed",
          });
        } catch (logErr) {
          console.warn("Log insert error:", logErr);
        }

        const userMsg = isTimeout
          ? "Koneksi ke server kurir Biteship melebihi batas waktu (timeout). Silakan coba beberapa saat lagi."
          : `Gagal memuat tarif pengiriman (${errObj.message || "Gangguan jaringan"}).`;

        return new Response(
          JSON.stringify({ error: userMsg }),
          {
            status: isTimeout ? 408 : 502,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }
    }

    // If live Biteship is not enabled or no API key, reject with human-readable error instead of fake data
    return new Response(
      JSON.stringify({
        error: "Layanan pengiriman Biteship belum dikonfigurasi pada server.",
      }),
      {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("Rates function error:", error);
    return new Response(
      JSON.stringify({ error: (error as Error).message || "Internal server error" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
