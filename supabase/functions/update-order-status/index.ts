import {serve} from "https://deno.land/std@0.224.0/http/server.ts";
import {createClient} from "https://esm.sh/@supabase/supabase-js@2";

interface BiteshipItemPayload {
    name: string;
    description: string;
    value: number;
    length: number;
    width: number;
    height: number;
    weight: number;
    quantity: number;
}

interface OrderItemProduct {
    name?: string;
    weight?: number;
    length?: number;
    width?: number;
    height?: number;
}

interface OrderItemRow {
    id: string;
    quantity?: number;
    price?: number;
    product?: OrderItemProduct | OrderItemProduct[] | null;
}

interface BiteshipCourierInfo {
    name?: string;
    phone?: string;
    waybill_id?: string;
    tracking_id?: string;
}

interface BiteshipOrderResponse {
    id?: string;
    status?: string;
    courier?: BiteshipCourierInfo;
    error?: string;
    message?: string;
    [key: string]: unknown;
}

function formatIdPhone(phone?: string | null): string {
    if (!phone) return "081234567890";
    let cleaned = String(phone).replace(/[^0-9]/g, "");
    if (cleaned.startsWith("62")) cleaned = "0" + cleaned.slice(2);
    if (cleaned.startsWith("8")) cleaned = "0" + cleaned;
    if (!cleaned.startsWith("0")) cleaned = "08" + cleaned;
    if (cleaned.length < 10) cleaned = cleaned.padEnd(11, "0");
    return cleaned;
}

function toFriendlyBiteshipError(data: Record<string, unknown> | null | undefined, status: number): string {
    const rawMsg = String(data?.error || data?.message || "").toLowerCase();
    if (rawMsg.includes("balance") || rawMsg.includes("saldo") || rawMsg.includes("credit")) {
        return "Saldo deposit Biteship tidak mencukupi untuk melakukan pemesanan kurir. Silakan top-up saldo akun Biteship Anda.";
    }
    if (rawMsg.includes("coordinate") || rawMsg.includes("koordinat")) {
        return "Titik koordinat penjemputan toko atau tujuan penerima belum lengkap/tidak valid untuk layanan kurir instan.";
    }
    if (rawMsg.includes("postal_code") || rawMsg.includes("postal code") || rawMsg.includes("kode pos")) {
        return "Kode pos alamat pengiriman atau toko tidak valid dalam database ekspedisi.";
    }
    if (rawMsg.includes("phone") || rawMsg.includes("telepon") || rawMsg.includes("nomor")) {
        return "Nomor telepon pengirim atau penerima tidak valid (gunakan format nomor Indonesia aktif, misal 08123456789).";
    }
    if (rawMsg.includes("courier") || rawMsg.includes("service") || rawMsg.includes("not available")) {
        return "Layanan kurir yang dipilih sedang tidak tersedia untuk rute tujuan ini.";
    }
    if (rawMsg.includes("bad request") || status === 400) {
        return `Permintaan ke Biteship ditolak (${data?.error || data?.message || "Data pengiriman tidak lengkap"}). Silakan periksa alamat penerima dan toko.`;
    }
    return `Gagal memproses pesanan kurir Biteship: ${data?.error || data?.message || "Terjadi kendala pada server ekspedisi"}`;
}

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, idempotency-key",
    "Access-Control-Allow-Methods": "POST, PATCH, OPTIONS",
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

serve(async (req) => {
    if (req.method === "OPTIONS") {
        return new Response("ok", { headers: corsHeaders });
    }

    try {
        /**
         * Supabase Flutter functions.invoke sends POST by default.
         * PATCH is still accepted for direct API clients.
         */
        if (!["POST", "PATCH"].includes(req.method)) {
            return jsonResponse({error: "Method not allowed"}, 405);
        }

        /**
         * Supabase authenticated client
         *
         * Authorization handled via RLS.
         */
        const supabase = createClient(
            Deno.env.get("SUPABASE_URL")!,
            Deno.env.get("SUPABASE_ANON_KEY")!,
            {
                global: {
                    headers: {
                        Authorization: req
                            .headers
                            .get("Authorization")!
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
            return jsonResponse({error: "Unauthorized"}, 401);
        }

        /**
         * Service role client to guarantee persistence and avoid RLS block
         */
        const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || Deno.env.get("SERVICE_ROLE_KEY");
        const dbClient = serviceKey
            ? createClient(Deno.env.get("SUPABASE_URL")!, serviceKey)
            : supabase;

        /**
         * Parse request body
         */
        const body = await req.json();

        const {
            order_id,
            status,
            shipping_provider,
            tracking_number
        } = body;

        /**
         * Required payload validation
         */
        if (!order_id || !status) {
            return jsonResponse({error: "Invalid payload"}, 400);
        }

        /**
         * Allowed operational statuses
         */
        const allowedStatuses = ["shipped", "completed"];

        if (!allowedStatuses.includes(status)) {
            return jsonResponse({error: "Invalid status"}, 400);
        }

        /**
         * Load current order state
         */
        const {data: order, error: orderError} = await supabase
            .from("orders")
            .select(`
                *,
                store:stores (
                    id,
                    name,
                    address,
                    postal_code,
                    latitude,
                    longitude,
                    notes,
                    biteship_area_id
                )
            `)
            .eq("id", order_id)
            .single();

        console.log("Operational order:", order);

        if (orderError) {
            console.error(orderError);

            return jsonResponse({error: "Order not found"}, 404);
        }

        const updates: Record<string, unknown> = {status};

        /**
         * Prepare lifecycle timestamps
         */
        let shippedAt = order.shipped_at;

        let completedAt = order.completed_at;

        if (status === "shipped") {
            if (order.status !== "processing") {
                return jsonResponse({error: "Invalid order lifecycle transition"}, 400);
            }

            if (order.payment_status !== "paid") {
                return jsonResponse({error: "Only paid orders can be shipped"}, 400);
            }

            const shippingProvider = String(shipping_provider ?? "").trim() || (order.shipping_provider ?? "Kurir");
            let trackingNumber = String(tracking_number ?? "").trim();

            const {error: storeOwnerError} = await supabase
                .from("stores")
                .select("id")
                .eq("id", order.store_id)
                .eq("owner_id", user.id)
                .single();

            if (storeOwnerError) {
                return jsonResponse({error: "Forbidden"}, 403);
            }

            const useLive = Deno.env.get("BITESHIP_USE_LIVE") === "true";
            const apiKey = Deno.env.get("BITESHIP_API_KEY");

            // Live Biteship Booking for automated couriers
            if (useLive && apiKey && !order.biteship_order_id && !order.waybill_id) {
                // LAPIS 1: Pre-Dispatch Sync (Check if already booked in Biteship)
                // Cek apakah di database logs sudah pernah ada booking sukses untuk order_number ini
                const { data: existingLogs } = await dbClient
                    .from("biteship_api_logs")
                    .select("response_body")
                    .eq("url", "https://api.biteship.com/v1/orders")
                    .eq("method", "POST")
                    .gte("status_code", 200)
                    .lte("status_code", 299)
                    .filter("request_body->>reference_id", "ilike", `${order.order_number}%`)
                    .order("created_at", { ascending: false })
                    .limit(1);

                if (existingLogs && existingLogs.length > 0 && existingLogs[0].response_body?.id) {
                    console.log(`[Pre-Sync] Found existing booking in logs for ${order.order_number}. Reusing booking without duplicate request.`);
                    const prevOrder = existingLogs[0].response_body;
                    updates.biteship_order_id = prevOrder.id;
                    const realWaybill = prevOrder.courier?.waybill_id || prevOrder.courier?.tracking_id || "";
                    updates.waybill_id = realWaybill;
                    updates.tracking_number = realWaybill;
                    trackingNumber = realWaybill;
                    updates.tracking_status = prevOrder.status || "allocated";
                    if (prevOrder.courier?.name) updates.driver_name = prevOrder.courier.name;
                    if (prevOrder.courier?.phone) updates.driver_phone = prevOrder.courier.phone;
                } else {
                    const startTime = Date.now();
                    const idempotencyKey = `biteship-${order.id}-${order.order_number}`;

                    let destLat = -6.244179;
                    let destLng = 106.783529;

                    // Attempt to fetch recipient coordinates from addresses table
                    const { data: userAddr } = await supabase
                        .from("addresses")
                        .select("latitude, longitude")
                        .eq("user_id", order.user_id)
                        .not("latitude", "is", null)
                        .limit(1)
                        .maybeSingle();

                    if (userAddr?.latitude && userAddr?.longitude) {
                        destLat = userAddr.latitude;
                        destLng = userAddr.longitude;
                    }

                    const originLat = order.store?.latitude ?? -6.303112;
                    const originLng = order.store?.longitude ?? 106.779493;

                    // Fetch real order items for Biteship specification compliance
                    const { data: orderItems } = await supabase
                        .from("order_items")
                        .select("id, quantity, price, product:products(name, weight, length, width, height)")
                        .eq("order_id", order.id);

                    let itemsPayload: BiteshipItemPayload[] = [];
                    if (orderItems && orderItems.length > 0) {
                        itemsPayload = (orderItems as unknown as OrderItemRow[]).map((oi) => {
                            const prod = Array.isArray(oi.product) ? oi.product[0] : oi.product;
                            return {
                                name: prod?.name || "Barang Belanja UMK",
                                description: prod?.name || "Barang Belanja UMK",
                                value: Number(oi.price || 10000),
                                length: Number(prod?.length || 10),
                                width: Number(prod?.width || 10),
                                height: Number(prod?.height || 10),
                                weight: Math.max(100, Number(prod?.weight || 250)),
                                quantity: Number(oi.quantity || 1),
                            };
                        });
                    } else {
                        itemsPayload = [
                            {
                                name: "Barang Belanja UMK",
                                description: "Barang Belanja UMK",
                                value: Number(order.subtotal || 50000),
                                length: 10,
                                width: 10,
                                height: 10,
                                weight: 500,
                                quantity: 1,
                            }
                        ];
                    }

                    const courierCompany = (order.courier_code || "jne").toLowerCase();
                    const courierType = (order.courier_service_code || "reg").toLowerCase();

                    // Pure 1-to-1 reference ID (no suffixes)
                    const biteshipPayload = {
                        reference_id: order.order_number,
                        shipper_contact_name: order.store?.name || "Toko UMK",
                        shipper_contact_phone: formatIdPhone(order.store?.phone || "081234567890"),
                        origin_contact_name: order.store?.name || "Toko UMK",
                        origin_contact_phone: formatIdPhone(order.store?.phone || "081234567890"),
                        origin_address: order.store?.address || "Alamat Toko UMK",
                        origin_note: order.store?.notes || "Toko UMK",
                        origin_postal_code: Number(order.store?.postal_code || 12430),
                        origin_coordinate: {
                            latitude: originLat,
                            longitude: originLng,
                        },
                        destination_contact_name: order.shipping_name || "Penerima",
                        destination_contact_phone: formatIdPhone(order.shipping_phone),
                        destination_address: order.shipping_address || "Alamat Pengiriman",
                        destination_note: order.shipping_notes || "Alamat Pembeli",
                        destination_postal_code: Number(order.shipping_postal_code || 12950),
                        destination_coordinate: {
                            latitude: destLat,
                            longitude: destLng,
                        },
                        courier_company: courierCompany,
                        courier_type: courierType,
                        delivery_type: "now",
                        items: itemsPayload,
                        ...(order.destination_area_id ? { destination_area_id: order.destination_area_id } : {}),
                        ...(order.store?.biteship_area_id ? { origin_area_id: order.store.biteship_area_id } : {}),
                    };

                    let biteshipRes: Response;
                    let bsData: BiteshipOrderResponse = {};

                    try {
                        biteshipRes = await fetch("https://api.biteship.com/v1/orders", {
                            method: "POST",
                            headers: {
                                "authorization": apiKey,
                                "content-type": "application/json",
                                "Idempotency-Key": idempotencyKey,
                            },
                            body: JSON.stringify(biteshipPayload),
                        });

                        bsData = (await biteshipRes.json().catch(() => ({}))) as BiteshipOrderResponse;
                    } catch (fetchErr: unknown) {
                        const fetchErrObj = fetchErr as Error;
                        console.error("Biteship fetch network error:", fetchErrObj);
                        return jsonResponse({
                            error: `Gagal terhubung ke server Biteship (${fetchErrObj.message || "Network Error"}). Periksa koneksi internet.`
                        }, 502);
                    }

                    // Log call to biteship_api_logs using dbClient (service role) to guarantee persistence
                    try {
                        await dbClient.from("biteship_api_logs").insert({
                            url: "https://api.biteship.com/v1/orders",
                            method: "POST",
                            request_body: biteshipPayload,
                            status_code: biteshipRes.status,
                            response_body: bsData,
                            duration_ms: Date.now() - startTime,
                            error_message: !biteshipRes.ok ? JSON.stringify(bsData) : null,
                        });
                    } catch (logErr) {
                        console.warn("Log insert error:", logErr);
                    }

                    // LAPIS 2: Handle duplicate reference_id response strictly WITHOUT blind suffix bypass
                    const rawErr = String(bsData.error || bsData.message || "").toLowerCase();
                    const isDuplicateRef = rawErr.includes("reference id has already been used") || bsData.code === 40002060;

                    if (isDuplicateRef) {
                        console.warn(`[Anti-Duplication] Biteship reports reference_id ${order.order_number} already used.`);
                        // Check if we can recover the existing order details from logs
                        const { data: recoveredLogs } = await dbClient
                            .from("biteship_api_logs")
                            .select("response_body")
                            .eq("url", "https://api.biteship.com/v1/orders")
                            .eq("method", "POST")
                            .gte("status_code", 200)
                            .lte("status_code", 299)
                            .filter("request_body->>reference_id", "eq", order.order_number)
                            .order("created_at", { ascending: false })
                            .limit(1);

                        if (recoveredLogs && recoveredLogs.length > 0 && recoveredLogs[0].response_body?.id) {
                            console.log(`[Anti-Duplication] Successfully recovered order from logs: ${recoveredLogs[0].response_body.id}`);
                            const prevOrder = recoveredLogs[0].response_body;
                            updates.biteship_order_id = prevOrder.id;
                            const realWaybill = prevOrder.courier?.waybill_id || prevOrder.courier?.tracking_id || "";
                            updates.waybill_id = realWaybill;
                            updates.tracking_number = realWaybill;
                            trackingNumber = realWaybill;
                            updates.tracking_status = prevOrder.status || "allocated";
                            if (prevOrder.courier?.name) updates.driver_name = prevOrder.courier.name;
                            if (prevOrder.courier?.phone) updates.driver_phone = prevOrder.courier.phone;
                        } else {
                            // DO NOT create a second order! Return safe explanation to user
                            return jsonResponse({
                                error: `Pesanan (${order.order_number}) sudah pernah terdaftar di sistem Biteship. Demi mencegah pemotongan saldo atau penjemputan ganda, sistem tidak membuat pesanan kedua. Silakan periksa dashboard Biteship atau gunakan opsi Input Resi Manual.`
                            }, 400);
                        }
                    } else if (!biteshipRes.ok || !bsData.id) {
                        console.error("Biteship order rejected:", biteshipRes.status, bsData);
                        const friendlyError = toFriendlyBiteshipError(bsData, biteshipRes.status);
                        return jsonResponse({
                            error: friendlyError,
                            details: bsData
                        }, 400);
                    } else {
                        // Live order created successfully in Biteship
                        updates.biteship_order_id = bsData.id;
                        const realWaybill = bsData.courier?.waybill_id || bsData.courier?.tracking_id || "";
                        updates.waybill_id = realWaybill;
                        updates.tracking_number = realWaybill;
                        trackingNumber = realWaybill;
                        updates.tracking_status = bsData.status || "allocated";

                        if (bsData.courier?.name) updates.driver_name = bsData.courier.name;
                        if (bsData.courier?.phone) updates.driver_phone = bsData.courier.phone;
                    }
                }
            } else {
                // Manual ship: seller physically input tracking number
                if (!trackingNumber) {
                    return jsonResponse({
                        error: "Nomor resi wajib diisi jika tidak menggunakan kurir otomatis Biteship."
                    }, 400);
                }
                updates.tracking_number = trackingNumber;
                updates.waybill_id = trackingNumber;
                updates.tracking_status = "on_delivery";
            }

            shippedAt = new Date().toISOString();
            updates.shipped_at = shippedAt;
            updates.shipping_provider = shippingProvider;
            if (body.driver_name && updates.driver_name === undefined) {
                // Only set driver if not already populated from real courier
                updates.driver_name = body.driver_name;
            }
            if (body.driver_phone && updates.driver_phone === undefined) {
                updates.driver_phone = body.driver_phone;
            }
            if (body.biteship_order_id && updates.biteship_order_id === undefined) {
                updates.biteship_order_id = body.biteship_order_id;
            }
        }

        if (status === "completed") {
            if (order.status !== "shipped" || order.user_id !== user.id) {
                return jsonResponse({error: "Invalid order lifecycle transition"}, 400);
            }

            completedAt = new Date().toISOString();
            updates.completed_at = completedAt;
        }

        /**
         * Update operational order state via service role to ensure reliable transaction commit
         */
        const {data: updatedOrder, error: updatedOrderError} = await dbClient
            .from("orders")
            .update(updates)
            .eq("id", order.id)
            .select()
            .single();

        console.log("Updated operational order:", updatedOrder);

        if (updatedOrderError) {
            console.error("Order update error:", updatedOrderError);

            return jsonResponse({
                error: `Gagal memperbarui status pesanan: ${updatedOrderError.message}`
            }, 400);
        }

        /**
         * Success response
         */
        return jsonResponse({success: true, order: updatedOrder}, 200);
    } catch (error) {
        console.error(error);

        return jsonResponse({error: "Internal server error"}, 500);
    }
});
