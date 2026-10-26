-- Migration: Add driver_id to orders and implement atomic claim_logistics_order RPC
-- Ensures separation between Biteship external courier and local partner drivers

-- 1. Add driver_id column referencing public.users
ALTER TABLE public.orders
ADD COLUMN IF NOT EXISTS driver_id UUID REFERENCES public.users(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_orders_driver_id ON public.orders(driver_id);
CREATE INDEX IF NOT EXISTS idx_orders_courier_code ON public.orders(courier_code);

-- 2. Atomic Order Claiming RPC for Drivers (Ekspedisi & Ojek)
CREATE OR REPLACE FUNCTION public.claim_logistics_order(
    p_order_id UUID,
    p_driver_name TEXT,
    p_driver_phone TEXT,
    p_vehicle_plate TEXT,
    p_latitude DOUBLE PRECISION DEFAULT NULL,
    p_longitude DOUBLE PRECISION DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_user_role TEXT;
    v_order RECORD;
    v_active_count INT;
    v_history JSONB;
    v_new_event JSONB;
    v_updated_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: User must be authenticated';
    END IF;

    SELECT role INTO v_user_role FROM public.users WHERE id = v_user_id;
    IF v_user_role NOT IN ('ojek', 'ekspedisi', 'admin') THEN
        RAISE EXCEPTION 'Akses ditolak: Hanya mitra logistik terdaftar yang dapat mengambil penugasan';
    END IF;

    SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pesanan tidak ditemukan';
    END IF;

    -- Security Guard: Biteship managed order protection
    IF v_order.biteship_order_id IS NOT NULL OR COALESCE(v_order.courier_code, '') IN ('jne', 'sicepat', 'jnt', 'anteraja') THEN
        RAISE EXCEPTION 'Pesanan ini dikelola otomatis oleh Biteship dan tidak dapat diambil manual';
    END IF;

    -- Guard: Order already taken by another driver
    IF v_order.driver_id IS NOT NULL THEN
        RAISE EXCEPTION 'Pesanan ini baru saja diambil oleh driver lain';
    END IF;

    -- Guard: Hoarding protection (max 3 concurrent active deliveries per driver)
    SELECT COUNT(*) INTO v_active_count
    FROM public.orders
    WHERE driver_id = v_user_id
      AND tracking_status IN ('picking_up', 'picked', 'dropping_off');

    IF v_active_count >= 3 THEN
        RAISE EXCEPTION 'Anda memiliki % pesanan aktif yang belum selesai. Selesaikan pengantaran sebelum mengambil pesanan baru.', v_active_count;
    END IF;

    -- Prepare event history
    v_history := COALESCE(v_order.tracking_history, '[]'::jsonb);
    v_new_event := jsonb_build_object(
        'status', 'picking_up',
        'note', 'Pesanan diterima & dijemput oleh ' || COALESCE(p_driver_name, 'Driver Mitra'),
        'updated_by', v_user_id,
        'role', v_user_role,
        'latitude', p_latitude,
        'longitude', p_longitude,
        'timestamp', NOW()
    );
    v_history := v_history || jsonb_build_array(v_new_event);

    -- Atomic update
    UPDATE public.orders
    SET
        driver_id = v_user_id,
        driver_name = COALESCE(NULLIF(p_driver_name, ''), driver_name),
        driver_phone = COALESCE(NULLIF(p_driver_phone, ''), driver_phone),
        driver_vehicle_plate = COALESCE(NULLIF(p_vehicle_plate, ''), driver_vehicle_plate),
        driver_latitude = COALESCE(p_latitude, driver_latitude),
        driver_longitude = COALESCE(p_longitude, driver_longitude),
        tracking_status = 'picking_up',
        status = 'shipped',
        tracking_history = v_history,
        driver_last_updated = NOW(),
        updated_at = NOW()
    WHERE id = p_order_id
      AND driver_id IS NULL
    RETURNING id INTO v_updated_id;

    IF v_updated_id IS NULL THEN
        RAISE EXCEPTION 'Pesanan ini baru saja diambil oleh driver lain';
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'order_id', p_order_id,
        'driver_id', v_user_id,
        'tracking_status', 'picking_up',
        'message', 'Pesanan berhasil Anda ambil'
    );
END;
$$;

-- 3. Update update_logistics_shipment to enforce driver ownership
CREATE OR REPLACE FUNCTION public.update_logistics_shipment(
    p_order_id UUID,
    p_status TEXT,
    p_waybill_id TEXT DEFAULT NULL,
    p_driver_name TEXT DEFAULT NULL,
    p_driver_phone TEXT DEFAULT NULL,
    p_vehicle_plate TEXT DEFAULT NULL,
    p_latitude DOUBLE PRECISION DEFAULT NULL,
    p_longitude DOUBLE PRECISION DEFAULT NULL,
    p_note TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_user_role TEXT;
    v_order RECORD;
    v_history JSONB;
    v_new_event JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    SELECT role INTO v_user_role FROM public.users WHERE id = v_user_id;

    SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pesanan tidak ditemukan';
    END IF;

    -- Security Guard: Driver can only update their own order unless admin/store owner
    IF v_order.driver_id IS NOT NULL 
       AND v_order.driver_id != v_user_id 
       AND COALESCE(v_user_role, '') NOT IN ('admin') THEN
        RAISE EXCEPTION 'Anda tidak memiliki wewenang untuk memperbarui pesanan mitra lain';
    END IF;

    v_history := COALESCE(v_order.tracking_history, '[]'::jsonb);
    v_new_event := jsonb_build_object(
        'status', p_status,
        'note', COALESCE(p_note, 'Pembaruan oleh ' || COALESCE(v_user_role, 'kurir')),
        'updated_by', v_user_id,
        'role', v_user_role,
        'latitude', p_latitude,
        'longitude', p_longitude,
        'timestamp', NOW()
    );
    v_history := v_history || jsonb_build_array(v_new_event);

    UPDATE public.orders
    SET 
        tracking_status = COALESCE(p_status, tracking_status),
        status = CASE 
            WHEN p_status IN ('delivered', 'completed') THEN 'completed'
            WHEN p_status IN ('cancelled', 'rejected') THEN 'cancelled'
            WHEN p_status IN ('picking_up', 'picked', 'dropping_off', 'on_delivery') THEN 'shipped'
            ELSE status
        END,
        driver_id = COALESCE(driver_id, v_user_id),
        waybill_id = COALESCE(NULLIF(p_waybill_id, ''), waybill_id),
        driver_name = COALESCE(NULLIF(p_driver_name, ''), driver_name),
        driver_phone = COALESCE(NULLIF(p_driver_phone, ''), driver_phone),
        driver_vehicle_plate = COALESCE(NULLIF(p_vehicle_plate, ''), driver_vehicle_plate),
        driver_latitude = COALESCE(p_latitude, driver_latitude),
        driver_longitude = COALESCE(p_longitude, driver_longitude),
        tracking_history = v_history,
        driver_last_updated = NOW(),
        updated_at = NOW()
    WHERE id = p_order_id;

    RETURN jsonb_build_object(
        'success', true,
        'order_id', p_order_id,
        'tracking_status', p_status,
        'waybill_id', COALESCE(p_waybill_id, v_order.waybill_id)
    );
END;
$$;

-- 4. Update cancel_logistics_shipment: Release back to pool if picking_up
CREATE OR REPLACE FUNCTION public.cancel_logistics_shipment(
    p_order_id UUID,
    p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_user_role TEXT;
    v_order RECORD;
    v_history JSONB;
    v_new_event JSONB;
    v_release_to_pool BOOLEAN;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    SELECT role INTO v_user_role FROM public.users WHERE id = v_user_id;

    SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pesanan tidak ditemukan';
    END IF;

    -- Security Guard: Driver check
    IF v_order.driver_id IS NOT NULL 
       AND v_order.driver_id != v_user_id 
       AND COALESCE(v_user_role, '') NOT IN ('admin') THEN
        RAISE EXCEPTION 'Anda tidak memiliki wewenang untuk membatalkan pesanan mitra lain';
    END IF;

    IF v_order.tracking_status = 'delivered' OR v_order.status = 'completed' THEN
        RAISE EXCEPTION 'Pesanan yang telah sampai tidak dapat dibatalkan';
    END IF;

    -- Edge case: If driver cancels while picking up, release back to pool so other drivers can pick it
    v_release_to_pool := (v_order.tracking_status = 'picking_up');

    v_history := COALESCE(v_order.tracking_history, '[]'::jsonb);
    v_new_event := jsonb_build_object(
        'status', CASE WHEN v_release_to_pool THEN 'unassigned_by_driver' ELSE 'cancelled_by_courier' END,
        'note', CASE 
            WHEN v_release_to_pool THEN 'Driver membatalkan jemputan: ' || COALESCE(p_reason, 'Kendala di perjalanan') || '. Pesanan dikembalikan ke antrean penugasan.'
            ELSE 'Pembatalan pengiriman: ' || COALESCE(p_reason, 'Kendala operasional mitra logistik')
        END,
        'updated_by', v_user_id,
        'role', v_user_role,
        'timestamp', NOW()
    );
    v_history := v_history || jsonb_build_array(v_new_event);

    IF v_release_to_pool THEN
        UPDATE public.orders
        SET 
            driver_id = NULL,
            tracking_status = 'pending',
            status = 'processing',
            tracking_history = v_history,
            driver_last_updated = NOW(),
            updated_at = NOW()
        WHERE id = p_order_id;

        RETURN jsonb_build_object(
            'success', true,
            'order_id', p_order_id,
            'released', true,
            'message', 'Penugasan dilepas dan dikembalikan ke antrean'
        );
    ELSE
        UPDATE public.orders
        SET 
            tracking_status = 'cancelled',
            status = 'cancelled',
            tracking_history = v_history,
            driver_last_updated = NOW(),
            updated_at = NOW()
        WHERE id = p_order_id;

        RETURN jsonb_build_object(
            'success', true,
            'order_id', p_order_id,
            'released', false,
            'message', 'Pengiriman berhasil dibatalkan oleh logistik'
        );
    END IF;
END;
$$;

-- Grant execution permissions
GRANT EXECUTE ON FUNCTION public.claim_logistics_order(UUID, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.update_logistics_shipment(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.cancel_logistics_shipment(UUID, TEXT) TO authenticated, service_role;
