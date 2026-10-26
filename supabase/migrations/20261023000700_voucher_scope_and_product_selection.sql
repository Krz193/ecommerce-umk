-- ==============================================================================
-- Migration: 20261023000700_voucher_scope_and_product_selection.sql
-- Feature: Store Voucher Scope (Per Order vs Per Multiple Specific Products)
-- Description:
--   1. Add 'scope' and 'applicable_product_ids' to store_vouchers table
--   2. Update validate_and_apply_voucher RPC to evaluate specific items in cart
-- ==============================================================================

-- 1. Add scope and applicable_product_ids columns
ALTER TABLE public.store_vouchers
ADD COLUMN IF NOT EXISTS scope VARCHAR(20) DEFAULT 'order' CHECK (scope IN ('order', 'product')),
ADD COLUMN IF NOT EXISTS applicable_product_ids UUID[] NULL;

CREATE INDEX IF NOT EXISTS idx_store_vouchers_scope ON public.store_vouchers(scope);

-- 2. Enhanced RPC validate_and_apply_voucher supporting cart items breakdown
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
    v_clean_code TEXT := UPPER(TRIM(p_code));
    v_item JSONB;
    v_item_prod_id UUID;
    v_item_price NUMERIC;
    v_item_qty INT;
    v_matched_count INT := 0;
    v_eligible_subtotal NUMERIC := 0;
    v_item_discount NUMERIC := 0;
    v_matched_names TEXT[] := ARRAY[]::TEXT[];
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

    -- =========================================================================
    -- SCOPE EVALUATION
    -- =========================================================================
    IF v_voucher.scope = 'product' AND v_voucher.applicable_product_ids IS NOT NULL AND array_length(v_voucher.applicable_product_ids, 1) > 0 THEN
        -- Evaluate each item in cart
        IF p_items IS NOT NULL AND jsonb_array_length(p_items) > 0 THEN
            FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
            LOOP
                v_item_prod_id := (v_item->>'product_id')::UUID;
                v_item_price := COALESCE((v_item->>'price')::NUMERIC, 0);
                v_item_qty := COALESCE((v_item->>'quantity')::INT, 1);

                IF v_item_prod_id = ANY(v_voucher.applicable_product_ids) THEN
                    v_matched_count := v_matched_count + 1;
                    v_eligible_subtotal := v_eligible_subtotal + (v_item_price * v_item_qty);
                    v_matched_names := array_append(v_matched_names, COALESCE(v_item->>'product_name', 'Produk Khusus'));

                    -- Calculate per item discount
                    IF v_voucher.discount_type = 'nominal' THEN
                        -- Nominal potongan per item quantity (capped at item price)
                        v_item_discount := LEAST(v_item_price, v_voucher.discount_value) * v_item_qty;
                        v_discount := v_discount + v_item_discount;
                    ELSIF v_voucher.discount_type = 'percentage' THEN
                        v_item_discount := ((v_item_price * v_voucher.discount_value) / 100.0) * v_item_qty;
                        v_discount := v_discount + v_item_discount;
                    ELSIF v_voucher.discount_type = 'fixed_price' THEN
                        -- Harga khusus baru per item: item_price di-override menjadi discount_value
                        IF v_item_price > v_voucher.discount_value THEN
                            v_item_discount := (v_item_price - v_voucher.discount_value) * v_item_qty;
                            v_discount := v_discount + v_item_discount;
                        END IF;
                    END IF;
                END IF;
            END LOOP;

            -- If percentage has max_discount cap
            IF v_voucher.discount_type = 'percentage' AND v_voucher.max_discount IS NOT NULL AND v_voucher.max_discount > 0 THEN
                v_discount := LEAST(v_discount, v_voucher.max_discount);
            END IF;
        END IF;

        IF v_matched_count = 0 THEN
            RETURN jsonb_build_object(
                'valid', false,
                'message', 'Voucher ini hanya berlaku untuk produk khusus yang ditentukan oleh penjual.'
            );
        END IF;
    ELSE
        -- SCOPE: PER ORDER (Order subtotal)
        IF v_voucher.discount_type = 'nominal' THEN
            v_discount := LEAST(p_subtotal, v_voucher.discount_value);
        ELSIF v_voucher.discount_type = 'percentage' THEN
            v_discount := (p_subtotal * v_voucher.discount_value) / 100.0;
            IF v_voucher.max_discount IS NOT NULL AND v_voucher.max_discount > 0 THEN
                v_discount := LEAST(v_discount, v_voucher.max_discount);
            END IF;
            v_discount := LEAST(p_subtotal, v_discount);
        ELSIF v_voucher.discount_type = 'fixed_price' THEN
            -- Fixed Price Borongan 1 Order
            IF p_subtotal > v_voucher.discount_value THEN
                v_discount := p_subtotal - v_voucher.discount_value;
            ELSE
                v_discount := 0;
            END IF;
        END IF;
    END IF;

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
