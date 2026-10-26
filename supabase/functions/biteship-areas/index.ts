import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface BiteshipAreaItem {
  id: string;
  name: string;
  country_name?: string;
  country_code?: string;
  administrative_division_level_1_name?: string;
  administrative_division_level_1_type?: string;
  administrative_division_level_2_name?: string;
  administrative_division_level_2_type?: string;
  administrative_division_level_3_name?: string;
  administrative_division_level_3_type?: string;
  administrative_division_level_4_name?: string;
  administrative_division_level_4_type?: string;
  postal_code?: number | string;
}

interface NormalizedArea {
  id: string;
  name: string;
  province: string;
  city: string;
  district: string;
  subdistrict: string;
  postal_code: string;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);
    let input = url.searchParams.get("input")?.trim() || "";

    if (!input && req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      input = String(body?.input || "").trim();
    }

    if (!input || input.length < 3) {
      return new Response(JSON.stringify({ success: true, areas: [] }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const apiKey = Deno.env.get("BITESHIP_API_KEY");
    if (!apiKey) {
      return new Response(
        JSON.stringify({ error: "BITESHIP_API_KEY not configured" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const adminSupabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const biteshipUrl = `https://api.biteship.com/v1/maps/areas?countries=ID&input=${encodeURIComponent(
      input
    )}&type=single`;

    const startTime = Date.now();
    const timeoutMs = 5000;
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), timeoutMs);

    let biteshipRes: Response;
    let biteshipData: Record<string, unknown> = {};

    try {
      biteshipRes = await fetch(biteshipUrl, {
        method: "GET",
        headers: {
          authorization: apiKey,
          "content-type": "application/json",
        },
        signal: controller.signal,
      });

      clearTimeout(timeoutId);
      biteshipData = (await biteshipRes.json().catch(() => ({}))) as Record<
        string,
        unknown
      >;
    } catch (fetchErr: unknown) {
      clearTimeout(timeoutId);
      const errObj = fetchErr as Error;
      const isTimeout =
        errObj.name === "AbortError" || errObj.message?.includes("abort");

      return new Response(
        JSON.stringify({
          error: isTimeout
            ? "Pencarian area Biteship melebihi batas waktu (timeout)."
            : `Gagal mencari area: ${errObj.message || "Gangguan jaringan"}`,
          areas: [],
        }),
        {
          status: isTimeout ? 408 : 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Log to biteship_api_logs
    try {
      await adminSupabase.from("biteship_api_logs").insert({
        url: biteshipUrl,
        method: "GET",
        request_body: { input },
        status_code: biteshipRes.status,
        response_body: biteshipData,
        duration_ms: Date.now() - startTime,
      });
    } catch (_logErr) {
      // ignore log failure
    }

    if (!biteshipRes.ok || !biteshipData.areas) {
      return new Response(
        JSON.stringify({
          success: false,
          error:
            String(biteshipData.error || biteshipData.message) ||
            "Gagal mengambil daftar area dari Biteship",
          areas: [],
        }),
        {
          status: biteshipRes.status || 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const rawAreas = (biteshipData.areas as BiteshipAreaItem[]) || [];
    const normalized: NormalizedArea[] = rawAreas.map((area) => ({
      id: area.id || "",
      name: area.name || "",
      province: area.administrative_division_level_1_name || "",
      city: area.administrative_division_level_2_name || "",
      district: area.administrative_division_level_3_name || "",
      subdistrict: area.administrative_division_level_4_name || "",
      postal_code: String(area.postal_code || ""),
    }));

    return new Response(
      JSON.stringify({
        success: true,
        areas: normalized,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err: unknown) {
    return new Response(
      JSON.stringify({
        error: (err as Error).message || "Internal server error",
        areas: [],
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
