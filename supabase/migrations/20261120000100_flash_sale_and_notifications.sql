-- ==============================================================================
-- Migration: 20261120000100_flash_sale_and_notifications.sql
-- Features:
--   1. Flash Sale / Sale Events & Sale Event Items (CRUD, Zero Client Trust pricing,
--      atomic quota reservation & rollback, multi-event best price resolution)
--   2. In-App Notification Center (notifications table, Realtime enabled,
--      strict RLS, and automated Postgres lifecycle triggers)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. SALE EVENTS & SALE EVENT ITEMS
-- ------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.sale_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NULL REFERENCES public.stores(id) ON DELETE CASCADE,
    created_by UUID NULL REFERENCES public.users(id) ON DELETE SET NULL,
    title VARCHAR(255) NOT NULL,
    slug VARCHAR(255) NOT NULL,
    description TEXT NULL,
    banner_url TEXT NULL,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT sale_events_time_check CHECK (end_time > start_time)
);

CREATE INDEX IF NOT EXISTS idx_sale_events_active_window
    ON public.sale_events(is_active, start_time, end_time);
CREATE INDEX IF NOT EXISTS idx_sale_events_store_id
    ON public.sale_events(store_id);

DROP TRIGGER IF EXISTS update_sale_events_updated_at ON public.sale_events;
CREATE TRIGGER update_sale_events_updated_at
    BEFORE UPDATE ON public.sale_events
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

CREATE TABLE IF NOT EXISTS public.sale_event_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sale_event_id UUID NOT NULL REFERENCES public.sale_events(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
    discount_type VARCHAR(20) NOT NULL CHECK (discount_type IN ('percentage', 'nominal', 'fixed_price')),
    discount_value NUMERIC(12, 2) NOT NULL CHECK (discount_value > 0),
    sale_price NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (sale_price >= 0),
    sale_quota INT NULL CHECK (sale_quota IS NULL OR sale_quota > 0),
    sold_count INT NOT NULL DEFAULT 0 CHECK (sold_count >= 0),
    max_qty_per_user INT NULL CHECK (max_qty_per_user IS NULL OR max_qty_per_user > 0),
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_sale_event_product UNIQUE (sale_event_id, product_id)
);

CREATE INDEX IF NOT EXISTS idx_sale_event_items_event_id
    ON public.sale_event_items(sale_event_id);
CREATE INDEX IF NOT EXISTS idx_sale_event_items_product_id
    ON public.sale_event_items(product_id);
CREATE INDEX IF NOT EXISTS idx_sale_event_items_store_id
    ON public.sale_event_items(store_id);

DROP TRIGGER IF EXISTS update_sale_event_items_updated_at ON public.sale_event_items;
CREATE TRIGGER update_sale_event_items_updated_at
    BEFORE UPDATE ON public.sale_event_items
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- ------------------------------------------------------------------------------
-- 2. ZERO CLIENT TRUST PRICING HELPERS & TRIGGERS
-- ------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.calculate_sale_price(
    p_base_price NUMERIC,
    p_discount_type VARCHAR,
    p_discount_value NUMERIC
)
RETURNS NUMERIC
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    IF p_discount_type = 'percentage' THEN
        RETURN GREATEST(0, ROUND(p_base_price * (1 - LEAST(100, GREATEST(0, p_discount_value)) / 100.0)));
    ELSIF p_discount_type = 'nominal' THEN
        RETURN GREATEST(0, ROUND(p_base_price - GREATEST(0, p_discount_value)));
    ELSIF p_discount_type = 'fixed_price' THEN
        RETURN GREATEST(0, LEAST(p_base_price, ROUND(p_discount_value)));
    END IF;

    RETURN GREATEST(0, ROUND(p_base_price));
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_compute_sale_event_item_price()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_product_price NUMERIC;
    v_product_store_id UUID;
    v_event_store_id UUID;
BEGIN
    SELECT price, store_id
    INTO v_product_price, v_product_store_id
    FROM public.products
    WHERE id = NEW.product_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product % not found for sale event item', NEW.product_id;
    END IF;

    SELECT store_id
    INTO v_event_store_id
    FROM public.sale_events
    WHERE id = NEW.sale_event_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Sale event % not found', NEW.sale_event_id;
    END IF;

    IF v_event_store_id IS NOT NULL AND v_event_store_id <> v_product_store_id THEN
        RAISE EXCEPTION 'Product does not belong to this store sale event';
    END IF;

    -- Authoritative store_id and server-side calculated sale_price
    NEW.store_id := v_product_store_id;
    NEW.sale_price := public.calculate_sale_price(
        v_product_price,
        NEW.discount_type,
        NEW.discount_value
    );

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_compute_sale_event_item_price ON public.sale_event_items;
CREATE TRIGGER trg_compute_sale_event_item_price
    BEFORE INSERT OR UPDATE OF product_id, sale_event_id, discount_type, discount_value
    ON public.sale_event_items
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_compute_sale_event_item_price();

-- Keep sale_price synchronized when a product's base selling price changes
CREATE OR REPLACE FUNCTION public.fn_sync_sale_item_price_on_product_update()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NEW.price IS DISTINCT FROM OLD.price THEN
        UPDATE public.sale_event_items
        SET sale_price = public.calculate_sale_price(NEW.price, discount_type, discount_value),
            updated_at = NOW()
        WHERE product_id = NEW.id;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_sale_item_price_on_product_update ON public.products;
CREATE TRIGGER trg_sync_sale_item_price_on_product_update
    AFTER UPDATE OF price ON public.products
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_sync_sale_item_price_on_product_update();

-- ------------------------------------------------------------------------------
-- 3. EXTEND ORDER ITEMS & FLASH SALE QUOTA RPCS
-- ------------------------------------------------------------------------------

ALTER TABLE public.order_items
    ADD COLUMN IF NOT EXISTS sale_event_id UUID NULL REFERENCES public.sale_events(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS sale_event_item_id UUID NULL REFERENCES public.sale_event_items(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS is_flash_sale BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS quota_rolled_back BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_order_items_sale_event_item_id
    ON public.order_items(sale_event_item_id)
    WHERE sale_event_item_id IS NOT NULL;

-- Returns best active flash sale per product (cheapest sale_price wins when >1 event)
CREATE OR REPLACE FUNCTION public.get_active_product_flash_sales(
    p_product_ids UUID[],
    p_user_id UUID DEFAULT auth.uid()
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_effective_user_id UUID;
    v_result JSONB;
BEGIN
    IF p_product_ids IS NULL OR array_length(p_product_ids, 1) IS NULL THEN
        RETURN '[]'::jsonb;
    END IF;

    -- Prevent IDOR: authenticated non-service-role callers can only query their own purchase quota
    IF auth.uid() IS NOT NULL AND current_setting('role', true) <> 'service_role' THEN
        v_effective_user_id := auth.uid();
    ELSE
        v_effective_user_id := p_user_id;
    END IF;

    WITH ranked_items AS (
        SELECT DISTINCT ON (sei.product_id)
            sei.product_id,
            sei.sale_event_id,
            sei.id AS sale_event_item_id,
            se.title AS event_title,
            se.start_time,
            se.end_time,
            sei.discount_type,
            sei.discount_value,
            sei.sale_price,
            p.price AS regular_price,
            sei.sale_quota,
            sei.sold_count,
            sei.max_qty_per_user,
            CASE
                WHEN sei.sale_quota IS NULL THEN NULL
                ELSE GREATEST(0, sei.sale_quota - sei.sold_count)
            END AS remaining_sale_quota,
            COALESCE((
                SELECT SUM(oi.quantity)::INT
                FROM public.order_items oi
                JOIN public.orders o ON o.id = oi.order_id
                WHERE v_effective_user_id IS NOT NULL
                  AND o.user_id = v_effective_user_id
                  AND oi.sale_event_item_id = sei.id
                  AND oi.is_flash_sale = true
                  AND o.status NOT IN ('cancelled', 'failed')
                  AND o.payment_status NOT IN ('expired', 'failed')
            ), 0) AS user_purchased_qty
        FROM public.sale_event_items sei
        JOIN public.sale_events se ON se.id = sei.sale_event_id
        JOIN public.products p ON p.id = sei.product_id
        WHERE sei.product_id = ANY(p_product_ids)
          AND se.is_active = true
          AND sei.is_active = true
          AND NOW() >= se.start_time
          AND NOW() <= se.end_time
          AND sei.sale_price < p.price
          AND (sei.sale_quota IS NULL OR sei.sold_count < sei.sale_quota)
        ORDER BY sei.product_id, sei.sale_price ASC, se.end_time ASC
    )
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'product_id', r.product_id,
            'sale_event_id', r.sale_event_id,
            'sale_event_item_id', r.sale_event_item_id,
            'event_title', r.event_title,
            'start_time', r.start_time,
            'end_time', r.end_time,
            'discount_type', r.discount_type,
            'discount_value', r.discount_value,
            'sale_price', r.sale_price,
            'regular_price', r.regular_price,
            'sale_quota', r.sale_quota,
            'sold_count', r.sold_count,
            'max_qty_per_user', r.max_qty_per_user,
            'remaining_sale_quota', r.remaining_sale_quota,
            'user_purchased_qty', r.user_purchased_qty,
            'eligible_qty', CASE
                WHEN r.remaining_sale_quota IS NULL AND r.max_qty_per_user IS NULL THEN NULL
                ELSE GREATEST(0, LEAST(
                    COALESCE(r.remaining_sale_quota, 2147483647),
                    CASE
                        WHEN r.max_qty_per_user IS NULL THEN 2147483647
                        ELSE GREATEST(0, r.max_qty_per_user - r.user_purchased_qty)
                    END
                ))
            END
        )
    ), '[]'::jsonb)
    INTO v_result
    FROM ranked_items r;

    RETURN v_result;
END;
$$;

-- Atomically reserve flash sale quota during checkout
CREATE OR REPLACE FUNCTION public.reserve_flash_sale_quota(
    p_sale_event_item_id UUID,
    p_qty INT,
    p_order_id UUID DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_item RECORD;
BEGIN
    IF p_qty IS NULL OR p_qty <= 0 THEN
        RETURN false;
    END IF;

    -- Guard against arbitrary quota exhaustion calls outside an active pending order
    IF current_setting('role', true) <> 'service_role' THEN
        IF p_order_id IS NULL OR NOT EXISTS (
            SELECT 1 FROM public.orders
            WHERE id = p_order_id
              AND user_id = auth.uid()
              AND status = 'pending'
        ) THEN
            RAISE EXCEPTION 'Unauthorized quota reservation attempt';
        END IF;
    END IF;

    SELECT sei.id, sei.sale_quota, sei.sold_count, sei.is_active, se.is_active AS event_active, se.start_time, se.end_time
    INTO v_item
    FROM public.sale_event_items sei
    JOIN public.sale_events se ON se.id = sei.sale_event_id
    WHERE sei.id = p_sale_event_item_id
    FOR UPDATE OF sei;

    IF NOT FOUND THEN
        RETURN false;
    END IF;

    IF NOT v_item.is_active OR NOT v_item.event_active THEN
        RETURN false;
    END IF;

    IF NOW() < v_item.start_time OR NOW() > v_item.end_time THEN
        RETURN false;
    END IF;

    IF v_item.sale_quota IS NOT NULL AND (v_item.sold_count + p_qty) > v_item.sale_quota THEN
        RETURN false;
    END IF;

    UPDATE public.sale_event_items
    SET sold_count = sold_count + p_qty,
        updated_at = NOW()
    WHERE id = p_sale_event_item_id;

    RETURN true;
END;
$$;

-- Idempotent rollback of reserved flash sale quota on expire / cancel / failure
CREATE OR REPLACE FUNCTION public.rollback_order_flash_sale_quota(
    p_order_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_oi RECORD;
BEGIN
    IF pg_trigger_depth() = 0 AND current_setting('role', true) <> 'service_role' THEN
        IF NOT EXISTS (
            SELECT 1 FROM public.orders
            WHERE id = p_order_id
              AND user_id = auth.uid()
              AND (status IN ('cancelled', 'failed') OR payment_status IN ('expired', 'failed'))
        ) THEN
            RAISE EXCEPTION 'Unauthorized quota rollback attempt';
        END IF;
    END IF;

    FOR v_oi IN
        SELECT id, sale_event_item_id, quantity
        FROM public.order_items
        WHERE order_id = p_order_id
          AND is_flash_sale = true
          AND sale_event_item_id IS NOT NULL
          AND quota_rolled_back = false
        FOR UPDATE
    LOOP
        UPDATE public.sale_event_items
        SET sold_count = GREATEST(0, sold_count - v_oi.quantity),
            updated_at = NOW()
        WHERE id = v_oi.sale_event_item_id;

        UPDATE public.order_items
        SET quota_rolled_back = true
        WHERE id = v_oi.id;
    END LOOP;
END;
$$;

-- ------------------------------------------------------------------------------
-- 4. IN-APP NOTIFICATIONS TABLE & HELPERS
-- ------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    category VARCHAR(30) NOT NULL DEFAULT 'system' CHECK (category IN ('transaction', 'promo', 'system')),
    type VARCHAR(60) NOT NULL DEFAULT 'general',
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,
    target_route VARCHAR(255) NULL,
    data JSONB NOT NULL DEFAULT '{}'::jsonb,
    is_read BOOLEAN NOT NULL DEFAULT false,
    read_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
    ON public.notifications(user_id, is_read, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_user_category
    ON public.notifications(user_id, category, created_at DESC);

DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
EXCEPTION
    WHEN duplicate_object THEN NULL;
    WHEN undefined_object THEN NULL;
END $$;

CREATE OR REPLACE FUNCTION public.create_notification(
    p_user_id UUID,
    p_category VARCHAR,
    p_type VARCHAR,
    p_title VARCHAR,
    p_body TEXT,
    p_target_route VARCHAR DEFAULT NULL,
    p_data JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_id UUID;
BEGIN
    IF p_user_id IS NULL THEN
        RETURN NULL;
    END IF;

    INSERT INTO public.notifications (
        user_id,
        category,
        type,
        title,
        body,
        target_route,
        data
    )
    VALUES (
        p_user_id,
        COALESCE(NULLIF(p_category, ''), 'system'),
        COALESCE(NULLIF(p_type, ''), 'general'),
        p_title,
        p_body,
        p_target_route,
        COALESCE(p_data, '{}'::jsonb)
    )
    RETURNING id INTO v_id;

    RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.notify_store_stakeholders(
    p_store_id UUID,
    p_category VARCHAR,
    p_type VARCHAR,
    p_title VARCHAR,
    p_body TEXT,
    p_target_route VARCHAR DEFAULT NULL,
    p_data JSONB DEFAULT '{}'::jsonb
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_recipient UUID;
BEGIN
    FOR v_recipient IN
        SELECT DISTINCT uid FROM (
            SELECT owner_id AS uid FROM public.stores WHERE id = p_store_id
            UNION
            SELECT user_id AS uid FROM public.store_assistants WHERE store_id = p_store_id
        ) recipients
        WHERE uid IS NOT NULL
    LOOP
        PERFORM public.create_notification(
            v_recipient,
            p_category,
            p_type,
            p_title,
            p_body,
            p_target_route,
            p_data
        );
    END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_all_notifications_read()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_updated INT := 0;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    UPDATE public.notifications
    SET is_read = true,
        read_at = NOW()
    WHERE user_id = auth.uid()
      AND is_read = false;

    GET DIAGNOSTICS v_updated = ROW_COUNT;
    RETURN v_updated;
END;
$$;

-- ------------------------------------------------------------------------------
-- 5. AUTOMATED POSTGRES TRIGGERS FOR NOTIFICATIONS & QUOTA ROLLBACK
-- ------------------------------------------------------------------------------

-- A. Orders lifecycle trigger
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

    -- Payment status transitions
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

    -- Order operational status transitions
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
        END IF;
    END IF;

    -- Courier / Biteship tracking milestone transitions
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

DROP TRIGGER IF EXISTS trg_notify_order_lifecycle ON public.orders;
CREATE TRIGGER trg_notify_order_lifecycle
    AFTER INSERT OR UPDATE ON public.orders
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_notify_order_lifecycle();

-- B. Flash Sale / Sale Event broadcast trigger
CREATE OR REPLACE FUNCTION public.fn_notify_new_sale_event()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_buyer_id UUID;
    v_should_notify BOOLEAN := false;
BEGIN
    IF TG_OP = 'INSERT' AND NEW.is_active = true THEN
        v_should_notify := true;
    ELSIF TG_OP = 'UPDATE' AND OLD.is_active = false AND NEW.is_active = true THEN
        v_should_notify := true;
    END IF;

    IF NOT v_should_notify THEN
        RETURN NEW;
    END IF;

    FOR v_buyer_id IN
        SELECT id FROM public.users WHERE role = 'buyer' LIMIT 500
    LOOP
        PERFORM public.create_notification(
            v_buyer_id,
            'promo',
            'flash_sale_new',
            'Flash Sale: ' || NEW.title,
            COALESCE(NULLIF(TRIM(NEW.description), ''), 'Promo Flash Sale ' || NEW.title || ' telah dibuka! Cek produk diskon berbatas kuota sekarang.'),
            '/home',
            jsonb_build_object('sale_event_id', NEW.id)
        );
    END LOOP;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_new_sale_event ON public.sale_events;
CREATE TRIGGER trg_notify_new_sale_event
    AFTER INSERT OR UPDATE OF is_active ON public.sale_events
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_notify_new_sale_event();

-- C. Refunds lifecycle trigger
CREATE OR REPLACE FUNCTION public.fn_notify_refund_lifecycle()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_order RECORD;
BEGIN
    SELECT id, order_number, user_id, store_id
    INTO v_order
    FROM public.orders
    WHERE id = NEW.order_id;

    IF NOT FOUND THEN
        RETURN NEW;
    END IF;

    IF TG_OP = 'INSERT' THEN
        IF COALESCE(NEW.requester_role, 'buyer') = 'buyer' THEN
            PERFORM public.notify_store_stakeholders(
                v_order.store_id,
                'transaction',
                'refund_requested',
                'Pengajuan Refund / Pembatalan Baru',
                'Pembeli mengajukan ' || COALESCE(NEW.request_type, 'refund') || ' untuk pesanan ' || v_order.order_number || '.',
                '/seller/orders/' || v_order.id,
                jsonb_build_object('refund_id', NEW.id, 'order_id', v_order.id)
            );
        ELSE
            PERFORM public.create_notification(
                v_order.user_id,
                'transaction',
                'refund_requested',
                'Pengajuan Pembatalan / Refund Pesanan',
                'Penjual mengajukan ' || COALESCE(NEW.request_type, 'refund') || ' untuk pesanan ' || v_order.order_number || '.',
                '/orders/' || v_order.id,
                jsonb_build_object('refund_id', NEW.id, 'order_id', v_order.id)
            );
        END IF;
        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' AND NEW.status IS DISTINCT FROM OLD.status THEN
        PERFORM public.create_notification(
            v_order.user_id,
            'transaction',
            'refund_updated',
            'Update Status Refund',
            'Status pengajuan refund untuk pesanan ' || v_order.order_number || ' diperbarui menjadi: ' || NEW.status || '.',
            '/orders/' || v_order.id,
            jsonb_build_object('refund_id', NEW.id, 'order_id', v_order.id, 'status', NEW.status)
        );

        PERFORM public.notify_store_stakeholders(
            v_order.store_id,
            'transaction',
            'refund_updated',
            'Update Status Refund Pesanan',
            'Status pengajuan refund pesanan ' || v_order.order_number || ' diperbarui menjadi: ' || NEW.status || '.',
            '/seller/orders/' || v_order.id,
            jsonb_build_object('refund_id', NEW.id, 'order_id', v_order.id, 'status', NEW.status)
        );
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_refund_lifecycle ON public.refunds;
CREATE TRIGGER trg_notify_refund_lifecycle
    AFTER INSERT OR UPDATE OF status ON public.refunds
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_notify_refund_lifecycle();

-- D. Product reviews & seller replies trigger (resolves store_id via products)
CREATE OR REPLACE FUNCTION public.fn_notify_review_lifecycle()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_product RECORD;
BEGIN
    SELECT id, name, store_id
    INTO v_product
    FROM public.products
    WHERE id = NEW.product_id;

    IF NOT FOUND THEN
        RETURN NEW;
    END IF;

    IF TG_OP = 'INSERT' THEN
        PERFORM public.notify_store_stakeholders(
            v_product.store_id,
            'system',
            'new_review',
            'Ulasan Produk Baru',
            'Pembeli memberikan rating ' || NEW.rating || ' bintang untuk "' || v_product.name || '".',
            '/seller/reviews',
            jsonb_build_object('review_id', NEW.id, 'product_id', NEW.product_id)
        );
        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE'
       AND NEW.seller_reply IS DISTINCT FROM OLD.seller_reply
       AND NEW.seller_reply IS NOT NULL
       AND TRIM(NEW.seller_reply) <> '' THEN
        PERFORM public.create_notification(
            NEW.user_id,
            'system',
            'review_replied',
            'Penjual Membalas Ulasan Anda',
            'Balasan pada "' || v_product.name || '": "' || LEFT(TRIM(NEW.seller_reply), 100) || '"',
            '/products/' || NEW.product_id,
            jsonb_build_object('review_id', NEW.id, 'product_id', NEW.product_id)
        );
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_review_lifecycle ON public.product_reviews;
CREATE TRIGGER trg_notify_review_lifecycle
    AFTER INSERT OR UPDATE OF seller_reply ON public.product_reviews
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_notify_review_lifecycle();

-- E. Store moderation trigger
CREATE OR REPLACE FUNCTION public.fn_notify_store_moderation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NEW.status IS DISTINCT FROM OLD.status THEN
        PERFORM public.create_notification(
            NEW.owner_id,
            'system',
            'store_moderation',
            'Update Status Toko UMK',
            'Status toko "' || NEW.name || '" diperbarui menjadi: ' || NEW.status || '.',
            '/seller/store',
            jsonb_build_object('store_id', NEW.id, 'status', NEW.status)
        );
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_store_moderation ON public.stores;
CREATE TRIGGER trg_notify_store_moderation
    AFTER UPDATE OF status ON public.stores
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_notify_store_moderation();

-- F. Product moderation (archive/restore) trigger
CREATE OR REPLACE FUNCTION public.fn_notify_product_moderation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NEW.archived_at IS DISTINCT FROM OLD.archived_at THEN
        PERFORM public.notify_store_stakeholders(
            NEW.store_id,
            'system',
            'product_moderation',
            CASE WHEN NEW.archived_at IS NOT NULL THEN 'Produk Diarsipkan Admin' ELSE 'Produk Dipulihkan Admin' END,
            'Produk "' || NEW.name || '" telah ' ||
                CASE WHEN NEW.archived_at IS NOT NULL THEN 'diarsipkan oleh Admin.' ELSE 'dipulihkan ke katalog publik.' END,
            '/seller/products',
            jsonb_build_object('product_id', NEW.id, 'archived', NEW.archived_at IS NOT NULL)
        );
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_product_moderation ON public.products;
CREATE TRIGGER trg_notify_product_moderation
    AFTER UPDATE OF archived_at ON public.products
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_notify_product_moderation();

-- G. System feedback response trigger
CREATE OR REPLACE FUNCTION public.fn_notify_feedback_update()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NEW.status IS DISTINCT FROM OLD.status OR NEW.admin_notes IS DISTINCT FROM OLD.admin_notes THEN
        PERFORM public.create_notification(
            NEW.user_id,
            'system',
            'feedback_updated',
            'Update Tiket Bantuan & Masukan',
            'Admin menanggapi tiket "' || NEW.subject || '" (Status: ' || NEW.status || ').',
            '/feedback',
            jsonb_build_object('feedback_id', NEW.id, 'status', NEW.status)
        );
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_feedback_update ON public.system_feedbacks;
CREATE TRIGGER trg_notify_feedback_update
    AFTER UPDATE OF status, admin_notes ON public.system_feedbacks
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_notify_feedback_update();

-- ------------------------------------------------------------------------------
-- 6. RLS POLICIES & GRANTS
-- ------------------------------------------------------------------------------

ALTER TABLE public.sale_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sale_event_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Grants
GRANT SELECT ON public.sale_events TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.sale_events TO authenticated;
GRANT ALL ON public.sale_events TO service_role;

GRANT SELECT ON public.sale_event_items TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.sale_event_items TO authenticated;
GRANT ALL ON public.sale_event_items TO service_role;

GRANT SELECT, DELETE ON public.notifications TO authenticated;
GRANT UPDATE (is_read, read_at) ON public.notifications TO authenticated;
GRANT ALL ON public.notifications TO service_role;

GRANT EXECUTE ON FUNCTION public.calculate_sale_price(NUMERIC, VARCHAR, NUMERIC) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_active_product_flash_sales(UUID[], UUID) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.reserve_flash_sale_quota(UUID, INT, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rollback_order_flash_sale_quota(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.mark_all_notifications_read() TO authenticated, service_role;

-- Policies for sale_events
DROP POLICY IF EXISTS "Public can view active sale events" ON public.sale_events;
CREATE POLICY "Public can view active sale events"
ON public.sale_events
FOR SELECT
TO anon, authenticated
USING (
    is_active = true
    OR created_by = auth.uid()
    OR (
        store_id IS NOT NULL
        AND EXISTS (
            SELECT 1 FROM public.stores s
            WHERE s.id = sale_events.store_id
              AND (
                  s.owner_id = auth.uid()
                  OR EXISTS (
                      SELECT 1 FROM public.store_assistants sa
                      WHERE sa.store_id = s.id AND sa.user_id = auth.uid()
                  )
              )
        )
    )
);

DROP POLICY IF EXISTS "Store owners and assistants can manage store sale events" ON public.sale_events;
CREATE POLICY "Store owners and assistants can manage store sale events"
ON public.sale_events
FOR ALL
TO authenticated
USING (
    store_id IS NOT NULL
    AND EXISTS (
        SELECT 1 FROM public.stores s
        WHERE s.id = sale_events.store_id
          AND (
              s.owner_id = auth.uid()
              OR EXISTS (
                  SELECT 1 FROM public.store_assistants sa
                  WHERE sa.store_id = s.id AND sa.user_id = auth.uid()
              )
          )
    )
)
WITH CHECK (
    store_id IS NOT NULL
    AND EXISTS (
        SELECT 1 FROM public.stores s
        WHERE s.id = sale_events.store_id
          AND (
              s.owner_id = auth.uid()
              OR EXISTS (
                  SELECT 1 FROM public.store_assistants sa
                  WHERE sa.store_id = s.id AND sa.user_id = auth.uid()
              )
          )
    )
);

-- Policies for sale_event_items
DROP POLICY IF EXISTS "Public can view sale event items" ON public.sale_event_items;
CREATE POLICY "Public can view sale event items"
ON public.sale_event_items
FOR SELECT
TO anon, authenticated
USING (true);

DROP POLICY IF EXISTS "Store owners and assistants can manage own store sale items" ON public.sale_event_items;
CREATE POLICY "Store owners and assistants can manage own store sale items"
ON public.sale_event_items
FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.stores s
        WHERE s.id = sale_event_items.store_id
          AND (
              s.owner_id = auth.uid()
              OR EXISTS (
                  SELECT 1 FROM public.store_assistants sa
                  WHERE sa.store_id = s.id AND sa.user_id = auth.uid()
              )
          )
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.stores s
        WHERE s.id = sale_event_items.store_id
          AND (
              s.owner_id = auth.uid()
              OR EXISTS (
                  SELECT 1 FROM public.store_assistants sa
                  WHERE sa.store_id = s.id AND sa.user_id = auth.uid()
              )
          )
    )
    AND EXISTS (
        SELECT 1 FROM public.sale_events se
        WHERE se.id = sale_event_items.sale_event_id
          AND (se.store_id IS NULL OR se.store_id = sale_event_items.store_id)
    )
);

-- Policies for notifications (strict owner-only read/update/delete; insert only via triggers/admin)
DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
CREATE POLICY "Users can view own notifications"
ON public.notifications
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can mark own notifications read" ON public.notifications;
CREATE POLICY "Users can mark own notifications read"
ON public.notifications
FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own notifications" ON public.notifications;
CREATE POLICY "Users can delete own notifications"
ON public.notifications
FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

NOTIFY pgrst, 'reload schema';
