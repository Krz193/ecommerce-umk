-- ==============================================================================
-- Migration: 20261125000100_batch_1_security_and_local_shipping.sql
-- Description (Batch 1 Security & Financial Integrity + UMKM Optional Local Shipping):
--   1. Drop insecure client-side order shipping RPC/policy & logistics self-elevation RPC
--   2. Add optional UMKM local shipping settings (ojek_lokal & ekspedisi_lokal tiers) to stores
--   3. Create store_couriers table + management RPCs to bind couriers to UMKM stores
--   4. Tighten logistics RLS & claim_logistics_order RPC (require paid + store_couriers match)
--   5. Harden store_vouchers constraints, validate_and_apply_voucher RPC, & atomic quota RPCs
--   6. Add server-authoritative WebRTC call authorization RPC + realtime.messages RLS
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ------------------------------------------------------------------------------
-- 1. DROP INSECURE CLIENT MUTATION PATHS & SELF-ELEVATION RPC
-- ------------------------------------------------------------------------------

DROP FUNCTION IF EXISTS public.set_order_shipping_details(UUID, TEXT, TEXT, TEXT, TEXT, NUMERIC);
DROP POLICY IF EXISTS "Users can update own pending orders" ON public.orders;
DROP FUNCTION IF EXISTS public.become_logistics_partner(TEXT);

-- ------------------------------------------------------------------------------
-- 2. OPTIONAL UMKM LOCAL SHIPPING CONFIGURATION ON STORES
-- ------------------------------------------------------------------------------

ALTER TABLE public.stores
ADD COLUMN IF NOT EXISTS local_ojek_enabled BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS local_ojek_rates JSONB NOT NULL DEFAULT '[]'::jsonb,
ADD COLUMN IF NOT EXISTS local_ekspedisi_enabled BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS local_ekspedisi_rates JSONB NOT NULL DEFAULT '[]'::jsonb;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'stores_local_ojek_rates_array_check'
    ) THEN
        ALTER TABLE public.stores
        ADD CONSTRAINT stores_local_ojek_rates_array_check
        CHECK (jsonb_typeof(local_ojek_rates) = 'array');
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'stores_local_ekspedisi_rates_array_check'
    ) THEN
        ALTER TABLE public.stores
        ADD CONSTRAINT stores_local_ekspedisi_rates_array_check
        CHECK (jsonb_typeof(local_ekspedisi_rates) = 'array');
    END IF;
END $$;

-- ------------------------------------------------------------------------------
-- 3. STORE COURIERS BINDING (UMKM-OWNED / ASSIGNED OJEK & EKSPEDISI)
-- ------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.store_couriers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    courier_type TEXT NOT NULL CHECK (courier_type IN ('ojek', 'ekspedisi')),
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_store_courier_assignment UNIQUE (store_id, user_id, courier_type)
);

CREATE INDEX IF NOT EXISTS idx_store_couriers_store_id
    ON public.store_couriers(store_id);
CREATE INDEX IF NOT EXISTS idx_store_couriers_user_lookup
    ON public.store_couriers(user_id, courier_type, is_active);

DROP TRIGGER IF EXISTS update_store_couriers_updated_at ON public.store_couriers;
CREATE TRIGGER update_store_couriers_updated_at
    BEFORE UPDATE ON public.store_couriers
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

ALTER TABLE public.store_couriers ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.store_couriers TO authenticated, service_role;

DROP POLICY IF EXISTS "Couriers can view own store assignments" ON public.store_couriers;
CREATE POLICY "Couriers can view own store assignments"
ON public.store_couriers FOR SELECT TO authenticated
USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Store managers can manage store couriers" ON public.store_couriers;
CREATE POLICY "Store managers can manage store couriers"
ON public.store_couriers FOR ALL TO authenticated
USING (
    public.is_store_owner(store_id)
    OR public.is_store_assistant_user(store_id, auth.uid())
    OR public.is_admin()
)
WITH CHECK (
    public.is_store_owner(store_id)
    OR public.is_store_assistant_user(store_id, auth.uid())
    OR public.is_admin()
);

-- Helper: Verify whether a user is an active assigned store courier matching the order's local courier type
CREATE OR REPLACE FUNCTION public.is_store_courier_for_order(
    p_store_id UUID,
    p_courier_code TEXT,
    p_courier_service_type TEXT,
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
        FROM public.store_couriers sc
        JOIN public.users u ON u.id = sc.user_id
        WHERE sc.store_id = p_store_id
          AND sc.user_id = p_user_id
          AND sc.is_active = true
          AND (
              (
                  sc.courier_type = 'ojek'
                  AND u.role = 'ojek'
                  AND LOWER(COALESCE(p_courier_code, '')) IN ('ojek', 'ojek_lokal', 'instant_lokal')
              )
              OR (
                  sc.courier_type = 'ekspedisi'
                  AND u.role = 'ekspedisi'
                  AND LOWER(COALESCE(p_courier_code, '')) IN ('ekspedisi', 'ekspedisi_lokal', 'kurir_toko', 'manual')
              )
          )
    );
$$;

REVOKE EXECUTE ON FUNCTION public.is_store_courier_for_order(UUID, TEXT, TEXT, UUID) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.is_store_courier_for_order(UUID, TEXT, TEXT, UUID) TO authenticated, service_role;

-- RPC: List assigned couriers for a store (authorized for store owner, assistant, or admin)
CREATE OR REPLACE FUNCTION public.get_store_couriers(p_store_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller UUID := auth.uid();
    v_result JSONB;
BEGIN
    IF v_caller IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    IF NOT public.is_store_owner(p_store_id)
       AND NOT public.is_store_assistant_user(p_store_id, v_caller)
       AND NOT public.is_admin()
    THEN
        RAISE EXCEPTION 'Forbidden: Tidak memiliki akses ke kurir toko ini';
    END IF;

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', sc.id,
                'store_id', sc.store_id,
                'user_id', sc.user_id,
                'courier_type', sc.courier_type,
                'is_active', sc.is_active,
                'full_name', u.full_name,
                'phone', u.phone,
                'role', u.role,
                'email', au.email,
                'created_at', sc.created_at
            )
            ORDER BY sc.created_at DESC
        ),
        '[]'::jsonb
    )
    INTO v_result
    FROM public.store_couriers sc
    JOIN public.users u ON u.id = sc.user_id
    LEFT JOIN auth.users au ON au.id = sc.user_id
    WHERE sc.store_id = p_store_id;

    RETURN v_result;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_store_couriers(UUID) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.get_store_couriers(UUID) TO authenticated;

-- RPC: Assign an existing courier account (role = ojek | ekspedisi) to a store by email
CREATE OR REPLACE FUNCTION public.assign_store_courier_by_email(
    p_store_id UUID,
    p_email TEXT,
    p_courier_type TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller UUID := auth.uid();
    v_clean_email TEXT := LOWER(TRIM(COALESCE(p_email, '')));
    v_target_user RECORD;
    v_assignment public.store_couriers;
BEGIN
    IF v_caller IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    IF p_courier_type NOT IN ('ojek', 'ekspedisi') THEN
        RAISE EXCEPTION 'Jenis kurir harus ojek atau ekspedisi';
    END IF;

    IF v_clean_email = '' THEN
        RAISE EXCEPTION 'Email akun kurir wajib diisi';
    END IF;

    IF NOT public.is_store_owner(p_store_id)
       AND NOT public.is_store_assistant_user(p_store_id, v_caller)
       AND NOT public.is_admin()
    THEN
        RAISE EXCEPTION 'Forbidden: Tidak memiliki akses mengelola kurir toko ini';
    END IF;

    SELECT u.id, u.full_name, u.phone, u.role, au.email
    INTO v_target_user
    FROM auth.users au
    JOIN public.users u ON u.id = au.id
    WHERE LOWER(au.email) = v_clean_email
    LIMIT 1;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Akun dengan email % tidak ditemukan', v_clean_email;
    END IF;

    IF v_target_user.role <> p_courier_type THEN
        RAISE EXCEPTION 'Akun % memiliki role "%". Hanya akun dengan role "%" (ditetapkan oleh Admin) yang dapat ditugaskan.',
            v_clean_email, v_target_user.role, p_courier_type;
    END IF;

    INSERT INTO public.store_couriers (store_id, user_id, courier_type, is_active)
    VALUES (p_store_id, v_target_user.id, p_courier_type, true)
    ON CONFLICT (store_id, user_id, courier_type)
    DO UPDATE SET is_active = true, updated_at = NOW()
    RETURNING * INTO v_assignment;

    RETURN jsonb_build_object(
        'id', v_assignment.id,
        'store_id', v_assignment.store_id,
        'user_id', v_assignment.user_id,
        'courier_type', v_assignment.courier_type,
        'is_active', v_assignment.is_active,
        'full_name', v_target_user.full_name,
        'phone', v_target_user.phone,
        'email', v_target_user.email
    );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.assign_store_courier_by_email(UUID, TEXT, TEXT) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.assign_store_courier_by_email(UUID, TEXT, TEXT) TO authenticated;

-- RPC: Remove courier assignment from store
CREATE OR REPLACE FUNCTION public.remove_store_courier(p_assignment_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller UUID := auth.uid();
    v_store_id UUID;
BEGIN
    IF v_caller IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    SELECT store_id INTO v_store_id
    FROM public.store_couriers
    WHERE id = p_assignment_id;

    IF NOT FOUND THEN
        RETURN false;
    END IF;

    IF NOT public.is_store_owner(v_store_id)
       AND NOT public.is_store_assistant_user(v_store_id, v_caller)
       AND NOT public.is_admin()
    THEN
        RAISE EXCEPTION 'Forbidden: Tidak memiliki akses menghapus kurir toko ini';
    END IF;

    DELETE FROM public.store_couriers WHERE id = p_assignment_id;
    RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.remove_store_courier(UUID) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.remove_store_courier(UUID) TO authenticated;

-- ------------------------------------------------------------------------------
-- 4. TIGHTEN LOGISTICS ORDER VISIBILITY RLS & CLAIM RPC
-- ------------------------------------------------------------------------------

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
                  AND o.payment_status = 'paid'
                  AND o.biteship_order_id IS NULL
                  AND public.is_store_courier_for_order(o.store_id, o.courier_code, o.courier_service_type, p_user_id)
              )
          )
    );
$$;

DROP POLICY IF EXISTS ekspedisi_and_ojek_view_orders ON public.orders;
CREATE POLICY ekspedisi_and_ojek_view_orders
ON public.orders
FOR SELECT
TO authenticated
USING (
    driver_id = auth.uid()
    OR (
        driver_id IS NULL
        AND payment_status = 'paid'
        AND biteship_order_id IS NULL
        AND status IN ('processing', 'pending')
        AND public.is_store_courier_for_order(store_id, courier_code, courier_service_type, auth.uid())
    )
);

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
    IF COALESCE(v_user_role, '') NOT IN ('ojek', 'ekspedisi', 'admin') THEN
        RAISE EXCEPTION 'Akses ditolak: Hanya mitra kurir terdaftar yang dapat mengambil penugasan';
    END IF;

    SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pesanan tidak ditemukan';
    END IF;

    IF v_order.payment_status <> 'paid' THEN
        RAISE EXCEPTION 'Pesanan belum lunas (paid) dan tidak dapat diklaim';
    END IF;

    IF v_order.status IN ('cancelled', 'completed') THEN
        RAISE EXCEPTION 'Pesanan sudah ditutup dan tidak dapat diklaim';
    END IF;

    IF v_order.biteship_order_id IS NOT NULL
       OR LOWER(COALESCE(v_order.courier_code, '')) IN ('gojek', 'grab', 'jne', 'sicepat', 'jnt', 'anteraja', 'paxel', 'ninja', 'lion', 'pos', 'tiki')
    THEN
        RAISE EXCEPTION 'Pesanan ini dikelola otomatis oleh kurir eksternal Biteship dan tidak dapat diambil manual';
    END IF;

    IF v_user_role <> 'admin' AND NOT public.is_store_courier_for_order(
        v_order.store_id,
        v_order.courier_code,
        v_order.courier_service_type,
        v_user_id
    ) THEN
        RAISE EXCEPTION 'Anda tidak terdaftar sebagai kurir toko untuk jenis layanan pesanan ini';
    END IF;

    IF v_order.driver_id IS NOT NULL THEN
        RAISE EXCEPTION 'Pesanan ini baru saja diambil oleh kurir lain';
    END IF;

    SELECT COUNT(*) INTO v_active_count
    FROM public.orders
    WHERE driver_id = v_user_id
      AND tracking_status IN ('picking_up', 'picked', 'dropping_off', 'on_delivery');

    IF v_active_count >= 3 THEN
        RAISE EXCEPTION 'Anda memiliki % pesanan aktif yang belum selesai. Selesaikan pengantaran sebelum mengambil pesanan baru.', v_active_count;
    END IF;

    v_history := COALESCE(v_order.tracking_history, '[]'::jsonb);
    v_new_event := jsonb_build_object(
        'status', 'picking_up',
        'note', 'Pesanan diterima & dijemput oleh ' || COALESCE(NULLIF(TRIM(p_driver_name), ''), 'Kurir Toko'),
        'updated_by', v_user_id,
        'role', v_user_role,
        'latitude', p_latitude,
        'longitude', p_longitude,
        'timestamp', NOW()
    );
    v_history := v_history || jsonb_build_array(v_new_event);

    UPDATE public.orders
    SET
        driver_id = v_user_id,
        driver_name = COALESCE(NULLIF(TRIM(p_driver_name), ''), driver_name),
        driver_phone = COALESCE(NULLIF(TRIM(p_driver_phone), ''), driver_phone),
        driver_vehicle_plate = COALESCE(NULLIF(TRIM(p_vehicle_plate), ''), driver_vehicle_plate),
        driver_latitude = COALESCE(p_latitude, driver_latitude),
        driver_longitude = COALESCE(p_longitude, driver_longitude),
        tracking_status = 'picking_up',
        status = 'shipped',
        shipped_at = COALESCE(shipped_at, NOW()),
        tracking_history = v_history,
        driver_last_updated = NOW(),
        updated_at = NOW()
    WHERE id = p_order_id
      AND driver_id IS NULL
      AND payment_status = 'paid'
    RETURNING id INTO v_updated_id;

    IF v_updated_id IS NULL THEN
        RAISE EXCEPTION 'Pesanan ini baru saja diambil oleh kurir lain';
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

REVOKE EXECUTE ON FUNCTION public.claim_logistics_order(UUID, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.claim_logistics_order(UUID, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 5. VOUCHER VALIDATION HARDENING & ATOMIC QUOTA RESERVATION
-- ------------------------------------------------------------------------------

UPDATE public.store_vouchers
SET min_purchase = 0
WHERE min_purchase IS NULL OR min_purchase < 0;

UPDATE public.store_vouchers
SET discount_value = 100
WHERE discount_type = 'percentage' AND discount_value > 100;

UPDATE public.store_vouchers
SET is_active = false
WHERE scope = 'product'
  AND (applicable_product_ids IS NULL OR COALESCE(array_length(applicable_product_ids, 1), 0) = 0);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'store_vouchers_min_purchase_nonneg'
    ) THEN
        ALTER TABLE public.store_vouchers
        ADD CONSTRAINT store_vouchers_min_purchase_nonneg
        CHECK (min_purchase >= 0);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'store_vouchers_percentage_cap'
    ) THEN
        ALTER TABLE public.store_vouchers
        ADD CONSTRAINT store_vouchers_percentage_cap
        CHECK (discount_type <> 'percentage' OR (discount_value > 0 AND discount_value <= 100));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'store_vouchers_product_scope_nonempty'
    ) THEN
        ALTER TABLE public.store_vouchers
        ADD CONSTRAINT store_vouchers_product_scope_nonempty
        CHECK (
            scope <> 'product'
            OR NOT is_active
            OR (applicable_product_ids IS NOT NULL AND array_length(applicable_product_ids, 1) > 0)
        );
    END IF;
END $$;

ALTER TABLE public.orders
ADD COLUMN IF NOT EXISTS voucher_quota_reserved BOOLEAN NOT NULL DEFAULT false;

CREATE OR REPLACE FUNCTION public.validate_and_apply_voucher(
    p_code TEXT,
    p_store_id UUID,
    p_subtotal NUMERIC,
    p_items JSONB DEFAULT '[]'::jsonb,
    p_user_id UUID DEFAULT auth.uid()
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_voucher RECORD;
    v_discount NUMERIC := 0;
    v_final_price NUMERIC := 0;
    v_clean_code TEXT := UPPER(TRIM(COALESCE(p_code, '')));
    v_item JSONB;
    v_item_prod_id UUID;
    v_item_price NUMERIC;
    v_item_qty INT;
    v_matched_count INT := 0;
    v_eligible_subtotal NUMERIC := 0;
    v_item_discount NUMERIC := 0;
    v_pct NUMERIC := 0;
BEGIN
    IF v_clean_code = '' THEN
        RETURN jsonb_build_object('valid', false, 'message', 'Kode voucher tidak boleh kosong');
    END IF;

    IF p_subtotal IS NULL OR p_subtotal <= 0 THEN
        RETURN jsonb_build_object('valid', false, 'message', 'Subtotal belanja tidak valid');
    END IF;

    SELECT * INTO v_voucher
    FROM public.store_vouchers
    WHERE store_id = p_store_id
      AND UPPER(code) = v_clean_code;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('valid', false, 'message', 'Kode voucher tidak ditemukan untuk toko ini');
    END IF;

    IF NOT v_voucher.is_active THEN
        RETURN jsonb_build_object('valid', false, 'message', 'Voucher ini sudah tidak aktif');
    END IF;

    IF v_voucher.start_date IS NOT NULL AND NOW() < v_voucher.start_date THEN
        RETURN jsonb_build_object('valid', false, 'message', 'Voucher ini belum memasuki periode berlaku');
    END IF;

    IF v_voucher.end_date IS NOT NULL AND NOW() > v_voucher.end_date THEN
        RETURN jsonb_build_object('valid', false, 'message', 'Masa berlaku voucher telah berakhir');
    END IF;

    IF v_voucher.usage_limit IS NOT NULL AND v_voucher.used_count >= v_voucher.usage_limit THEN
        RETURN jsonb_build_object('valid', false, 'message', 'Kuota pemakaian voucher telah habis');
    END IF;

    IF COALESCE(v_voucher.min_purchase, 0) < 0 THEN
        RETURN jsonb_build_object('valid', false, 'message', 'Konfigurasi minimal belanja voucher tidak valid');
    END IF;

    IF v_voucher.discount_type = 'percentage' AND (v_voucher.discount_value <= 0 OR v_voucher.discount_value > 100) THEN
        RETURN jsonb_build_object('valid', false, 'message', 'Konfigurasi persentase voucher tidak valid');
    END IF;

    IF v_voucher.min_purchase IS NOT NULL AND p_subtotal < v_voucher.min_purchase THEN
        RETURN jsonb_build_object(
            'valid', false,
            'message', 'Minimal belanja untuk voucher ini adalah Rp ' || TO_CHAR(v_voucher.min_purchase, 'FM999,999,999')
        );
    END IF;

    IF v_voucher.scope = 'product' THEN
        IF v_voucher.applicable_product_ids IS NULL
           OR COALESCE(array_length(v_voucher.applicable_product_ids, 1), 0) = 0
        THEN
            RETURN jsonb_build_object(
                'valid', false,
                'message', 'Voucher produk tidak memiliki daftar produk yang berlaku'
            );
        END IF;

        IF p_items IS NOT NULL AND jsonb_typeof(p_items) = 'array' AND jsonb_array_length(p_items) > 0 THEN
            FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
            LOOP
                v_item_prod_id := (v_item->>'product_id')::UUID;
                v_item_price := GREATEST(0, COALESCE((v_item->>'price')::NUMERIC, 0));
                v_item_qty := GREATEST(0, COALESCE((v_item->>'quantity')::INT, 0));

                IF v_item_qty > 0 AND v_item_prod_id = ANY(v_voucher.applicable_product_ids) THEN
                    v_matched_count := v_matched_count + 1;
                    v_eligible_subtotal := v_eligible_subtotal + (v_item_price * v_item_qty);

                    IF v_voucher.discount_type = 'nominal' THEN
                        v_item_discount := LEAST(v_item_price, v_voucher.discount_value) * v_item_qty;
                        v_discount := v_discount + v_item_discount;
                    ELSIF v_voucher.discount_type = 'percentage' THEN
                        v_pct := LEAST(100, GREATEST(0, v_voucher.discount_value));
                        v_item_discount := ((v_item_price * v_pct) / 100.0) * v_item_qty;
                        v_discount := v_discount + v_item_discount;
                    ELSIF v_voucher.discount_type = 'fixed_price' THEN
                        IF v_item_price > v_voucher.discount_value THEN
                            v_item_discount := (v_item_price - v_voucher.discount_value) * v_item_qty;
                            v_discount := v_discount + v_item_discount;
                        END IF;
                    END IF;
                END IF;
            END LOOP;

            IF v_voucher.discount_type = 'percentage'
               AND v_voucher.max_discount IS NOT NULL
               AND v_voucher.max_discount > 0
            THEN
                v_discount := LEAST(v_discount, v_voucher.max_discount);
            END IF;

            v_discount := LEAST(p_subtotal, v_eligible_subtotal, v_discount);
        END IF;

        IF v_matched_count = 0 THEN
            RETURN jsonb_build_object(
                'valid', false,
                'message', 'Voucher ini hanya berlaku untuk produk pilihan yang ditentukan penjual.'
            );
        END IF;
    ELSE
        IF v_voucher.discount_type = 'nominal' THEN
            v_discount := LEAST(p_subtotal, v_voucher.discount_value);
        ELSIF v_voucher.discount_type = 'percentage' THEN
            v_pct := LEAST(100, GREATEST(0, v_voucher.discount_value));
            v_discount := (p_subtotal * v_pct) / 100.0;
            IF v_voucher.max_discount IS NOT NULL AND v_voucher.max_discount > 0 THEN
                v_discount := LEAST(v_discount, v_voucher.max_discount);
            END IF;
            v_discount := LEAST(p_subtotal, v_discount);
        ELSIF v_voucher.discount_type = 'fixed_price' THEN
            IF p_subtotal > v_voucher.discount_value THEN
                v_discount := p_subtotal - v_voucher.discount_value;
            ELSE
                v_discount := 0;
            END IF;
        END IF;
    END IF;

    v_discount := ROUND(GREATEST(0, LEAST(p_subtotal, v_discount)));
    v_final_price := GREATEST(0, p_subtotal - v_discount);

    RETURN jsonb_build_object(
        'valid', true,
        'voucher_id', v_voucher.id,
        'code', v_voucher.code,
        'title', v_voucher.title,
        'scope', v_voucher.scope,
        'applicable_product_ids', v_voucher.applicable_product_ids,
        'matched_items_count', v_matched_count,
        'discount_type', v_voucher.discount_type,
        'discount_value', v_voucher.discount_value,
        'calculated_discount', v_discount,
        'final_subtotal', v_final_price,
        'message', 'Voucher berhasil diterapkan!'
    );
END;
$$;

-- Atomic Voucher Usage Quota Reservation & Idempotent Rollback (service_role only)
CREATE OR REPLACE FUNCTION public.reserve_voucher_quota(
    p_voucher_id UUID,
    p_order_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_updated_voucher UUID;
BEGIN
    UPDATE public.store_vouchers
    SET used_count = used_count + 1,
        updated_at = NOW()
    WHERE id = p_voucher_id
      AND is_active = true
      AND (start_date IS NULL OR NOW() >= start_date)
      AND (end_date IS NULL OR NOW() <= end_date)
      AND (usage_limit IS NULL OR used_count < usage_limit)
    RETURNING id INTO v_updated_voucher;

    IF v_updated_voucher IS NULL THEN
        RETURN false;
    END IF;

    UPDATE public.orders
    SET voucher_quota_reserved = true
    WHERE id = p_order_id;

    RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public.rollback_voucher_quota(p_order_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_order RECORD;
BEGIN
    SELECT id, voucher_id, voucher_quota_reserved
    INTO v_order
    FROM public.orders
    WHERE id = p_order_id
    FOR UPDATE;

    IF NOT FOUND OR v_order.voucher_id IS NULL OR NOT v_order.voucher_quota_reserved THEN
        RETURN false;
    END IF;

    UPDATE public.store_vouchers
    SET used_count = GREATEST(0, used_count - 1),
        updated_at = NOW()
    WHERE id = v_order.voucher_id;

    UPDATE public.orders
    SET voucher_quota_reserved = false
    WHERE id = p_order_id;

    RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.reserve_voucher_quota(UUID, UUID) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reserve_voucher_quota(UUID, UUID) TO service_role;

REVOKE EXECUTE ON FUNCTION public.rollback_voucher_quota(UUID) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rollback_voucher_quota(UUID) TO service_role;

-- ------------------------------------------------------------------------------
-- 6. WEBRTC SIGNALING CHANNEL AUTHORIZATION & REALTIME RLS
-- ------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.private_internal_secrets (
    key TEXT PRIMARY KEY,
    secret_value TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.private_internal_secrets ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.private_internal_secrets FROM public, anon, authenticated;

INSERT INTO public.private_internal_secrets (key, secret_value)
VALUES ('webrtc_channel_hmac_secret', encode(gen_random_bytes(32), 'hex'))
ON CONFLICT (key) DO NOTHING;

CREATE OR REPLACE FUNCTION public.is_order_call_participant(
    p_order_id UUID,
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
        LEFT JOIN public.users u ON u.id = p_user_id
        WHERE o.id = p_order_id
          AND o.biteship_order_id IS NULL
          AND o.status NOT IN ('completed', 'cancelled')
          AND COALESCE(o.tracking_status, '') NOT IN ('delivered', 'completed', 'cancelled')
          AND (
              o.user_id = p_user_id
              OR o.driver_id = p_user_id
              OR public.is_store_owner(o.store_id)
              OR public.is_store_assistant_user(o.store_id, p_user_id)
              OR COALESCE(u.role, '') = 'admin'
          )
    );
$$;

REVOKE EXECUTE ON FUNCTION public.is_order_call_participant(UUID, UUID) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.is_order_call_participant(UUID, UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.authorize_order_webrtc_call(p_order_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_order public.orders;
    v_user public.users;
    v_caller_role TEXT;
    v_secret TEXT;
    v_token TEXT;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;

    SELECT * INTO v_order FROM public.orders WHERE id = p_order_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pesanan tidak ditemukan';
    END IF;

    IF v_order.status IN ('completed', 'cancelled')
       OR COALESCE(v_order.tracking_status, '') IN ('delivered', 'completed', 'cancelled')
    THEN
        RAISE EXCEPTION 'Panggilan ditutup karena pesanan telah selesai atau dibatalkan';
    END IF;

    IF v_order.biteship_order_id IS NOT NULL THEN
        RAISE EXCEPTION 'Panggilan VoIP in-app hanya tersedia untuk kurir lokal toko';
    END IF;

    SELECT * INTO v_user FROM public.users WHERE id = v_uid;

    IF v_order.user_id = v_uid THEN
        v_caller_role := 'buyer';
    ELSIF v_order.driver_id = v_uid THEN
        v_caller_role := CASE WHEN v_user.role = 'ekspedisi' THEN 'ekspedisi' ELSE 'ojek' END;
    ELSIF public.is_store_owner(v_order.store_id) OR public.is_store_assistant_user(v_order.store_id, v_uid) THEN
        v_caller_role := 'seller';
    ELSIF COALESCE(v_user.role, '') = 'admin' THEN
        v_caller_role := 'admin';
    ELSE
        RAISE EXCEPTION 'Forbidden: Anda bukan peserta sah untuk panggilan pesanan ini';
    END IF;

    SELECT secret_value INTO v_secret
    FROM public.private_internal_secrets
    WHERE key = 'webrtc_channel_hmac_secret';

    v_token := encode(hmac(p_order_id::text, v_secret, 'sha256'), 'hex');

    RETURN jsonb_build_object(
        'authorized', true,
        'channel_topic', 'webrtc:order_' || p_order_id::text || '_' || substr(v_token, 1, 32),
        'caller_role', v_caller_role,
        'caller_name', COALESCE(NULLIF(TRIM(v_user.full_name), ''), 'Pengguna')
    );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.authorize_order_webrtc_call(UUID) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.authorize_order_webrtc_call(UUID) TO authenticated;

-- Second-layer defense on realtime.messages when Private Channel Broadcast RLS is active
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = 'realtime' AND table_name = 'messages'
    ) THEN
        EXECUTE 'DROP POLICY IF EXISTS "webrtc_order_participants_broadcast_select" ON realtime.messages';
        EXECUTE 'DROP POLICY IF EXISTS "webrtc_order_participants_broadcast_insert" ON realtime.messages';

        EXECUTE $pol$
            CREATE POLICY "webrtc_order_participants_broadcast_select"
            ON realtime.messages
            FOR SELECT
            TO authenticated
            USING (
                realtime.topic() NOT LIKE 'webrtc:order_%'
                OR (
                    substring(realtime.topic() FROM '^webrtc:order_([0-9a-fA-F-]{36})') IS NOT NULL
                    AND public.is_order_call_participant(
                        substring(realtime.topic() FROM '^webrtc:order_([0-9a-fA-F-]{36})')::uuid,
                        auth.uid()
                    )
                )
            )
        $pol$;

        EXECUTE $pol$
            CREATE POLICY "webrtc_order_participants_broadcast_insert"
            ON realtime.messages
            FOR INSERT
            TO authenticated
            WITH CHECK (
                realtime.topic() NOT LIKE 'webrtc:order_%'
                OR (
                    substring(realtime.topic() FROM '^webrtc:order_([0-9a-fA-F-]{36})') IS NOT NULL
                    AND public.is_order_call_participant(
                        substring(realtime.topic() FROM '^webrtc:order_([0-9a-fA-F-]{36})')::uuid,
                        auth.uid()
                    )
                )
            )
        $pol$;
    END IF;
EXCEPTION
    WHEN insufficient_privilege THEN
        RAISE NOTICE 'Skipping realtime.messages policy creation due to schema privilege boundary';
END $$;

NOTIFY pgrst, 'reload schema';
