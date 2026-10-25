-- ==============================================================================
-- Migration: 20261023000600_store_vouchers_and_special_pricing.sql
-- Feature: Store Vouchers & Special Customer Pricing (Phase Additional)
-- Description:
--   1. Create store_vouchers table for store-specific promo, nominal, percentage, or fixed custom price
--   2. Add voucher tracking columns to orders table
--   3. RPC validate_and_apply_voucher to ensure server-side Zero Client Trust validation
--   4. RLS policies allowing sellers to manage vouchers and buyers to validate/read active vouchers
-- ==============================================================================

-- 1. Create store_vouchers table
CREATE TABLE IF NOT EXISTS public.store_vouchers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
    code VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    discount_type VARCHAR(20) NOT NULL CHECK (discount_type IN ('nominal', 'percentage', 'fixed_price')),
    discount_value NUMERIC(12, 2) NOT NULL CHECK (discount_value > 0),
    min_purchase NUMERIC(12, 2) DEFAULT 0,
    max_discount NUMERIC(12, 2) NULL,
    start_date TIMESTAMPTZ DEFAULT NOW(),
    end_date TIMESTAMPTZ NULL,
    usage_limit INT DEFAULT 1, -- 1 = single use / sekali pakai kenalan
    used_count INT DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_store_voucher_code UNIQUE (store_id, code)
);

CREATE INDEX IF NOT EXISTS idx_store_vouchers_store_id ON public.store_vouchers(store_id);
CREATE INDEX IF NOT EXISTS idx_store_vouchers_code ON public.store_vouchers(code);

-- 2. Add voucher reference columns to orders table
ALTER TABLE public.orders
ADD COLUMN IF NOT EXISTS voucher_id UUID REFERENCES public.store_vouchers(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS voucher_code VARCHAR(50) NULL,
ADD COLUMN IF NOT EXISTS voucher_discount NUMERIC(12, 2) DEFAULT 0;

-- 3. Server-side validation RPC for Zero Client Trust
CREATE OR REPLACE FUNCTION public.validate_and_apply_voucher(
    p_code TEXT,
    p_store_id UUID,
    p_subtotal NUMERIC,
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
    v_clean_code TEXT := UPPER(TRIM(p_code));
BEGIN
    IF v_clean_code IS NULL OR v_clean_code = '' THEN
        RETURN jsonb_build_object('valid', false, 'message', 'Kode voucher tidak boleh kosong');
    END IF;

    -- Lookup voucher matching store and code
    SELECT * INTO v_voucher
    FROM public.store_vouchers
    WHERE store_id = p_store_id 
      AND UPPER(code) = v_clean_code;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('valid', false, 'message', 'Kode voucher tidak ditemukan untuk toko ini');
    END IF;

    -- Check if active
    IF NOT v_voucher.is_active THEN
        RETURN jsonb_build_object('valid', false, 'message', 'Voucher ini sudah tidak aktif');
    END IF;

    -- Check start date
    IF v_voucher.start_date IS NOT NULL AND NOW() < v_voucher.start_date THEN
        RETURN jsonb_build_object('valid', false, 'message', 'Voucher ini belum dapat digunakan');
    END IF;

    -- Check expiry date
    IF v_voucher.end_date IS NOT NULL AND NOW() > v_voucher.end_date THEN
        RETURN jsonb_build_object('valid', false, 'message', 'Masa berlaku voucher telah berakhir');
    END IF;

    -- Check usage limit / quota
    IF v_voucher.usage_limit IS NOT NULL AND v_voucher.used_count >= v_voucher.usage_limit THEN
        RETURN jsonb_build_object('valid', false, 'message', 'Kuota pemakaian voucher telah habis');
    END IF;

    -- Check min purchase
    IF v_voucher.min_purchase IS NOT NULL AND p_subtotal < v_voucher.min_purchase THEN
        RETURN jsonb_build_object(
            'valid', false, 
            'message', 'Minimal belanja untuk voucher ini adalah Rp ' || TO_CHAR(v_voucher.min_purchase, 'FM999,999,999')
        );
    END IF;

    -- Calculate discount based on type
    IF v_voucher.discount_type = 'nominal' THEN
        v_discount := LEAST(p_subtotal, v_voucher.discount_value);
    ELSIF v_voucher.discount_type = 'percentage' THEN
        v_discount := (p_subtotal * v_voucher.discount_value) / 100.0;
        IF v_voucher.max_discount IS NOT NULL AND v_voucher.max_discount > 0 THEN
            v_discount := LEAST(v_discount, v_voucher.max_discount);
        END IF;
        v_discount := LEAST(p_subtotal, v_discount);
    ELSIF v_voucher.discount_type = 'fixed_price' THEN
        -- Harga khusus baru: Subtotal di-override menjadi discount_value
        IF p_subtotal > v_voucher.discount_value THEN
            v_discount := p_subtotal - v_voucher.discount_value;
        ELSE
            v_discount := 0;
        END IF;
    END IF;

    v_final_price := GREATEST(0, p_subtotal - v_discount);

    RETURN jsonb_build_object(
        'valid', true,
        'voucher_id', v_voucher.id,
        'code', v_voucher.code,
        'title', v_voucher.title,
        'discount_type', v_voucher.discount_type,
        'discount_value', v_voucher.discount_value,
        'calculated_discount', v_discount,
        'final_subtotal', v_final_price,
        'message', 'Voucher berhasil diterapkan!'
    );
END;
$$;

-- 4. Enable RLS
ALTER TABLE public.store_vouchers ENABLE ROW LEVEL SECURITY;

-- Policy: Store owners can manage their own vouchers
CREATE POLICY store_vouchers_owner_policy ON public.store_vouchers
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.stores
            WHERE stores.id = store_vouchers.store_id
              AND stores.owner_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.stores
            WHERE stores.id = store_vouchers.store_id
              AND stores.owner_id = auth.uid()
        )
    );

-- Policy: Authenticated users can view active vouchers to validate code
CREATE POLICY store_vouchers_read_policy ON public.store_vouchers
    FOR SELECT
    TO authenticated
    USING (is_active = true);

GRANT EXECUTE ON FUNCTION public.validate_and_apply_voucher(TEXT, UUID, NUMERIC, UUID) TO authenticated, anon;
