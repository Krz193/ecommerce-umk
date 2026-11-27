-- ==============================================================================
-- Migration: 20261126000100_final_audit_security_and_financial_hardening.sql
-- Description (Final Re-Audit Security & Financial Integrity Hardening):
--   1. Revoke direct client INSERT/UPDATE/DELETE on orders, order_items, payments,
--      and direct INSERT on donations (+ insert trigger guard)
--   2. Add sensitive columns guard trigger on public.stores (balance/status/owner_id)
--   3. Lock down SECURITY DEFINER RPCs to service_role & harden Biteship RPCs
--   4. Harden cancel_logistics_shipment & update_logistics_shipment ownership/paid guards
--   5. Add atomic process_order_payment_webhook RPC for race-free stock/payment settlement
--   6. Sync contracts: drop legacy validate_and_apply_voucher overload, add voucher
--      rollback to order lifecycle trigger, block unpaid refunds in RLS, allow store
--      assistants on store_vouchers & refunds, allow donors to view linked store_contents,
--      and fix is_order_call_participant owner check for p_user_id
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. REVOKE DIRECT CLIENT WRITES ON TRANSACTIONAL TABLES
-- ------------------------------------------------------------------------------

REVOKE INSERT, UPDATE, DELETE ON public.orders FROM authenticated, anon;
REVOKE INSERT, UPDATE, DELETE ON public.order_items FROM authenticated, anon;
REVOKE INSERT, UPDATE, DELETE ON public.payments FROM authenticated, anon;

GRANT SELECT ON public.orders TO authenticated;
GRANT SELECT ON public.order_items TO authenticated;
GRANT SELECT ON public.payments TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.orders TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.order_items TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.payments TO service_role;

DROP POLICY IF EXISTS "Users can create own orders" ON public.orders;
DROP POLICY IF EXISTS "Store owners can update store orders" ON public.orders;
DROP POLICY IF EXISTS "Store assistants can update store orders" ON public.orders;
DROP POLICY IF EXISTS "Users can complete own shipped orders" ON public.orders;
DROP POLICY IF EXISTS "Users can create own order items" ON public.order_items;
DROP POLICY IF EXISTS "Users can create own payments" ON public.payments;
DROP POLICY IF EXISTS "Users can update own payments" ON public.payments;

-- Donations: creation must go through donation-checkout Edge Function (service_role)
REVOKE INSERT ON public.donations FROM authenticated, anon;
DROP POLICY IF EXISTS "Authenticated users can create donations" ON public.donations;

CREATE OR REPLACE FUNCTION public.enforce_buyer_donation_insert_guard()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF auth.uid() IS NULL OR public.is_admin() THEN
        RETURN NEW;
    END IF;

    RAISE EXCEPTION 'Pembuatan donasi wajib melalui layanan pembayaran resmi';
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_buyer_donation_insert_guard ON public.donations;
CREATE TRIGGER trg_enforce_buyer_donation_insert_guard
BEFORE INSERT ON public.donations
FOR EACH ROW
EXECUTE FUNCTION public.enforce_buyer_donation_insert_guard();

-- ------------------------------------------------------------------------------
-- 2. PROTECT SENSITIVE COLUMNS ON PUBLIC.STORES
-- ------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.enforce_store_sensitive_columns_guard()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Backend service_role / SQL jobs (auth.uid() IS NULL) and Admins bypass
    IF auth.uid() IS NULL OR public.is_admin() THEN
        RETURN NEW;
    END IF;

    IF TG_OP = 'INSERT' THEN
        NEW.status := 'pending';
        NEW.balance := 0;
        NEW.suspended_at := NULL;
        RETURN NEW;
    END IF;

    IF NEW.balance IS DISTINCT FROM OLD.balance
       OR NEW.status IS DISTINCT FROM OLD.status
       OR NEW.suspended_at IS DISTINCT FROM OLD.suspended_at
       OR NEW.owner_id IS DISTINCT FROM OLD.owner_id
    THEN
        RAISE EXCEPTION 'Kolom status, saldo, dan kepemilikan toko hanya dapat diubah oleh sistem atau Admin';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_store_sensitive_columns_guard ON public.stores;
CREATE TRIGGER trg_enforce_store_sensitive_columns_guard
BEFORE INSERT OR UPDATE ON public.stores
FOR EACH ROW
EXECUTE FUNCTION public.enforce_store_sensitive_columns_guard();

-- ------------------------------------------------------------------------------
-- 3. LOCK DOWN SECURITY DEFINER RPCS TO SERVICE_ROLE & ADD IDEMPOTENCY
-- ------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.execute_order_biteship_transaction(
    p_order_id UUID,
    p_store_id UUID,
    p_biteship_order_id TEXT,
    p_waybill_id TEXT,
    p_shipping_cost NUMERIC,
    p_idempotency_key TEXT,
    p_driver_name TEXT DEFAULT NULL,
    p_driver_phone TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_order RECORD;
    v_result JSONB;
BEGIN
    SELECT * INTO v_order
    FROM public.orders
    WHERE id = p_order_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order with ID % not found', p_order_id;
    END IF;

    IF v_order.store_id <> p_store_id THEN
        RAISE EXCEPTION 'Order does not belong to store %', p_store_id;
    END IF;

    IF v_order.payment_status <> 'paid' THEN
        RAISE EXCEPTION 'Order % is not paid', p_order_id;
    END IF;

    -- Idempotency guard: avoid double balance deduction on retries
    IF v_order.biteship_order_id IS NOT NULL THEN
        RETURN jsonb_build_object(
            'success', true,
            'idempotent_skip', true,
            'order_id', p_order_id,
            'biteship_order_id', v_order.biteship_order_id,
            'waybill_id', v_order.waybill_id,
            'idempotency_key', v_order.idempotency_key
        );
    END IF;

    IF p_shipping_cost IS NULL OR p_shipping_cost < 0 THEN
        RAISE EXCEPTION 'Invalid shipping cost';
    END IF;

    UPDATE public.stores
    SET balance = balance - p_shipping_cost,
        updated_at = NOW()
    WHERE id = p_store_id;

    UPDATE public.orders
    SET biteship_order_id = p_biteship_order_id,
        waybill_id = p_waybill_id,
        tracking_number = p_waybill_id,
        idempotency_key = p_idempotency_key,
        status = 'shipped',
        tracking_status = 'on_delivery',
        driver_name = COALESCE(p_driver_name, driver_name),
        driver_phone = COALESCE(p_driver_phone, driver_phone),
        shipped_at = COALESCE(shipped_at, NOW()),
        updated_at = NOW()
    WHERE id = p_order_id;

    v_result := jsonb_build_object(
        'success', true,
        'idempotent_skip', false,
        'order_id', p_order_id,
        'biteship_order_id', p_biteship_order_id,
        'waybill_id', p_waybill_id,
        'idempotency_key', p_idempotency_key
    );

    RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION public.apply_shipping_discrepancy(
    p_order_id UUID,
    p_actual_shipping_cost NUMERIC,
    p_discrepancy_amount NUMERIC,
    p_original_weight NUMERIC DEFAULT NULL,
    p_actual_weight NUMERIC DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_order RECORD;
BEGIN
    SELECT * INTO v_order
    FROM public.orders
    WHERE id = p_order_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order % not found', p_order_id;
    END IF;

    -- Idempotency guard: ignore duplicate discrepancy webhooks for the same order & adjustment
    IF EXISTS (
        SELECT 1
        FROM public.biteship_discrepancies
        WHERE order_id = p_order_id
          AND actual_shipping_cost = p_actual_shipping_cost
          AND discrepancy_amount = p_discrepancy_amount
    ) THEN
        RETURN jsonb_build_object(
            'success', true,
            'idempotent_skip', true,
            'order_id', p_order_id,
            'store_id', v_order.store_id,
            'original_shipping_cost', v_order.shipping_cost,
            'actual_shipping_cost', p_actual_shipping_cost,
            'discrepancy_amount', p_discrepancy_amount
        );
    END IF;

    UPDATE public.orders
    SET actual_shipping_cost = p_actual_shipping_cost,
        shipping_discrepancy = p_discrepancy_amount,
        updated_at = NOW()
    WHERE id = p_order_id;

    UPDATE public.stores
    SET balance = balance - p_discrepancy_amount,
        updated_at = NOW()
    WHERE id = v_order.store_id;

    INSERT INTO public.biteship_discrepancies (
        order_id,
        original_shipping_cost,
        actual_shipping_cost,
        discrepancy_amount,
        original_weight,
        actual_weight,
        seller_balance_adjusted,
        notes
    ) VALUES (
        p_order_id,
        v_order.shipping_cost,
        p_actual_shipping_cost,
        p_discrepancy_amount,
        p_original_weight,
        p_actual_weight,
        TRUE,
        p_notes
    );

    RETURN jsonb_build_object(
        'success', true,
        'idempotent_skip', false,
        'order_id', p_order_id,
        'store_id', v_order.store_id,
        'original_shipping_cost', v_order.shipping_cost,
        'actual_shipping_cost', p_actual_shipping_cost,
        'discrepancy_amount', p_discrepancy_amount
    );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.execute_order_biteship_transaction(UUID, UUID, TEXT, TEXT, NUMERIC, TEXT, TEXT, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.execute_order_biteship_transaction(UUID, UUID, TEXT, TEXT, NUMERIC, TEXT, TEXT, TEXT) TO service_role;

REVOKE EXECUTE ON FUNCTION public.apply_shipping_discrepancy(UUID, NUMERIC, NUMERIC, NUMERIC, NUMERIC, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.apply_shipping_discrepancy(UUID, NUMERIC, NUMERIC, NUMERIC, NUMERIC, TEXT) TO service_role;

REVOKE EXECUTE ON FUNCTION public.reserve_flash_sale_quota(UUID, INT, UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reserve_flash_sale_quota(UUID, INT, UUID) TO service_role;

REVOKE EXECUTE ON FUNCTION public.rollback_order_flash_sale_quota(UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rollback_order_flash_sale_quota(UUID) TO service_role;

REVOKE EXECUTE ON FUNCTION public.create_notification(UUID, VARCHAR, VARCHAR, VARCHAR, TEXT, VARCHAR, JSONB) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.create_notification(UUID, VARCHAR, VARCHAR, VARCHAR, TEXT, VARCHAR, JSONB) TO service_role;

REVOKE EXECUTE ON FUNCTION public.notify_store_stakeholders(UUID, VARCHAR, VARCHAR, VARCHAR, TEXT, VARCHAR, JSONB) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.notify_store_stakeholders(UUID, VARCHAR, VARCHAR, VARCHAR, TEXT, VARCHAR, JSONB) TO service_role;

-- ------------------------------------------------------------------------------
-- 4. HARDEN LOGISTICS SHIPMENT UPDATE & CANCEL RPCS
-- ------------------------------------------------------------------------------

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

    IF v_order.payment_status <> 'paid' THEN
        RAISE EXCEPTION 'Pesanan belum lunas dan tidak dapat diperbarui pengirimannya';
    END IF;

    IF v_order.status IN ('cancelled', 'completed') THEN
        RAISE EXCEPTION 'Pesanan sudah selesai atau dibatalkan';
    END IF;

    IF COALESCE(v_user_role, '') <> 'admin' THEN
        IF v_order.biteship_order_id IS NOT NULL
           OR LOWER(COALESCE(v_order.courier_code, '')) IN ('gojek', 'grab', 'jne', 'sicepat', 'jnt', 'anteraja', 'paxel', 'ninja', 'lion', 'pos', 'tiki')
        THEN
            RAISE EXCEPTION 'Pesanan ini dikelola otomatis oleh Biteship';
        END IF;

        IF v_order.driver_id IS NULL OR v_order.driver_id <> v_user_id THEN
            RAISE EXCEPTION 'Anda harus mengklaim pesanan ini terlebih dahulu atau bukan kurir yang ditugaskan';
        END IF;
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

REVOKE EXECUTE ON FUNCTION public.update_logistics_shipment(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_logistics_shipment(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, TEXT) TO authenticated, service_role;

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
    IF COALESCE(v_user_role, '') NOT IN ('ekspedisi', 'ojek', 'admin') THEN
        RAISE EXCEPTION 'Forbidden: Hanya mitra logistik atau admin yang dapat membatalkan pengiriman';
    END IF;

    SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pesanan tidak ditemukan';
    END IF;

    IF COALESCE(v_user_role, '') <> 'admin' THEN
        IF v_order.biteship_order_id IS NOT NULL THEN
            RAISE EXCEPTION 'Pesanan Biteship tidak dapat dibatalkan oleh kurir lokal';
        END IF;

        IF v_order.driver_id IS NULL OR v_order.driver_id <> v_user_id THEN
            RAISE EXCEPTION 'Anda tidak memiliki wewenang untuk membatalkan pesanan ini';
        END IF;
    END IF;

    IF v_order.tracking_status = 'delivered' OR v_order.status IN ('completed', 'cancelled') THEN
        RAISE EXCEPTION 'Pesanan yang telah sampai atau ditutup tidak dapat dibatalkan';
    END IF;

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
            tracking_status = 'ready_to_ship',
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

REVOKE EXECUTE ON FUNCTION public.cancel_logistics_shipment(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_logistics_shipment(UUID, TEXT) TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 5. ATOMIC PAYMENT WEBHOOK SETTLEMENT RPC (SERVICE_ROLE ONLY)
-- ------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.process_order_payment_webhook(
    p_order_number TEXT,
    p_transaction_status TEXT,
    p_fraud_status TEXT DEFAULT NULL,
    p_gross_amount NUMERIC DEFAULT NULL,
    p_raw_response JSONB DEFAULT '{}'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_order public.orders;
    v_payment public.payments;
    v_item RECORD;
    v_item_count INT := 0;
    v_updated_product_id UUID;
    v_is_paid_event BOOLEAN;
    v_is_expire BOOLEAN;
    v_is_fail BOOLEAN;
    v_next_status TEXT;
BEGIN
    SELECT * INTO v_order
    FROM public.orders
    WHERE order_number = p_order_number
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('ok', false, 'code', 'not_found', 'error', 'Order not found');
    END IF;

    SELECT * INTO v_payment
    FROM public.payments
    WHERE order_id = v_order.id
    ORDER BY created_at DESC
    LIMIT 1
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('ok', false, 'code', 'not_found', 'error', 'Payment not found');
    END IF;

    IF p_gross_amount IS NULL OR ROUND(p_gross_amount) <> ROUND(v_payment.amount) THEN
        RETURN jsonb_build_object(
            'ok', false,
            'code', 'amount_mismatch',
            'error', 'Gross amount mismatch'
        );
    END IF;

    -- Idempotent / forward-only guard: never downgrade or re-settle an already paid/finalized order
    IF v_payment.status = 'paid'
       OR v_order.payment_status = 'paid'
       OR v_order.status IN ('shipped', 'completed')
    THEN
        RETURN jsonb_build_object(
            'ok', true,
            'ignored', true,
            'message', 'Payment already settled or finalized',
            'payment', to_jsonb(v_payment),
            'order', to_jsonb(v_order)
        );
    END IF;

    v_is_paid_event := (p_transaction_status = 'settlement')
        OR (p_transaction_status = 'capture' AND COALESCE(p_fraud_status, '') <> 'deny');
    v_is_expire := (p_transaction_status = 'expire');
    v_is_fail := (p_transaction_status IN ('cancel', 'deny'));

    IF v_is_paid_event THEN
        IF v_order.status = 'cancelled' OR v_payment.status IN ('expired', 'failed') THEN
            RETURN jsonb_build_object(
                'ok', false,
                'code', 'order_already_closed',
                'error', 'Cannot settle an already cancelled or expired order'
            );
        END IF;

        -- Deduct stock atomically in deterministic product_id order to prevent deadlocks
        FOR v_item IN
            SELECT id, product_id, quantity
            FROM public.order_items
            WHERE order_id = v_order.id
            ORDER BY product_id ASC
        LOOP
            v_item_count := v_item_count + 1;

            UPDATE public.products
            SET stock = stock - v_item.quantity,
                updated_at = NOW()
            WHERE id = v_item.product_id
              AND stock >= v_item.quantity
            RETURNING id INTO v_updated_product_id;

            IF v_updated_product_id IS NULL THEN
                RAISE EXCEPTION 'Insufficient stock for product %', v_item.product_id;
            END IF;
        END LOOP;

        IF v_item_count = 0 THEN
            RETURN jsonb_build_object(
                'ok', false,
                'code', 'order_items_not_found',
                'error', 'Order items not found'
            );
        END IF;

        DELETE FROM public.cart_items
        WHERE cart_id IN (
            SELECT id
            FROM public.carts
            WHERE user_id = v_order.user_id
              AND store_id = v_order.store_id
        );

        UPDATE public.payments
        SET status = 'paid',
            paid_at = COALESCE(paid_at, NOW()),
            raw_response = COALESCE(p_raw_response, raw_response)
        WHERE id = v_payment.id
        RETURNING * INTO v_payment;

        UPDATE public.orders
        SET status = 'processing',
            payment_status = 'paid',
            paid_at = COALESCE(paid_at, NOW()),
            updated_at = NOW()
        WHERE id = v_order.id
        RETURNING * INTO v_order;

    ELSIF v_is_expire OR v_is_fail THEN
        v_next_status := CASE WHEN v_is_expire THEN 'expired' ELSE 'failed' END;

        PERFORM public.rollback_order_flash_sale_quota(v_order.id);
        PERFORM public.rollback_voucher_quota(v_order.id);

        UPDATE public.payments
        SET status = v_next_status,
            raw_response = COALESCE(p_raw_response, raw_response)
        WHERE id = v_payment.id
        RETURNING * INTO v_payment;

        UPDATE public.orders
        SET status = 'cancelled',
            payment_status = v_next_status,
            updated_at = NOW()
        WHERE id = v_order.id
        RETURNING * INTO v_order;
    ELSE
        UPDATE public.payments
        SET raw_response = COALESCE(p_raw_response, raw_response)
        WHERE id = v_payment.id
        RETURNING * INTO v_payment;
    END IF;

    RETURN jsonb_build_object(
        'ok', true,
        'ignored', false,
        'payment', to_jsonb(v_payment),
        'order', to_jsonb(v_order)
    );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.process_order_payment_webhook(TEXT, TEXT, TEXT, NUMERIC, JSONB) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.process_order_payment_webhook(TEXT, TEXT, TEXT, NUMERIC, JSONB) TO service_role;

-- ------------------------------------------------------------------------------
-- 6. SYNC CONTRACTS: VOUCHERS, TRIGGER ROLLBACK, REFUNDS, ASSISTANTS, DONORS, WEBRTC
-- ------------------------------------------------------------------------------

-- Drop legacy 4-arg validate_and_apply_voucher overload & restrict 5-arg to authenticated/service_role
DROP FUNCTION IF EXISTS public.validate_and_apply_voucher(TEXT, UUID, NUMERIC, UUID);
REVOKE EXECUTE ON FUNCTION public.validate_and_apply_voucher(TEXT, UUID, NUMERIC, JSONB, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.validate_and_apply_voucher(TEXT, UUID, NUMERIC, JSONB, UUID) TO authenticated, service_role;

-- Include voucher quota rollback in order lifecycle trigger
CREATE OR REPLACE FUNCTION public.fn_notify_order_lifecycle()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_order_route TEXT;
    v_seller_route TEXT;
    v_meta JSONB;
    v_tracking_msg TEXT;
BEGIN
    v_order_route := '/orders/' || NEW.id;
    v_seller_route := '/seller/orders/' || NEW.id;
    v_meta := jsonb_build_object('order_id', NEW.id, 'order_number', NEW.order_number);

    IF TG_OP = 'INSERT' THEN
        PERFORM public.create_notification(
            NEW.user_id,
            'transaction',
            'order_created',
            'Pesanan Menunggu Pembayaran',
            'Pesanan ' || NEW.order_number || ' berhasil dibuat. Segera selesaikan pembayaran sebelum kedaluwarsa.',
            v_order_route,
            v_meta
        );

        PERFORM public.notify_store_stakeholders(
            NEW.store_id,
            'transaction',
            'seller_new_order',
            'Pesanan Baru Masuk',
            'Pesanan baru ' || NEW.order_number || ' telah dibuat dan sedang menunggu pembayaran pembeli.',
            v_seller_route,
            v_meta
        );
        RETURN NEW;
    END IF;

    IF NEW.payment_status IS DISTINCT FROM OLD.payment_status THEN
        IF NEW.payment_status = 'paid' THEN
            PERFORM public.create_notification(
                NEW.user_id,
                'transaction',
                'payment_paid',
                'Pembayaran Berhasil',
                'Pembayaran pesanan ' || NEW.order_number || ' telah diterima. Penjual akan segera memproses pesanan Anda.',
                v_order_route,
                v_meta
            );

            PERFORM public.notify_store_stakeholders(
                NEW.store_id,
                'transaction',
                'seller_order_paid',
                'Pesanan Telah Dibayar',
                'Pesanan ' || NEW.order_number || ' sudah dibayar! Segera siapkan dan kirim barang.',
                v_seller_route,
                v_meta
            );
        ELSIF NEW.payment_status IN ('expired', 'failed') THEN
            PERFORM public.rollback_order_flash_sale_quota(NEW.id);
            PERFORM public.rollback_voucher_quota(NEW.id);
            PERFORM public.create_notification(
                NEW.user_id,
                'transaction',
                'payment_' || NEW.payment_status,
                CASE WHEN NEW.payment_status = 'expired' THEN 'Pembayaran Kedaluwarsa' ELSE 'Pembayaran Gagal' END,
                'Pembayaran untuk pesanan ' || NEW.order_number || ' ' ||
                    CASE WHEN NEW.payment_status = 'expired' THEN 'telah melewati batas waktu.' ELSE 'gagal diproses.' END,
                v_order_route,
                v_meta
            );
        END IF;
    END IF;

    IF NEW.status IS DISTINCT FROM OLD.status THEN
        IF NEW.status = 'shipped' THEN
            PERFORM public.create_notification(
                NEW.user_id,
                'transaction',
                'order_shipped',
                'Pesanan Sedang Dikirim',
                'Pesanan ' || NEW.order_number || ' telah dikirim oleh penjual' ||
                    COALESCE(' (Resi: ' || NULLIF(NEW.tracking_number, '') || ')', '') || '.',
                v_order_route,
                v_meta
            );
        ELSIF NEW.status = 'completed' THEN
            PERFORM public.create_notification(
                NEW.user_id,
                'transaction',
                'order_completed',
                'Pesanan Selesai — Beri Ulasan',
                'Terima kasih! Pesanan ' || NEW.order_number || ' telah selesai. Yuk berikan rating & ulasan produk.',
                v_order_route,
                v_meta
            );

            PERFORM public.notify_store_stakeholders(
                NEW.store_id,
                'transaction',
                'seller_order_completed',
                'Pesanan Diselesaikan Pembeli',
                'Pesanan ' || NEW.order_number || ' telah dikonfirmasi diterima oleh pembeli.',
                v_seller_route,
                v_meta
            );
        ELSIF NEW.status = 'cancelled' THEN
            PERFORM public.rollback_order_flash_sale_quota(NEW.id);
            PERFORM public.rollback_voucher_quota(NEW.id);
        END IF;
    END IF;

    IF NEW.tracking_status IS DISTINCT FROM OLD.tracking_status
       AND NEW.tracking_status IN ('allocated', 'picking_up', 'dropping_off', 'delivered') THEN
        v_tracking_msg := CASE NEW.tracking_status
            WHEN 'allocated' THEN 'Kurir telah ditugaskan untuk menjemput pesanan ' || NEW.order_number || '.'
            WHEN 'picking_up' THEN 'Kurir sedang dalam perjalanan menjemput pesanan ' || NEW.order_number || ' dari toko.'
            WHEN 'dropping_off' THEN 'Kurir sedang mengantarkan pesanan ' || NEW.order_number || ' ke alamat tujuan Anda.'
            WHEN 'delivered' THEN 'Kurir menandai pesanan ' || NEW.order_number || ' telah tiba di tujuan.'
        END;

        PERFORM public.create_notification(
            NEW.user_id,
            'transaction',
            'tracking_' || NEW.tracking_status,
            'Update Pengiriman Kurir',
            v_tracking_msg,
            v_order_route,
            v_meta || jsonb_build_object('tracking_status', NEW.tracking_status)
        );
    END IF;

    RETURN NEW;
END;
$$;

-- Refunds RLS: block unpaid orders (payment_status = 'paid' required) + support store assistants
DROP POLICY IF EXISTS "Buyers can create own refund requests" ON public.refunds;
CREATE POLICY "Buyers can create own refund requests"
ON public.refunds
FOR INSERT
TO authenticated
WITH CHECK (
    requested_by = auth.uid()
    AND requester_role = 'buyer'
    AND EXISTS (
        SELECT 1
        FROM public.orders
        WHERE orders.id = refunds.order_id
          AND orders.user_id = auth.uid()
          AND orders.status NOT IN ('pending', 'cancelled')
          AND orders.payment_status = 'paid'
    )
);

DROP POLICY IF EXISTS "Store owners can view store refund requests" ON public.refunds;
CREATE POLICY "Store owners can view store refund requests"
ON public.refunds
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.orders
        WHERE orders.id = refunds.order_id
          AND (
              public.is_store_owner(orders.store_id)
              OR public.is_store_assistant_user(orders.store_id, auth.uid())
          )
    )
);

DROP POLICY IF EXISTS "Store owners can create store refund requests" ON public.refunds;
CREATE POLICY "Store owners can create store refund requests"
ON public.refunds
FOR INSERT
TO authenticated
WITH CHECK (
    requested_by = auth.uid()
    AND requester_role = 'seller'
    AND EXISTS (
        SELECT 1
        FROM public.orders
        WHERE orders.id = refunds.order_id
          AND (
              public.is_store_owner(orders.store_id)
              OR public.is_store_assistant_user(orders.store_id, auth.uid())
          )
          AND orders.status NOT IN ('pending', 'cancelled', 'completed')
          AND orders.payment_status = 'paid'
    )
);

-- Store Vouchers RLS: allow store owners AND assigned store assistants
DROP POLICY IF EXISTS store_vouchers_owner_policy ON public.store_vouchers;
CREATE POLICY store_vouchers_owner_policy
ON public.store_vouchers
FOR ALL
TO authenticated
USING (
    public.is_store_owner(store_id)
    OR public.is_store_assistant_user(store_id, auth.uid())
)
WITH CHECK (
    public.is_store_owner(store_id)
    OR public.is_store_assistant_user(store_id, auth.uid())
);

-- Store Contents RLS: allow donors to read title/type of content linked to their own donations
DROP POLICY IF EXISTS "Donors can view linked store content" ON public.store_contents;
CREATE POLICY "Donors can view linked store content"
ON public.store_contents
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.donations d
        WHERE d.content_id = store_contents.id
          AND d.user_id = auth.uid()
    )
);

-- WebRTC participant helper: check owner via p_user_id instead of auth.uid()
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
              OR EXISTS (
                  SELECT 1 FROM public.stores s
                  WHERE s.id = o.store_id AND s.owner_id = p_user_id
              )
              OR public.is_store_assistant_user(o.store_id, p_user_id)
              OR COALESCE(u.role, '') = 'admin'
          )
    );
$$;

NOTIFY pgrst, 'reload schema';
