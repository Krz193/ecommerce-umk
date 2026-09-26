-- Migration: biteship_logistics_infrastructure
-- Implements robust database architecture for Biteship integration:
-- Logging, Webhook Message Queue, Discrepancy Tracking, and ACID Transactions.

-- 1. Raw API Logging Table [OBS-001]
CREATE TABLE IF NOT EXISTS public.biteship_api_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    url TEXT NOT NULL,
    method TEXT NOT NULL,
    request_body JSONB,
    status_code INTEGER,
    response_body JSONB,
    duration_ms INTEGER,
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_biteship_api_logs_created_at ON public.biteship_api_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_biteship_api_logs_status_code ON public.biteship_api_logs(status_code);

-- 2. Webhook Message Queue / Background Job Table [WHK-002]
CREATE TABLE IF NOT EXISTS public.webhook_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source TEXT NOT NULL DEFAULT 'biteship',
    event_type TEXT NOT NULL,
    payload JSONB NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'processing', 'completed', 'failed'
    attempts INTEGER NOT NULL DEFAULT 0,
    error_message TEXT NULL,
    processed_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_webhook_jobs_status ON public.webhook_jobs(status, created_at);

-- 3. Biteship Discrepancy Tracking Table [FIN-001]
CREATE TABLE IF NOT EXISTS public.biteship_discrepancies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    original_shipping_cost NUMERIC(12,2) NOT NULL DEFAULT 0,
    actual_shipping_cost NUMERIC(12,2) NOT NULL DEFAULT 0,
    discrepancy_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    original_weight NUMERIC(10,2) NULL,
    actual_weight NUMERIC(10,2) NULL,
    seller_balance_adjusted BOOLEAN NOT NULL DEFAULT FALSE,
    notes TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_biteship_discrepancies_order_id ON public.biteship_discrepancies(order_id);

-- 4. Extend orders and stores tables
ALTER TABLE public.orders
ADD COLUMN IF NOT EXISTS idempotency_key TEXT NULL,
ADD COLUMN IF NOT EXISTS actual_shipping_cost NUMERIC(12,2) NULL,
ADD COLUMN IF NOT EXISTS shipping_discrepancy NUMERIC(12,2) NOT NULL DEFAULT 0;

ALTER TABLE public.stores
ADD COLUMN IF NOT EXISTS balance NUMERIC(14,2) NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_orders_idempotency_key ON public.orders(idempotency_key);

-- 5. ACID Transaction RPC for Order Creation & Courier Booking [LOG-002]
-- Encapsulates order updating, internal balance deduction, and status lock in a single ACID transaction block
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
AS $$
DECLARE
    v_order RECORD;
    v_result JSONB;
BEGIN
    -- BEGIN TRANSACTION BLOCK (guaranteed atomic execution in PostgreSQL)
    -- 1. Lock and validate order state
    SELECT * INTO v_order
    FROM public.orders
    WHERE id = p_order_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order with ID % not found', p_order_id;
    END IF;

    -- 2. Deduct / allocate internal store balance for logistics booking
    UPDATE public.stores
    SET balance = balance - p_shipping_cost,
        updated_at = NOW()
    WHERE id = p_store_id;

    -- 3. Save Biteship order info and transition status to shipped
    UPDATE public.orders
    SET biteship_order_id = p_biteship_order_id,
        waybill_id = p_waybill_id,
        tracking_number = p_waybill_id,
        idempotency_key = p_idempotency_key,
        status = 'shipped',
        tracking_status = 'on_delivery',
        driver_name = COALESCE(p_driver_name, driver_name),
        driver_phone = COALESCE(p_driver_phone, driver_phone),
        shipped_at = NOW(),
        updated_at = NOW()
    WHERE id = p_order_id;

    -- COMMIT TRANSACTION
    v_result := jsonb_build_object(
        'success', true,
        'order_id', p_order_id,
        'biteship_order_id', p_biteship_order_id,
        'waybill_id', p_waybill_id,
        'idempotency_key', p_idempotency_key
    );

    RETURN v_result;

EXCEPTION WHEN OTHERS THEN
    -- Automatic ROLLBACK of all state changes
    RAISE EXCEPTION 'Transaction failed and rolled back: %', SQLERRM;
END;
$$;

-- 6. Discrepancy Adjustment RPC [FIN-001]
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
        RAISE EXCEPTION 'Order % not found', p_order_id;
    END IF;

    -- Update order shipping cost and discrepancy
    UPDATE public.orders
    SET actual_shipping_cost = p_actual_shipping_cost,
        shipping_discrepancy = p_discrepancy_amount,
        updated_at = NOW()
    WHERE id = p_order_id;

    -- Adjust seller balance (deduct discrepancy if courier charges more)
    UPDATE public.stores
    SET balance = balance - p_discrepancy_amount,
        updated_at = NOW()
    WHERE id = v_order.store_id;

    -- Record in audit table
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

    v_result := jsonb_build_object(
        'success', true,
        'order_id', p_order_id,
        'store_id', v_order.store_id,
        'original_shipping_cost', v_order.shipping_cost,
        'actual_shipping_cost', p_actual_shipping_cost,
        'discrepancy_amount', p_discrepancy_amount
    );

    RETURN v_result;

EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Discrepancy adjustment failed and rolled back: %', SQLERRM;
END;
$$;

-- RLS & Grants
ALTER TABLE public.biteship_api_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.webhook_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.biteship_discrepancies ENABLE ROW LEVEL SECURITY;

GRANT ALL ON public.biteship_api_logs TO service_role;
GRANT ALL ON public.webhook_jobs TO service_role;
GRANT ALL ON public.biteship_discrepancies TO service_role;

GRANT EXECUTE ON FUNCTION public.execute_order_biteship_transaction TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.apply_shipping_discrepancy TO authenticated, service_role;
