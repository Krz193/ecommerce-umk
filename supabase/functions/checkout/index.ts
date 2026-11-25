import {serve} from "https://deno.land/std@0.224.0/http/server.ts";
import {createClient} from "https://esm.sh/@supabase/supabase-js@2";
import {createMidtransTransaction} from "./midtrans.ts";
import {
    isValidLatLng,
    resolveLocalStoreShippingOptions,
} from "../_shared/local_shipping.ts";

interface PendingOrderRef {
    id: string;
}

interface ProductImageItem {
    image_url: string;
    sort_order: number;
}

interface FlashSaleRpcItem {
    product_id: string;
    sale_event_id: string;
    sale_event_item_id: string;
    event_title: string;
    sale_price: number;
    regular_price: number;
    eligible_qty: number | null;
}

interface CheckoutLineItem {
    product_id: string;
    product_name: string;
    unit_price: number;
    quantity: number;
    subtotal: number;
    product_thumbnail: string | null;
    is_flash_sale: boolean;
    sale_event_id: string | null;
    sale_event_item_id: string | null;
}

interface ProductRecord {
    id: string;
    name: string;
    price: number;
    stock: number;
    status: string;
    store_id: string;
    weight?: number | null;
    length?: number | null;
    width?: number | null;
    height?: number | null;
    thumbnail_url?: string | null;
    product_images?: ProductImageItem[];
}

interface BiteshipRateItem {
    courier_name?: string;
    courier_code?: string;
    courier_service_name?: string;
    courier_service_code?: string;
    service_type?: string;
    type?: string;
    price?: number;
}

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
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
        if (req.method !== "POST") {
            return jsonResponse({error: "Method not allowed"}, 405);
        }

        const supabase = createClient(
            Deno.env.get("SUPABASE_URL")!,
            Deno.env.get("SUPABASE_ANON_KEY")!,
            {
                global: {
                    headers: {
                        Authorization: req.headers.get("Authorization") ?? ""
                    }
                }
            },
        );

        const {data: {user}, error: authError} = await supabase.auth.getUser();

        if (authError || !user) {
            return jsonResponse({error: "Unauthorized"}, 401);
        }

        const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || Deno.env.get("SERVICE_ROLE_KEY");
        if (!serviceKey) {
            return jsonResponse({error: "Server configuration error"}, 500);
        }
        const dbClient = createClient(Deno.env.get("SUPABASE_URL")!, serviceKey);

        // Parse request body (Zero Client Trust: ignore any client-supplied price or discount)
        const body = await req.json();
        const {cart_id, address_id, selected_courier, voucher_code} = body;

        const requestedCourierCode = String(
            body.courier_code ?? selected_courier?.courier_code ?? "",
        ).trim().toLowerCase();
        const requestedServiceCode = String(
            body.courier_service_code ?? selected_courier?.courier_service_code ?? "",
        ).trim().toLowerCase();

        if (!cart_id || !address_id) {
            return jsonResponse({error: "cart_id and address_id are required"}, 400);
        }

        if (!requestedCourierCode || !requestedServiceCode) {
            return jsonResponse({error: "Pilih layanan kurir pengiriman terlebih dahulu"}, 400);
        }

        // Fetch cart
        const {data: cart, error: cartError} = await supabase
            .from("carts")
            .select("id, user_id, store_id")
            .eq("id", cart_id)
            .single();

        if (cartError || !cart) {
            return jsonResponse({error: "Cart not found"}, 404);
        }

        if (cart.user_id !== user.id) {
            return jsonResponse({error: "Forbidden cart access"}, 403);
        }

        // Prevent duplicate pending payment scoped to user's own orders
        const now = new Date().toISOString();
        const {data: existingPendingPayment} = await supabase
            .from("payments")
            .select(`
                id,
                order_id,
                status,
                expired_at,
                orders!inner (
                    id,
                    user_id
                )
            `)
            .eq("orders.user_id", user.id)
            .eq("status", "pending")
            .gt("expired_at", now)
            .order("created_at", {ascending: false})
            .limit(1)
            .maybeSingle();

        if (existingPendingPayment) {
            const pendingOrder = existingPendingPayment.orders as unknown as PendingOrderRef | PendingOrderRef[] | null;
            const pendingOrderId = Array.isArray(pendingOrder)
                ? pendingOrder[0]?.id
                : (pendingOrder?.id ?? existingPendingPayment.order_id);

            return jsonResponse(
                {
                    error: "You still have pending payment",
                    order_id: pendingOrderId,
                },
                400,
            );
        }

        // Fetch cart items including weight & dimensions for server-side shipping calculation
        const {data: cartItems, error: cartItemsError} = await supabase
            .from("cart_items")
            .select(`
                id,
                quantity,
                product:products (
                    id,
                    name,
                    price,
                    stock,
                    status,
                    store_id,
                    weight,
                    length,
                    width,
                    height,
                    thumbnail_url,
                    product_images (
                        image_url,
                        sort_order
                    )
                )
            `)
            .eq("cart_id", cart.id);

        if (cartItemsError) {
            return jsonResponse({error: "Failed to fetch cart items"}, 500);
        }

        if (!cartItems || cartItems.length === 0) {
            return jsonResponse({error: "Cart is empty"}, 400);
        }

        // Validate products
        for (const item of cartItems) {
            const product = (Array.isArray(item.product) ? item.product[0] : item.product) as unknown as ProductRecord | null | undefined;

            if (!product) {
                return jsonResponse({error: "Product not found"}, 400);
            }

            if (product.status !== "published") {
                return jsonResponse({error: `Product ${product.name} is unavailable`}, 400);
            }

            if (product.stock < item.quantity) {
                return jsonResponse({error: `Insufficient stock for ${product.name}`}, 400);
            }

            if (product.store_id !== cart.store_id) {
                return jsonResponse({error: "Cross-store checkout is not allowed"}, 400);
            }
        }

        // Fetch destination address & verify ownership
        const {data: address, error: addressError} = await supabase
            .from("addresses")
            .select(`
                id,
                user_id,
                recipient_name,
                recipient_phone,
                province,
                city,
                district,
                postal_code,
                full_address,
                notes,
                biteship_area_id,
                latitude,
                longitude
            `)
            .eq("id", address_id)
            .single();

        if (addressError || !address) {
            return jsonResponse({error: "Address not found"}, 404);
        }

        if (address.user_id !== user.id) {
            return jsonResponse({error: "Forbidden address access"}, 403);
        }

        // Fetch store origin snapshot & local shipping settings
        const {data: store, error: storeError} = await dbClient
            .from("stores")
            .select(`
                id,
                name,
                phone,
                address,
                province,
                city,
                district,
                postal_code,
                notes,
                biteship_area_id,
                latitude,
                longitude,
                local_ojek_enabled,
                local_ojek_rates,
                local_ekspedisi_enabled,
                local_ekspedisi_rates
            `)
            .eq("id", cart.store_id)
            .single();

        if (storeError || !store) {
            return jsonResponse({error: "Store not found"}, 404);
        }

        // Fetch active Flash Sale pricing per product (server-authoritative)
        const productIds = cartItems
            .map((item) => {
                const product = (Array.isArray(item.product) ? item.product[0] : item.product) as unknown as ProductRecord | null | undefined;
                return product?.id;
            })
            .filter((id): id is string => Boolean(id));

        const flashSaleMap = new Map<string, FlashSaleRpcItem>();
        if (productIds.length > 0) {
            const {data: flashSalesData, error: flashSalesError} = await supabase.rpc(
                "get_active_product_flash_sales",
                {
                    p_product_ids: productIds,
                    p_user_id: user.id,
                },
            );

            if (!flashSalesError && Array.isArray(flashSalesData)) {
                for (const fsItem of flashSalesData as FlashSaleRpcItem[]) {
                    flashSaleMap.set(fsItem.product_id, fsItem);
                }
            }
        }

        // Build split checkout lines
        const checkoutLines: CheckoutLineItem[] = [];
        for (const item of cartItems) {
            const product = (Array.isArray(item.product) ? item.product[0] : item.product) as unknown as ProductRecord | null | undefined;
            if (!product) continue;

            const images = product.product_images;
            const thumbnail = product.thumbnail_url ??
                images?.slice().sort((a, b) => Number(a?.sort_order ?? 0) - Number(b?.sort_order ?? 0))?.[0]?.image_url ?? null;

            const regularPrice = Math.round(Number(product.price ?? 0));
            const flashInfo = flashSaleMap.get(product.id);
            const salePrice = flashInfo ? Math.round(Number(flashInfo.sale_price ?? regularPrice)) : regularPrice;

            let saleQty = 0;
            if (flashInfo && salePrice < regularPrice) {
                const eligibleQty = flashInfo.eligible_qty === null || flashInfo.eligible_qty === undefined
                    ? item.quantity
                    : Math.max(0, Number(flashInfo.eligible_qty));
                saleQty = Math.min(item.quantity, eligibleQty);
            }

            const regularQty = item.quantity - saleQty;

            if (saleQty > 0 && flashInfo) {
                checkoutLines.push({
                    product_id: product.id,
                    product_name: `${product.name} (Flash Sale)`,
                    unit_price: salePrice,
                    quantity: saleQty,
                    subtotal: salePrice * saleQty,
                    product_thumbnail: thumbnail,
                    is_flash_sale: true,
                    sale_event_id: flashInfo.sale_event_id,
                    sale_event_item_id: flashInfo.sale_event_item_id,
                });
            }

            if (regularQty > 0) {
                checkoutLines.push({
                    product_id: product.id,
                    product_name: product.name,
                    unit_price: regularPrice,
                    quantity: regularQty,
                    subtotal: regularPrice * regularQty,
                    product_thumbnail: thumbnail,
                    is_flash_sale: false,
                    sale_event_id: null,
                    sale_event_item_id: null,
                });
            }
        }

        const subtotal = checkoutLines.reduce((sum, line) => sum + line.subtotal, 0);

        // =====================================================================
        // SERVER-AUTHORITATIVE SHIPPING CALCULATION (ZERO CLIENT TRUST)
        // =====================================================================
        let shippingCost = 0;
        let resolvedCourierName = "";
        let resolvedCourierCode = requestedCourierCode;
        let resolvedServiceName = "";
        let resolvedServiceCode = requestedServiceCode;
        let resolvedServiceType = "standard";

        if (requestedCourierCode === "ojek_lokal" || requestedCourierCode === "ekspedisi_lokal") {
            const localOptions = resolveLocalStoreShippingOptions(
                store,
                address.latitude,
                address.longitude,
            );
            const matchedLocal = localOptions.find(
                (opt) =>
                    opt.courier_code.toLowerCase() === requestedCourierCode &&
                    opt.courier_service_code.toLowerCase() === requestedServiceCode,
            );

            if (!matchedLocal) {
                return jsonResponse(
                    {
                        error: "Layanan pengiriman lokal toko tidak aktif atau alamat berada di luar jangkauan jarak toko.",
                    },
                    400,
                );
            }

            shippingCost = Math.max(0, Math.round(matchedLocal.price));
            resolvedCourierName = matchedLocal.courier_name;
            resolvedCourierCode = matchedLocal.courier_code;
            resolvedServiceName = matchedLocal.courier_service_name;
            resolvedServiceCode = matchedLocal.courier_service_code;
            resolvedServiceType = matchedLocal.service_type;
        } else {
            const apiKey = Deno.env.get("BITESHIP_API_KEY");
            const useLive = Deno.env.get("BITESHIP_USE_LIVE") === "true";

            if (!useLive || !apiKey) {
                return jsonResponse(
                    {error: "Layanan kurir eksternal Biteship belum aktif pada server."},
                    400,
                );
            }

            const hasCoords = isValidLatLng(store.latitude, store.longitude) &&
                isValidLatLng(address.latitude, address.longitude);

            if ((requestedCourierCode === "gojek" || requestedCourierCode === "grab") && !hasCoords) {
                return jsonResponse(
                    {error: "Titik koordinat GPS toko dan alamat tujuan wajib lengkap untuk kurir instan."},
                    400,
                );
            }

            const itemsForRates = cartItems.map((ci) => {
                const prod = (Array.isArray(ci.product) ? ci.product[0] : ci.product) as unknown as ProductRecord | null | undefined;
                return {
                    name: prod?.name ?? "Produk UMK",
                    description: prod?.name ?? "Produk UMK",
                    value: Math.max(1000, Math.round(Number(prod?.price ?? 10000))),
                    length: Number(prod?.length ?? 10),
                    width: Number(prod?.width ?? 10),
                    height: Number(prod?.height ?? 10),
                    weight: Math.max(100, Number(prod?.weight ?? 250)),
                    quantity: ci.quantity,
                };
            });

            const ratesPayload: Record<string, unknown> = {
                origin_postal_code: Number(store.postal_code) || 12430,
                destination_postal_code: Number(address.postal_code) || 12950,
                couriers: requestedCourierCode,
                items: itemsForRates,
            };

            if (hasCoords) {
                ratesPayload.origin_latitude = Number(store.latitude);
                ratesPayload.origin_longitude = Number(store.longitude);
                ratesPayload.destination_latitude = Number(address.latitude);
                ratesPayload.destination_longitude = Number(address.longitude);
            }

            const controller = new AbortController();
            const timeoutId = setTimeout(() => controller.abort(), 5000);
            let liveRatesData: Record<string, unknown> = {};
            let ratesResOk = false;

            try {
                const ratesRes = await fetch("https://api.biteship.com/v1/rates/couriers", {
                    method: "POST",
                    headers: {
                        "authorization": apiKey,
                        "content-type": "application/json",
                    },
                    body: JSON.stringify(ratesPayload),
                    signal: controller.signal,
                });
                clearTimeout(timeoutId);
                ratesResOk = ratesRes.ok;
                liveRatesData = (await ratesRes.json().catch(() => ({}))) as Record<string, unknown>;
            } catch (rateErr) {
                clearTimeout(timeoutId);
                console.error("Checkout Biteship rate verification failed:", rateErr);
                return jsonResponse(
                    {error: "Gagal memverifikasi tarif ongkos kirim ke server ekspedisi. Silakan coba lagi."},
                    502,
                );
            }

            const pricingList = (ratesResOk && Array.isArray(liveRatesData.pricing))
                ? (liveRatesData.pricing as BiteshipRateItem[])
                : [];

            const matchedBiteship = pricingList.find(
                (p) =>
                    String(p.courier_code ?? "").toLowerCase() === requestedCourierCode &&
                    String(p.courier_service_code ?? "").toLowerCase() === requestedServiceCode,
            );

            if (!matchedBiteship || matchedBiteship.price == null || Number(matchedBiteship.price) < 0) {
                return jsonResponse(
                    {error: "Layanan kurir yang dipilih tidak tersedia untuk rute pengiriman ini."},
                    400,
                );
            }

            shippingCost = Math.round(Number(matchedBiteship.price));
            resolvedCourierName = matchedBiteship.courier_name || requestedCourierCode.toUpperCase();
            resolvedCourierCode = String(matchedBiteship.courier_code || requestedCourierCode).toLowerCase();
            resolvedServiceName = matchedBiteship.courier_service_name || requestedServiceCode.toUpperCase();
            resolvedServiceCode = String(matchedBiteship.courier_service_code || requestedServiceCode).toLowerCase();
            resolvedServiceType = String(matchedBiteship.service_type || matchedBiteship.type || "standard").toLowerCase();
        }

        const applicationFee = 0;

        // =====================================================================
        // SERVER-AUTHORITATIVE VOUCHER VALIDATION (STRICT REJECT ON INVALID)
        // =====================================================================
        let appliedVoucherDiscount = 0;
        let finalVoucherId: string | null = null;
        let finalVoucherCode: string | null = null;

        const cleanVoucherCode = typeof voucher_code === "string" ? voucher_code.trim().toUpperCase() : "";
        if (cleanVoucherCode.length > 0) {
            const voucherItemsPayload = checkoutLines.map((line) => ({
                product_id: line.product_id,
                product_name: line.product_name,
                price: line.unit_price,
                quantity: line.quantity,
            }));

            const {data: vResult, error: vError} = await supabase.rpc("validate_and_apply_voucher", {
                p_store_id: cart.store_id,
                p_code: cleanVoucherCode,
                p_subtotal: subtotal,
                p_items: voucherItemsPayload,
            });

            if (vError || !vResult || vResult.valid !== true) {
                return jsonResponse(
                    {
                        error: vResult?.message || "Kode voucher tidak valid atau sudah tidak berlaku.",
                    },
                    400,
                );
            }

            appliedVoucherDiscount = Math.min(
                subtotal,
                Math.max(0, Math.round(Number(vResult.calculated_discount ?? 0))),
            );
            finalVoucherId = vResult.voucher_id ?? null;
            finalVoucherCode = vResult.code ?? cleanVoucherCode;
        }

        const totalAmount = Math.max(0, (subtotal - appliedVoucherDiscount) + shippingCost + applicationFee);

        const orderNumber = `ORD-${Date.now()}`;
        const fullCourierDisplayName = resolvedServiceName
            ? `${resolvedCourierName} - ${resolvedServiceName}`
            : resolvedCourierName;

        // Create order using dbClient with canonical server-computed values
        const {data: order, error: orderError} = await dbClient
            .from("orders")
            .insert({
                user_id: user.id,
                store_id: cart.store_id,
                order_number: orderNumber,

                status: "pending",
                payment_status: "pending",

                subtotal: subtotal,
                shipping_cost: shippingCost,
                application_fee: applicationFee,
                voucher_id: finalVoucherId,
                voucher_code: finalVoucherCode,
                voucher_discount: appliedVoucherDiscount,
                total_amount: totalAmount,

                shipping_name: address.recipient_name,
                shipping_phone: address.recipient_phone,
                shipping_address: address.full_address,
                shipping_notes: address.notes || null,
                destination_area_id: address.biteship_area_id || null,
                shipping_city: address.city,
                shipping_postal_code: address.postal_code,
                shipping_latitude: address.latitude ?? null,
                shipping_longitude: address.longitude ?? null,

                origin_contact_name: store.name ?? null,
                origin_phone: store.phone ?? null,
                origin_address: store.address ?? null,
                origin_city: store.city ?? null,
                origin_postal_code: store.postal_code ?? null,
                origin_notes: store.notes ?? null,
                origin_area_id: store.biteship_area_id ?? null,
                origin_latitude: store.latitude ?? null,
                origin_longitude: store.longitude ?? null,

                shipping_provider: fullCourierDisplayName,
                courier_name: fullCourierDisplayName,
                courier_code: resolvedCourierCode,
                courier_service_code: resolvedServiceCode,
                courier_service_type: resolvedServiceType,
                tracking_status: "pending",
            })
            .select()
            .single();

        if (orderError || !order) {
            console.error("Order insert error:", orderError);
            return jsonResponse({error: "Failed to create order"}, 500);
        }

        // Reserve voucher usage quota atomically if voucher applied
        if (finalVoucherId) {
            const {data: voucherReserved, error: voucherReserveErr} = await dbClient.rpc(
                "reserve_voucher_quota",
                {
                    p_voucher_id: finalVoucherId,
                    p_order_id: order.id,
                },
            );

            if (voucherReserveErr || voucherReserved !== true) {
                await dbClient.from("orders").delete().eq("id", order.id);
                return jsonResponse(
                    {error: "Kuota pemakaian voucher baru saja habis. Silakan periksa kembali voucher Anda."},
                    409,
                );
            }
        }

        // Reserve Flash Sale quota atomically and insert immutable order items snapshot
        const orderItems = [];
        for (const line of checkoutLines) {
            if (line.is_flash_sale && line.sale_event_item_id) {
                const {data: reserved, error: reserveErr} = await dbClient.rpc(
                    "reserve_flash_sale_quota",
                    {
                        p_sale_event_item_id: line.sale_event_item_id,
                        p_qty: line.quantity,
                        p_order_id: order.id,
                    },
                );

                if (reserveErr || reserved !== true) {
                    await dbClient.rpc("rollback_order_flash_sale_quota", {p_order_id: order.id});
                    await dbClient.rpc("rollback_voucher_quota", {p_order_id: order.id});
                    await dbClient.from("orders").delete().eq("id", order.id);

                    return jsonResponse(
                        {
                            error: `Kuota Flash Sale untuk ${line.product_name} baru saja habis. Silakan muat ulang keranjang Anda.`,
                        },
                        409,
                    );
                }
            }

            const {data: insertedItem, error: orderItemError} = await dbClient
                .from("order_items")
                .insert({
                    order_id: order.id,
                    product_id: line.product_id,
                    product_name: line.product_name,
                    product_price: line.unit_price,
                    quantity: line.quantity,
                    subtotal: line.subtotal,
                    product_thumbnail: line.product_thumbnail,
                    is_flash_sale: line.is_flash_sale,
                    sale_event_id: line.sale_event_id,
                    sale_event_item_id: line.sale_event_item_id,
                })
                .select()
                .single();

            if (orderItemError || !insertedItem) {
                console.error("Order item insert error:", orderItemError);
                await dbClient.rpc("rollback_order_flash_sale_quota", {p_order_id: order.id});
                await dbClient.rpc("rollback_voucher_quota", {p_order_id: order.id});
                await dbClient.from("order_items").delete().eq("order_id", order.id);
                await dbClient.from("orders").delete().eq("id", order.id);

                return jsonResponse({error: "Failed to create order items"}, 500);
            }

            orderItems.push(insertedItem);
        }

        // Create payment record
        const {data: payment, error: paymentError} = await dbClient
            .from("payments")
            .insert({
                order_id: order.id,
                provider: "midtrans",
                status: "pending",
                amount: totalAmount,
                expired_at: new Date(Date.now() + 1000 * 60 * 15).toISOString(),
            })
            .select()
            .single();

        if (paymentError || !payment) {
            await dbClient.rpc("rollback_order_flash_sale_quota", {p_order_id: order.id});
            await dbClient.rpc("rollback_voucher_quota", {p_order_id: order.id});
            await dbClient.from("order_items").delete().eq("order_id", order.id);
            await dbClient.from("orders").delete().eq("id", order.id);

            return jsonResponse({error: "Failed to create payment"}, 500);
        }

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

        const formattedOrderTime = `${formatter.format(new Date()).replace(",", "")} +0700`;

        const paymentPayload = {
            payment_type: "bank_transfer",
            transaction_details: {
                order_id: order.order_number,
                gross_amount: Number(order.total_amount),
            },
            custom_expiry: {
                order_time: formattedOrderTime,
                expiry_duration: 30,
                unit: "minute",
            },
            customer_details: {
                first_name: address.recipient_name,
                phone: address.recipient_phone,
            },
            item_details: [
                ...checkoutLines.map((line) => ({
                    id: line.is_flash_sale ? `${line.product_id}-FS` : line.product_id,
                    name: line.product_name.slice(0, 50),
                    price: line.unit_price,
                    quantity: line.quantity,
                })),
                ...(shippingCost > 0
                    ? [{
                        id: "SHIPPING_FEE",
                        name: `Ongkir (${fullCourierDisplayName})`.slice(0, 50),
                        price: shippingCost,
                        quantity: 1,
                    }]
                    : []),
                ...(appliedVoucherDiscount > 0
                    ? [{
                        id: "VOUCHER_DISCOUNT",
                        name: `Diskon Voucher ${finalVoucherCode || "VOUCHER"}`.slice(0, 50),
                        price: -appliedVoucherDiscount,
                        quantity: 1,
                    }]
                    : []),
            ],
        };

        const midtransResult = await createMidtransTransaction(paymentPayload);

        if (!midtransResult.ok) {
            await dbClient.rpc("rollback_order_flash_sale_quota", {p_order_id: order.id});
            await dbClient.rpc("rollback_voucher_quota", {p_order_id: order.id});
            await dbClient.from("payments").update({status: "failed"}).eq("id", payment.id);
            await dbClient
                .from("orders")
                .update({status: "cancelled", payment_status: "failed"})
                .eq("id", order.id);

            return jsonResponse(
                {
                    error: "Failed to create Midtrans transaction",
                    midtrans: midtransResult.data,
                },
                500,
            );
        }

        const {transaction_id, expiry_time} = midtransResult.data;
        let expiredAtUtc: string;
        if (typeof expiry_time === "string" && expiry_time.trim().length > 0) {
            const parsedExpiry = new Date(`${expiry_time.trim()} +0700`);
            expiredAtUtc = Number.isNaN(parsedExpiry.getTime())
                ? new Date(Date.now() + 30 * 60 * 1000).toISOString()
                : parsedExpiry.toISOString();
        } else {
            expiredAtUtc = new Date(Date.now() + 30 * 60 * 1000).toISOString();
        }

        const {data: updatedPayment, error: paymentUpdateError} = await dbClient
            .from("payments")
            .update({
                provider_transaction_id: transaction_id,
                raw_response: midtransResult.data,
                expired_at: expiredAtUtc,
            })
            .eq("id", payment.id)
            .select()
            .single();

        if (paymentUpdateError || !updatedPayment) {
            await dbClient.rpc("rollback_order_flash_sale_quota", {p_order_id: order.id});
            await dbClient.rpc("rollback_voucher_quota", {p_order_id: order.id});
            await dbClient.from("payments").update({status: "failed"}).eq("id", payment.id);
            await dbClient
                .from("orders")
                .update({status: "cancelled", payment_status: "failed"})
                .eq("id", order.id);

            return jsonResponse({error: "Failed to update payment transaction"}, 500);
        }

        return jsonResponse({
            success: true,
            order,
            payment: updatedPayment,
            midtrans: midtransResult.data,
        });
    } catch (error) {
        console.error(error);
        return jsonResponse({error: "Internal server error"}, 500);
    }
});
