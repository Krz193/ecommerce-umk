-- ==============================================================================
-- Migration: 20261121000100_shipments_tracking_biteship_batch.sql
-- Description:
--   1. Extend public.stores with province, city, district for Biteship Area alignment
--   2. Snapshot sender/origin fields on public.orders (+ backfill existing orders)
--   3. Add SECURITY DEFINER helper user_has_order_with_store & RLS policies for
--      stores, orders, order_items, payments (supporting Store Assistants & Logistics)
--   4. Update update_logistics_shipment RPC to support p_checkpoint_name and
--      protect Biteship-managed orders
--   5. Tighten append_order_driver_message RPC authorization & closed-order guard
-- ==============================================================================

-- 1. Extend public.stores with administrative area columns
ALTER TABLE public.stores
ADD COLUMN IF NOT EXISTS province TEXT NULL,
ADD COLUMN IF NOT EXISTS city TEXT NULL,
ADD COLUMN IF NOT EXISTS district TEXT NULL;

-- 2. Extend public.orders with origin/sender snapshot columns
ALTER TABLE public.orders
ADD COLUMN IF NOT EXISTS origin_contact_name TEXT NULL,
ADD COLUMN IF NOT EXISTS origin_phone TEXT NULL,
ADD COLUMN IF NOT EXISTS origin_address TEXT NULL,
ADD COLUMN IF NOT EXISTS origin_city TEXT NULL,
ADD COLUMN IF NOT EXISTS origin_postal_code TEXT NULL,
ADD COLUMN IF NOT EXISTS origin_notes TEXT NULL,
ADD COLUMN IF NOT EXISTS origin_latitude DOUBLE PRECISION NULL,
ADD COLUMN IF NOT EXISTS origin_longitude DOUBLE PRECISION NULL;

-- Backfill origin snapshot columns for historical orders from stores
UPDATE public.orders o
SET
    origin_contact_name = COALESCE(o.origin_contact_name, s.name),
    origin_phone = COALESCE(o.origin_phone, s.phone),
    origin_address = COALESCE(o.origin_address, s.address),
    origin_city = COALESCE(o.origin_city, s.city),
    origin_postal_code = COALESCE(o.origin_postal_code, s.postal_code),
    origin_notes = COALESCE(o.origin_notes, s.notes),
    origin_area_id = COALESCE(o.origin_area_id, s.biteship_area_id),
    origin_latitude = COALESCE(o.origin_latitude, s.latitude),
    origin_longitude = COALESCE(o.origin_longitude, s.longitude)
FROM public.stores s
WHERE o.store_id = s.id
  AND (
      o.origin_contact_name IS NULL
      OR o.origin_phone IS NULL
      OR o.origin_address IS NULL
      OR o.origin_latitude IS NULL
      OR o.origin_longitude IS NULL
  );

-- 3. SECURITY DEFINER helper & RLS policies
CREATE OR REPLACE FUNCTION public.user_has_order_with_store(
    p_store_id UUID,
    p_user_id UUID
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.orders o
        WHERE o.store_id = p_store_id
          AND (
              o.user_id = p_user_id
              OR o.driver_id = p_user_id
              OR (
                  o.driver_id IS NULL
                  AND o.biteship_order_id IS NULL
                  AND (public.is_ekspedisi() OR public.is_ojek())
              )
          )
    );
$$;

REVOKE EXECUTE ON FUNCTION public.user_has_order_with_store(UUID, UUID) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.user_has_order_with_store(UUID, UUID) TO authenticated;

DROP POLICY IF EXISTS "Users with order can view store profile" ON public.stores;
CREATE POLICY "Users with order can view store profile"
ON public.stores FOR SELECT TO authenticated
USING (
    public.user_has_order_with_store(id, auth.uid())
);

-- Ensure Store Assistants have non-recursive RLS policies on orders, order_items, payments
DROP POLICY IF EXISTS "Store assistants can view store orders" ON public.orders;
CREATE POLICY "Store assistants can view store orders"
ON public.orders FOR SELECT TO authenticated
USING (
    public.is_store_assistant_user(store_id, auth.uid())
);

DROP POLICY IF EXISTS "Store assistants can update store orders" ON public.orders;
CREATE POLICY "Store assistants can update store orders"
ON public.orders FOR UPDATE TO authenticated
USING (
    public.is_store_assistant_user(store_id, auth.uid())
)
WITH CHECK (
    public.is_store_assistant_user(store_id, auth.uid())
);

DROP POLICY IF EXISTS "Store assistants can view store order items" ON public.order_items;
CREATE POLICY "Store assistants can view store order items"
ON public.order_items FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.orders o
        WHERE o.id = order_items.order_id
          AND public.is_store_assistant_user(o.store_id, auth.uid())
    )
);

DROP POLICY IF EXISTS "Store assistants can view store payments" ON public.payments;
CREATE POLICY "Store assistants can view store payments"
ON public.payments FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.orders o
        WHERE o.id = payments.order_id
          AND public.is_store_assistant_user(o.store_id, auth.uid())
    )
);

-- 4. Update update_logistics_shipment to support checkpoint_name & Biteship guard
DROP FUNCTION IF EXISTS public.update_logistics_shipment(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT);
DROP FUNCTION IF EXISTS public.update_logistics_shipment(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.update_logistics_shipment(
    p_order_id UUID,
    p_status TEXT,
    p_waybill_id TEXT DEFAULT NULL,
    p_driver_name TEXT DEFAULT NULL,
    p_driver_phone TEXT DEFAULT NULL,
    p_vehicle_plate TEXT DEFAULT NULL,
    p_latitude DOUBLE PRECISION DEFAULT NULL,
    p_longitude DOUBLE PRECISION DEFAULT NULL,
    p_note TEXT DEFAULT NULL,
    p_checkpoint_name TEXT DEFAULT NULL
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
    IF COALESCE(v_user_role, '') NOT IN ('ekspedisi', 'ojek', 'admin') THEN
        RAISE EXCEPTION 'Forbidden: Hanya mitra logistik atau admin yang dapat memperbarui pengiriman';
    END IF;

    SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pesanan tidak ditemukan';
    END IF;

    -- Security Guard: Biteship managed orders cannot be mutated manually by local drivers
    IF v_order.biteship_order_id IS NOT NULL AND COALESCE(v_user_role, '') != 'admin' THEN
        RAISE EXCEPTION 'Pesanan ini dikelola otomatis oleh Biteship';
    END IF;

    -- Security Guard: Driver can only update their own order unless admin
    IF v_order.driver_id IS NOT NULL
       AND v_order.driver_id != v_user_id
       AND COALESCE(v_user_role, '') != 'admin' THEN
        RAISE EXCEPTION 'Anda tidak memiliki wewenang untuk memperbarui pesanan mitra lain';
    END IF;

    v_history := COALESCE(v_order.tracking_history, '[]'::jsonb);
    v_new_event := jsonb_build_object(
        'status', p_status,
        'checkpoint_name', NULLIF(TRIM(p_checkpoint_name), ''),
        'note', COALESCE(NULLIF(TRIM(p_note), ''), 'Pembaruan oleh ' || COALESCE(v_user_role, 'kurir')),
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
        shipped_at = CASE
            WHEN p_status IN ('picking_up', 'picked', 'dropping_off', 'on_delivery') AND shipped_at IS NULL THEN NOW()
            ELSE shipped_at
        END,
        completed_at = CASE
            WHEN p_status IN ('delivered', 'completed') AND completed_at IS NULL THEN NOW()
            ELSE completed_at
        END,
        driver_id = COALESCE(driver_id, v_user_id),
        waybill_id = COALESCE(NULLIF(p_waybill_id, ''), waybill_id),
        tracking_number = COALESCE(NULLIF(p_waybill_id, ''), tracking_number),
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
        'checkpoint_name', NULLIF(TRIM(p_checkpoint_name), ''),
        'waybill_id', COALESCE(p_waybill_id, v_order.waybill_id)
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_logistics_shipment(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, TEXT) TO authenticated, service_role;

-- 5. Tighten append_order_driver_message RPC authorization & closed-order guard
DROP FUNCTION IF EXISTS public.append_order_driver_message(UUID, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.append_order_driver_message(UUID, TEXT, TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.append_order_driver_message(
    p_order_id UUID,
    p_message TEXT,
    p_sender_role TEXT DEFAULT 'buyer',
    p_sender_name TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_order public.orders;
    v_user public.users;
    v_entry JSONB;
    v_updated JSONB;
    v_sender_name TEXT;
    v_role TEXT;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;

    IF COALESCE(TRIM(p_message), '') = '' THEN
        RAISE EXCEPTION 'Pesan tidak boleh kosong';
    END IF;

    SELECT * INTO v_user FROM public.users WHERE id = auth.uid();
    SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pesanan tidak ditemukan';
    END IF;

    -- Lifecycle guard: block new messages once completed, delivered, or cancelled
    IF v_order.status IN ('completed', 'cancelled')
       OR COALESCE(v_order.tracking_status, '') IN ('delivered', 'cancelled')
    THEN
        RAISE EXCEPTION 'Percakapan pengiriman sudah ditutup karena pesanan telah selesai atau dibatalkan';
    END IF;

    -- Strict authorization check scoped strictly to this order's parties:
    -- 1. Buyer of this order (v_order.user_id = auth.uid())
    -- 2. Assigned driver of this order (v_order.driver_id = auth.uid())
    -- 3. Store owner of this order's store
    -- 4. Assigned store assistant of this order's store
    -- 5. Admin
    IF v_order.user_id != auth.uid()
       AND COALESCE(v_order.driver_id, '00000000-0000-0000-0000-000000000000'::uuid) != auth.uid()
       AND NOT EXISTS (
           SELECT 1 FROM public.stores s
           WHERE s.id = v_order.store_id AND s.owner_id = auth.uid()
       )
       AND NOT public.is_store_assistant_user(v_order.store_id, auth.uid())
       AND COALESCE(v_user.role, '') != 'admin'
    THEN
        RAISE EXCEPTION 'Tidak memiliki akses ke percakapan pengiriman pesanan ini';
    END IF;

    v_role := COALESCE(NULLIF(TRIM(p_sender_role), ''), v_user.role, 'buyer');
    v_sender_name := COALESCE(
        NULLIF(TRIM(p_sender_name), ''),
        NULLIF(TRIM(v_user.full_name), ''),
        CASE
            WHEN v_role IN ('ojek', 'driver', 'ekspedisi') THEN 'Kurir / Ojek'
            WHEN v_role IN ('seller', 'assistant') THEN 'Penjual'
            ELSE 'Pengguna'
        END
    );

    v_entry := jsonb_build_object(
        'id', gen_random_uuid()::text,
        'sender_id', auth.uid()::text,
        'sender_name', v_sender_name,
        'sender_role', v_role,
        'message', TRIM(p_message),
        'sent_at', NOW()
    );

    v_updated := COALESCE(v_order.driver_messages, '[]'::jsonb) || jsonb_build_array(v_entry);

    UPDATE public.orders
    SET driver_messages = v_updated,
        updated_at = NOW()
    WHERE id = p_order_id;

    RETURN v_updated;
END;
$$;

GRANT EXECUTE ON FUNCTION public.append_order_driver_message(UUID, TEXT, TEXT, TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';
