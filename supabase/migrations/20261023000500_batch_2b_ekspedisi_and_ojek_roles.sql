-- ==============================================================================
-- Migration: 20261023000500_batch_2b_ekspedisi_and_ojek_roles.sql
-- Features #13 (Ekspedisi) & #14 (Ojek)
-- Description:
--   1. Expand role check constraint on auth & users: buyer, seller, assistant, ekspedisi, ojek, admin
--   2. RBAC Roles & Permissions for ekspedisi and ojek
--   3. RPCs for logistics partner workflow:
--      - public.is_ekspedisi(), public.is_ojek()
--      - public.become_logistics_partner(p_role TEXT)
--      - public.update_logistics_shipment(...)
--      - public.cancel_logistics_shipment(p_order_id UUID, p_reason TEXT)
--   4. RLS policies allowing ekspedisi & ojek to inspect & process assigned or unassigned paid orders
-- ==============================================================================

-- 1. Ensure role check allows ekspedisi and ojek on profiles/users if check constraint exists
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'users_role_check'
    ) THEN
        ALTER TABLE public.users DROP CONSTRAINT users_role_check;
        ALTER TABLE public.users ADD CONSTRAINT users_role_check 
            CHECK (role IN ('buyer', 'seller', 'assistant', 'ekspedisi', 'ojek', 'admin'));
    END IF;
END $$;

-- 2. Insert RBAC roles if rbac_roles table exists
INSERT INTO public.rbac_roles (name, description, is_system)
VALUES 
    ('ekspedisi', 'Mitra Kurir Ekspedisi non-Biteship / Eksternal', true),
    ('ojek', 'Mitra Pengemudi Ojek Lokal / Instan', true)
ON CONFLICT (name) DO NOTHING;

-- 3. Helper functions for role identification
CREATE OR REPLACE FUNCTION public.is_ekspedisi()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.users
        WHERE id = auth.uid() AND role = 'ekspedisi'
    );
$$;

CREATE OR REPLACE FUNCTION public.is_ojek()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.users
        WHERE id = auth.uid() AND role = 'ojek'
    );
$$;

-- 4. RPC to switch/register role for logistics partner (Ekspedisi / Ojek)
CREATE OR REPLACE FUNCTION public.become_logistics_partner(p_role TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: User must be authenticated';
    END IF;

    IF p_role NOT IN ('ekspedisi', 'ojek') THEN
        RAISE EXCEPTION 'Invalid role: Must be ekspedisi or ojek';
    END IF;

    UPDATE public.users
    SET role = p_role,
        updated_at = NOW()
    WHERE id = v_user_id;

    RETURN jsonb_build_object(
        'success', true,
        'user_id', v_user_id,
        'role', p_role,
        'message', 'Peran mitra logistik berhasil diperbarui'
    );
END;
$$;

-- 5. RPC: Update logistics shipment (Waybill, Status, GPS location, Tracking history)
-- Used by Ekspedisi (#13) and Ojek (#14)
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
    IF v_user_role NOT IN ('ekspedisi', 'ojek', 'admin') THEN
        RAISE EXCEPTION 'Forbidden: Hanya ekspedisi, ojek, atau admin yang dapat memperbarui pengiriman';
    END IF;

    SELECT * INTO v_order FROM public.orders WHERE id = p_order_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pesanan tidak ditemukan';
    END IF;

    v_history := COALESCE(v_order.tracking_history, '[]'::jsonb);
    v_new_event := jsonb_build_object(
        'status', p_status,
        'note', COALESCE(p_note, 'Pembaruan oleh ' || v_user_role),
        'updated_by', v_user_id,
        'role', v_user_role,
        'latitude', p_latitude,
        'longitude', p_longitude,
        'timestamp', NOW()
    );
    v_history := v_history || jsonb_build_array(v_new_event);

    UPDATE public.orders
    SET 
        delivery_status = COALESCE(p_status, delivery_status),
        order_status = CASE 
            WHEN p_status IN ('delivered', 'completed') THEN 'completed'
            WHEN p_status IN ('cancelled', 'rejected') THEN 'cancelled'
            ELSE 'processing'
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
        'delivery_status', p_status,
        'waybill_id', COALESCE(p_waybill_id, v_order.waybill_id)
    );
END;
$$;

-- 6. RPC: Cancel logistics shipment by Ekspedisi / Ojek with operational reason (#13 requirement 4)
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
    IF v_user_role NOT IN ('ekspedisi', 'ojek', 'admin') THEN
        RAISE EXCEPTION 'Forbidden: Hanya mitra logistik yang dapat membatalkan penugasan ini';
    END IF;

    SELECT * INTO v_order FROM public.orders WHERE id = p_order_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pesanan tidak ditemukan';
    END IF;

    IF v_order.delivery_status = 'delivered' THEN
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
        delivery_status = 'cancelled',
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

-- 7. Grant permissions
GRANT EXECUTE ON FUNCTION public.is_ekspedisi() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.is_ojek() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.become_logistics_partner(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_logistics_shipment(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_logistics_shipment(UUID, TEXT) TO authenticated;

-- 8. Add RLS policy for orders visibility for ekspedisi & ojek
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'orders' AND policyname = 'ekspedisi_and_ojek_view_orders'
    ) THEN
        CREATE POLICY ekspedisi_and_ojek_view_orders
            ON public.orders
            FOR SELECT
            TO authenticated
            USING (
                public.is_ekspedisi() OR public.is_ojek()
            );
    END IF;
END $$;
