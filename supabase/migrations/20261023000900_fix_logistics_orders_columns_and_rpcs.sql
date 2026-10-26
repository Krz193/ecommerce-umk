-- ==============================================================================
-- Migration: 20261023000900_fix_logistics_orders_columns_and_rpcs.sql
-- Description:
--   1. Add driver_vehicle_plate and driver_last_updated to orders
--   2. Fix update_logistics_shipment & cancel_logistics_shipment to use tracking_status and status
-- ==============================================================================

-- 1. Add missing logistics driver columns to orders
ALTER TABLE public.orders
ADD COLUMN IF NOT EXISTS driver_vehicle_plate TEXT NULL,
ADD COLUMN IF NOT EXISTS driver_last_updated TIMESTAMPTZ NULL;

-- 2. Update RPC update_logistics_shipment
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

    SELECT * INTO v_order FROM public.orders WHERE id = p_order_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pesanan tidak ditemukan';
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

-- 3. Update RPC cancel_logistics_shipment
CREATE OR REPLACE FUNCTION public.cancel_logistics_shipment(
    p_order_id UUID,
    p_reason TEXT
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

    SELECT * INTO v_order FROM public.orders WHERE id = p_order_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pesanan tidak ditemukan';
    END IF;

    IF v_order.tracking_status = 'delivered' OR v_order.status = 'completed' THEN
        RAISE EXCEPTION 'Pesanan yang telah sampai tidak dapat dibatalkan';
    END IF;

    v_history := COALESCE(v_order.tracking_history, '[]'::jsonb);
    v_new_event := jsonb_build_object(
        'status', 'cancelled_by_courier',
        'note', 'Pembatalan pengiriman: ' || COALESCE(p_reason, 'Kendala operasional mitra logistik'),
        'updated_by', v_user_id,
        'role', v_user_role,
        'timestamp', NOW()
    );
    v_history := v_history || jsonb_build_array(v_new_event);

    UPDATE public.orders
    SET 
        tracking_status = 'cancelled',
        tracking_history = v_history,
        driver_last_updated = NOW(),
        updated_at = NOW()
    WHERE id = p_order_id;

    RETURN jsonb_build_object(
        'success', true,
        'order_id', p_order_id,
        'message', 'Pengiriman berhasil dibatalkan oleh logistik'
    );
END;
$$;
