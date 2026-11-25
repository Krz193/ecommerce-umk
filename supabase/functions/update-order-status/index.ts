import {serve} from "https://deno.land/std@0.224.0/http/server.ts";
import {createClient, SupabaseClient} from "https://esm.sh/@supabase/supabase-js@2";

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
    driver_name?: string;
    driver_phone?: string;
    driver_plate_number?: string;
    link?: string;
    waybill_id?: string;
    tracking_id?: string;
    coordinate?: {
        latitude?: number;
        longitude?: number;
    };
    history?: BiteshipHistoryItem[];
}

interface BiteshipHistoryItem {
    status?: string;
    note?: string;
    updated_at?: string;
    timestamp?: string;
    service_type?: string;
    location?: string;
    checkpoint_name?: string;
    driver_name?: string;
    latitude?: number;
    longitude?: number;
    coordinate?: {
        latitude?: number;
        longitude?: number;
    };
}

interface BiteshipOrderResponse {
    id?: string;
    status?: string;
    waybill_id?: string;
    link?: string;
    courier?: BiteshipCourierInfo;
    history?: BiteshipHistoryItem[];
    error?: string;
    message?: string;
    code?: number;
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

function isValidLatLng(lat: unknown, lng: unknown): boolean {
    return (
        typeof lat === "number" &&
        typeof lng === "number" &&
        Number.isFinite(lat) &&
        Number.isFinite(lng) &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180 &&
        !(lat === 0 && lng === 0)
    );
}

async function isAuthorizedStoreStaff(
    dbClient: SupabaseClient,
    storeId: string,
    userId: string,
): Promise<boolean> {
    const {data: ownerStore} = await dbClient
        .from("stores")
        .select("id")
        .eq("id", storeId)
        .eq("owner_id", userId)
        .maybeSingle();

    if (ownerStore) return true;

    const {data: assistantRow} = await dbClient
        .from("store_assistants")
        .select("id")
        .eq("store_id", storeId)
        .eq("user_id", userId)
        .maybeSingle();

    return Boolean(assistantRow);
}

async function fetchWithTimeout(url: string, init: RequestInit, timeoutMs = 5000): Promise<Response> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
        return await fetch(url, {...init, signal: controller.signal});
    } finally {
        clearTimeout(timer);
    }
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

function normalizeBiteshipHistory(
    rawHistory: BiteshipHistoryItem[] | undefined,
    existingHistory: unknown,
    fallbackDriverName: string | null,
    trackingUrl: string | null,
): Record<string, unknown>[] {
    const existingList = Array.isArray(existingHistory)
        ? existingHistory.filter((item): item is Record<string, unknown> => Boolean(item && typeof item === "object"))
        : [];

    if (!Array.isArray(rawHistory) || rawHistory.length === 0) {
        return existingList;
    }

    return rawHistory.map((item) => {
        const status = item.status || "in_transit";
        const timestamp = item.updated_at || item.timestamp || new Date().toISOString();
        const existingMatch = existingList.find(
            (ex) => ex.status === status && ex.timestamp === timestamp,
        );
        const lat = item.latitude ?? item.coordinate?.latitude ?? (existingMatch?.latitude as number | undefined) ?? null;
        const lng = item.longitude ?? item.coordinate?.longitude ?? (existingMatch?.longitude as number | undefined) ?? null;

        return {
            status,
            checkpoint_name: item.checkpoint_name || item.location || (existingMatch?.checkpoint_name as string | undefined) || null,
            note: item.note || (existingMatch?.note as string | undefined) || `Status pengiriman: ${status}`,
            driver_name: item.driver_name || fallbackDriverName || (existingMatch?.driver_name as string | undefined) || null,
            tracking_url: trackingUrl || (existingMatch?.tracking_url as string | undefined) || null,
            latitude: lat,
            longitude: lng,
            timestamp,
        };
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
            action,
            shipping_provider,
            tracking_number
        } = body;

        /**
         * Required payload validation
         */
        if (!order_id || (!status && action !== "sync_tracking")) {
            return jsonResponse({error: "Invalid payload"}, 400);
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
                    phone,
                    address,
                    city,
                    postal_code,
                    latitude,
                    longitude,
                    notes,
                    biteship_area_id
                )
            `)
            .eq("id", order_id)
            .single();

        console.log("Operational order lookup:", {
            order_id: order?.id,
            status: order?.status,
            payment_status: order?.payment_status,
        });

        if (orderError) {
            console.error(orderError);

            return jsonResponse({error: "Order not found"}, 404);
        }

        // =====================================================================
        // Action: sync_tracking (Active sync with Biteship Orders / Trackings)
        // =====================================================================
        if (action === "sync_tracking") {
            const isBuyer = order.user_id === user.id;
            const isDriver = order.driver_id === user.id;
            const isStoreStaff = await isAuthorizedStoreStaff(dbClient, order.store_id, user.id);
            const {data: userRow} = await dbClient.from("users").select("role").eq("id", user.id).maybeSingle();
            const isAdmin = userRow?.role === "admin";

            if (!isBuyer && !isDriver && !isStoreStaff && !isAdmin) {
                return jsonResponse({error: "Forbidden"}, 403);
            }

            const apiKey = Deno.env.get("BITESHIP_API_KEY");
            const biteshipOrderId = order.biteship_order_id ? String(order.biteship_order_id) : null;
            const waybillId = String(order.waybill_id || order.tracking_number || "").trim();
            const courierCode = String(order.courier_code || "").trim().toLowerCase();
            const externalCouriers = ["gojek", "grab", "jne", "sicepat", "jnt", "anteraja", "paxel", "ninja", "lion", "pos", "tiki"];

            if (!apiKey || (!biteshipOrderId && !(waybillId && externalCouriers.includes(courierCode)))) {
                return jsonResponse({success: true, order}, 200);
            }

            const syncUpdates: Record<string, unknown> = {};
            let bsSyncData: BiteshipOrderResponse | null = null;
            let targetUrl = "";

            if (biteshipOrderId) {
                targetUrl = `https://api.biteship.com/v1/orders/${encodeURIComponent(biteshipOrderId)}`;
            } else if (waybillId && courierCode) {
                targetUrl = `https://api.biteship.com/v1/trackings/${encodeURIComponent(waybillId)}/couriers/${encodeURIComponent(courierCode)}`;
            }

            if (targetUrl) {
                const startTime = Date.now();
                try {
                    const res = await fetchWithTimeout(targetUrl, {
                        method: "GET",
                        headers: {
                            "authorization": apiKey,
                            "content-type": "application/json",
                        },
                    }, 5000);

                    const data = (await res.json().catch(() => ({}))) as BiteshipOrderResponse;

                    try {
                        await dbClient.from("biteship_api_logs").insert({
                            url: targetUrl,
                            method: "GET",
                            request_body: {order_id: order.id, action: "sync_tracking"},
                            status_code: res.status,
                            response_body: data,
                            duration_ms: Date.now() - startTime,
                            error_message: !res.ok ? JSON.stringify(data) : null,
                        });
                    } catch {
                        // ignore log error
                    }

                    if (res.ok) {
                        bsSyncData = data;
                    }
                } catch (err) {
                    console.warn("Biteship sync_tracking timeout/network warning:", err);
                }
            }

            if (bsSyncData) {
                const resolvedStatus = String(bsSyncData.status || order.tracking_status || "").trim();
                const resolvedWaybill = bsSyncData.courier?.waybill_id || bsSyncData.courier?.tracking_id || bsSyncData.waybill_id || order.waybill_id;
                const resolvedDriverName = bsSyncData.courier?.driver_name || bsSyncData.courier?.name || order.driver_name || null;
                const resolvedDriverPhone = bsSyncData.courier?.driver_phone || bsSyncData.courier?.phone || order.driver_phone || null;
                const resolvedPlate = bsSyncData.courier?.driver_plate_number || order.driver_vehicle_plate || null;
                const resolvedTrackingUrl = bsSyncData.courier?.link || bsSyncData.link || order.tracking_url || null;
                const driverLat = bsSyncData.courier?.coordinate?.latitude;
                const driverLng = bsSyncData.courier?.coordinate?.longitude;

                if (resolvedStatus) syncUpdates.tracking_status = resolvedStatus;
                if (resolvedWaybill) {
                    syncUpdates.waybill_id = resolvedWaybill;
                    syncUpdates.tracking_number = resolvedWaybill;
                }
                if (resolvedDriverName) syncUpdates.driver_name = resolvedDriverName;
                if (resolvedDriverPhone) syncUpdates.driver_phone = resolvedDriverPhone;
                if (resolvedPlate) syncUpdates.driver_vehicle_plate = resolvedPlate;
                if (resolvedTrackingUrl) syncUpdates.tracking_url = resolvedTrackingUrl;
                if (isValidLatLng(driverLat, driverLng)) {
                    syncUpdates.driver_latitude = driverLat;
                    syncUpdates.driver_longitude = driverLng;
                    syncUpdates.driver_last_updated = new Date().toISOString();
                }

                const rawHistory = bsSyncData.history || bsSyncData.courier?.history;
                if (Array.isArray(rawHistory) && rawHistory.length > 0) {
                    syncUpdates.tracking_history = normalizeBiteshipHistory(
                        rawHistory,
                        order.tracking_history,
                        resolvedDriverName,
                        resolvedTrackingUrl,
                    );
                }

                if (resolvedStatus === "delivered") {
                    syncUpdates.status = "completed";
                    if (!order.completed_at) {
                        syncUpdates.completed_at = new Date().toISOString();
                    }
                } else if (
                    ["picking_up", "allocated", "picked", "dropping_off", "on_delivery"].includes(resolvedStatus) &&
                    order.status === "processing"
                ) {
                    syncUpdates.status = "shipped";
                    if (!order.shipped_at) {
                        syncUpdates.shipped_at = new Date().toISOString();
                    }
                }
            }

            if (Object.keys(syncUpdates).length === 0) {
                return jsonResponse({success: true, order}, 200);
            }

            syncUpdates.updated_at = new Date().toISOString();
            const {data: syncedOrder, error: syncErr} = await dbClient
                .from("orders")
                .update(syncUpdates)
                .eq("id", order.id)
                .select(`
                    *,
                    store:stores (
                        id,
                        name,
                        slug,
                        phone,
                        address,
                        province,
                        city,
                        district,
                        postal_code,
                        latitude,
                        longitude,
                        notes,
                        biteship_area_id
                    )
                `)
                .single();

            if (syncErr) {
                return jsonResponse({error: `Gagal sinkronisasi resi: ${syncErr.message}`}, 400);
            }

            return jsonResponse({success: true, order: syncedOrder}, 200);
        }

        /**
         * Allowed operational statuses
         */
        const allowedStatuses = ["shipped", "completed"];

        if (!allowedStatuses.includes(status)) {
            return jsonResponse({error: "Invalid status"}, 400);
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

            const hasStoreAccess = await isAuthorizedStoreStaff(dbClient, order.store_id, user.id);

            if (!hasStoreAccess) {
                return jsonResponse({error: "Forbidden"}, 403);
            }

            // Populate any missing origin snapshot fields from store
            if (order.store) {
                if (!order.origin_contact_name && order.store.name) updates.origin_contact_name = order.store.name;
                if (!order.origin_phone && order.store.phone) updates.origin_phone = order.store.phone;
                if (!order.origin_address && order.store.address) updates.origin_address = order.store.address;
                if (!order.origin_city && order.store.city) updates.origin_city = order.store.city;
                if (!order.origin_postal_code && order.store.postal_code) updates.origin_postal_code = order.store.postal_code;
                if (!order.origin_notes && order.store.notes) updates.origin_notes = order.store.notes;
                if (!order.origin_area_id && order.store.biteship_area_id) updates.origin_area_id = order.store.biteship_area_id;
                if (order.origin_latitude == null && order.store.latitude != null) updates.origin_latitude = order.store.latitude;
                if (order.origin_longitude == null && order.store.longitude != null) updates.origin_longitude = order.store.longitude;
            }

            const useLive = Deno.env.get("BITESHIP_USE_LIVE") === "true";
            const apiKey = Deno.env.get("BITESHIP_API_KEY");
            const normalizedOrderCourier = String(order.courier_code || "").trim().toLowerCase();
            const isLocalStoreCourier = [
                "ojek_lokal",
                "ojek",
                "instant_lokal",
                "ekspedisi_lokal",
                "ekspedisi",
                "kurir_toko",
                "manual",
            ].includes(normalizedOrderCourier);

            if (isLocalStoreCourier && !trackingNumber) {
                if (order.tracking_status === "ready_to_ship") {
                    return jsonResponse({success: true, order}, 200);
                }

                // Local UMKM courier: mark order ready_to_ship in queue so assigned store courier can claim it
                updates.status = "processing";
                updates.shipping_provider = shippingProvider;
                updates.tracking_status = "ready_to_ship";
                const existingHistory = Array.isArray(order.tracking_history) ? order.tracking_history : [];
                updates.tracking_history = [
                    ...existingHistory,
                    {
                        status: "ready_to_ship",
                        checkpoint_name: order.origin_contact_name || order.store?.name || "Toko UMK",
                        note: `Pesanan siap dijemput oleh kurir lokal toko (${shippingProvider})`,
                        latitude: order.origin_latitude ?? order.store?.latitude ?? null,
                        longitude: order.origin_longitude ?? order.store?.longitude ?? null,
                        timestamp: new Date().toISOString(),
                    },
                ];
            } else if (useLive && apiKey && !isLocalStoreCourier && !order.biteship_order_id && !order.waybill_id && !trackingNumber) {
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
                    const recoveredDriverName = prevOrder.courier?.driver_name || prevOrder.courier?.name;
                    const recoveredDriverPhone = prevOrder.courier?.driver_phone || prevOrder.courier?.phone;
                    if (recoveredDriverName) updates.driver_name = recoveredDriverName;
                    if (recoveredDriverPhone) updates.driver_phone = recoveredDriverPhone;
                    if (prevOrder.courier?.driver_plate_number) updates.driver_vehicle_plate = prevOrder.courier.driver_plate_number;
                    if (prevOrder.courier?.link) updates.tracking_url = prevOrder.courier.link;
                } else {
                    const startTime = Date.now();
                    const idempotencyKey = `biteship-${order.id}-${order.order_number}`;

                    let destLat: number | null = typeof order.shipping_latitude === "number" ? order.shipping_latitude : null;
                    let destLng: number | null = typeof order.shipping_longitude === "number" ? order.shipping_longitude : null;

                    if (!isValidLatLng(destLat, destLng)) {
                        // Attempt to fetch recipient coordinates from addresses table
                        const { data: userAddr } = await dbClient
                            .from("addresses")
                            .select("latitude, longitude")
                            .eq("user_id", order.user_id)
                            .not("latitude", "is", null)
                            .limit(1)
                            .maybeSingle();

                        if (userAddr?.latitude && userAddr?.longitude) {
                            destLat = Number(userAddr.latitude);
                            destLng = Number(userAddr.longitude);
                        }
                    }

                    const rawOriginLat = order.origin_latitude ?? order.store?.latitude ?? null;
                    const rawOriginLng = order.origin_longitude ?? order.store?.longitude ?? null;
                    const originLat = rawOriginLat != null ? Number(rawOriginLat) : null;
                    const originLng = rawOriginLng != null ? Number(rawOriginLng) : null;

                    const courierCompany = (order.courier_code || "jne").toLowerCase();
                    const courierType = (order.courier_service_code || "reg").toLowerCase();
                    const serviceType = String(order.courier_service_type || "").toLowerCase();
                    const isInstantOrSameDay =
                        ["gojek", "grab"].includes(courierCompany) ||
                        ["instant", "same_day"].includes(serviceType) ||
                        courierType.includes("instant") ||
                        courierType.includes("same_day");

                    if (isInstantOrSameDay && (!isValidLatLng(originLat, originLng) || !isValidLatLng(destLat, destLng))) {
                        return jsonResponse({
                            error: "Titik koordinat GPS toko atau alamat tujuan belum valid/lengkap. Wajib set map point terlebih dahulu untuk layanan kurir Instant/Same-Day."
                        }, 400);
                    }

                    const effectiveOriginLat = isValidLatLng(originLat, originLng) ? originLat! : -6.303112;
                    const effectiveOriginLng = isValidLatLng(originLat, originLng) ? originLng! : 106.779493;
                    const effectiveDestLat = isValidLatLng(destLat, destLng) ? destLat! : -6.244179;
                    const effectiveDestLng = isValidLatLng(destLat, destLng) ? destLng! : 106.783529;

                    // Fetch real order items for Biteship specification compliance
                    const { data: orderItems } = await dbClient
                        .from("order_items")
                        .select("id, quantity, product_price, product:products(name, weight, length, width, height)")
                        .eq("order_id", order.id);

                    let itemsPayload: BiteshipItemPayload[] = [];
                    if (orderItems && orderItems.length > 0) {
                        itemsPayload = (orderItems as unknown as OrderItemRow[]).map((oi) => {
                            const prod = Array.isArray(oi.product) ? oi.product[0] : oi.product;
                            return {
                                name: prod?.name || "Barang Belanja UMK",
                                description: prod?.name || "Barang Belanja UMK",
                                value: Number((oi as unknown as {product_price?: number}).product_price || oi.price || 10000),
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

                    // Pure 1-to-1 reference ID (no suffixes)
                    const biteshipPayload = {
                        reference_id: order.order_number,
                        shipper_contact_name: order.origin_contact_name || order.store?.name || "Toko UMK",
                        shipper_contact_phone: formatIdPhone(order.origin_phone || order.store?.phone || "081234567890"),
                        origin_contact_name: order.origin_contact_name || order.store?.name || "Toko UMK",
                        origin_contact_phone: formatIdPhone(order.origin_phone || order.store?.phone || "081234567890"),
                        origin_address: order.origin_address || order.store?.address || "Alamat Toko UMK",
                        origin_note: order.origin_notes || order.store?.notes || "Toko UMK",
                        origin_postal_code: Number(order.origin_postal_code || order.store?.postal_code || 12430),
                        origin_coordinate: {
                            latitude: effectiveOriginLat,
                            longitude: effectiveOriginLng,
                        },
                        destination_contact_name: order.shipping_name || "Penerima",
                        destination_contact_phone: formatIdPhone(order.shipping_phone),
                        destination_address: order.shipping_address || "Alamat Pengiriman",
                        destination_note: order.shipping_notes || "Alamat Pembeli",
                        destination_postal_code: Number(order.shipping_postal_code || 12950),
                        destination_coordinate: {
                            latitude: effectiveDestLat,
                            longitude: effectiveDestLng,
                        },
                        courier_company: courierCompany,
                        courier_type: courierType,
                        delivery_type: "now",
                        items: itemsPayload,
                        ...(order.destination_area_id ? { destination_area_id: order.destination_area_id } : {}),
                        ...((order.origin_area_id || order.store?.biteship_area_id)
                            ? { origin_area_id: order.origin_area_id || order.store?.biteship_area_id }
                            : {}),
                    };

                    let biteshipRes: Response;
                    let bsData: BiteshipOrderResponse = {};

                    try {
                        biteshipRes = await fetchWithTimeout("https://api.biteship.com/v1/orders", {
                            method: "POST",
                            headers: {
                                "authorization": apiKey,
                                "content-type": "application/json",
                                "Idempotency-Key": idempotencyKey,
                            },
                            body: JSON.stringify(biteshipPayload),
                        }, 8000);

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
                            const recDriverName = prevOrder.courier?.driver_name || prevOrder.courier?.name;
                            const recDriverPhone = prevOrder.courier?.driver_phone || prevOrder.courier?.phone;
                            if (recDriverName) updates.driver_name = recDriverName;
                            if (recDriverPhone) updates.driver_phone = recDriverPhone;
                            if (prevOrder.courier?.driver_plate_number) updates.driver_vehicle_plate = prevOrder.courier.driver_plate_number;
                            if (prevOrder.courier?.link) updates.tracking_url = prevOrder.courier.link;
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

                        const resolvedDriverName = bsData.courier?.driver_name || bsData.courier?.name || null;
                        const resolvedDriverPhone = bsData.courier?.driver_phone || bsData.courier?.phone || null;
                        if (resolvedDriverName) updates.driver_name = resolvedDriverName;
                        if (resolvedDriverPhone) updates.driver_phone = resolvedDriverPhone;
                        if (bsData.courier?.driver_plate_number) updates.driver_vehicle_plate = bsData.courier.driver_plate_number;
                        if (bsData.courier?.link) updates.tracking_url = bsData.courier.link;

                        const existingHistory = Array.isArray(order.tracking_history) ? order.tracking_history : [];
                        updates.tracking_history = [
                            ...existingHistory,
                            {
                                status: updates.tracking_status,
                                checkpoint_name: "Pickup / Booking Biteship",
                                note: `Order kurir ${shippingProvider} berhasil dibuat di Biteship`,
                                driver_name: resolvedDriverName,
                                tracking_url: bsData.courier?.link || null,
                                latitude: effectiveOriginLat,
                                longitude: effectiveOriginLng,
                                timestamp: new Date().toISOString(),
                            },
                        ];
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
                const existingHistory = Array.isArray(order.tracking_history) ? order.tracking_history : [];
                updates.tracking_history = [
                    ...existingHistory,
                    {
                        status: "on_delivery",
                        checkpoint_name: "Input Resi Pengiriman",
                        note: `Nomor resi ${trackingNumber} (${shippingProvider}) diinput oleh penjual`,
                        timestamp: new Date().toISOString(),
                    },
                ];
            }

            if (updates.status === "shipped") {
                shippedAt = new Date().toISOString();
                updates.shipped_at = shippedAt;
            }
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

        console.log("Updated operational order:", {
            order_id: updatedOrder?.id,
            status: updatedOrder?.status,
            tracking_status: updatedOrder?.tracking_status,
        });

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
