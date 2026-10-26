-- Migration: add_shipping_biteship_fields
-- Supports Biteship logistics integration (Ojek Instant & Regular Couriers)

-- Enhance orders table
ALTER TABLE public.orders
ADD COLUMN IF NOT EXISTS courier_name TEXT NULL,
ADD COLUMN IF NOT EXISTS courier_code TEXT NULL,
ADD COLUMN IF NOT EXISTS courier_service_code TEXT NULL,
ADD COLUMN IF NOT EXISTS courier_service_type TEXT NULL,
ADD COLUMN IF NOT EXISTS shipping_cost NUMERIC(12,2) NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS biteship_order_id TEXT NULL,
ADD COLUMN IF NOT EXISTS waybill_id TEXT NULL,
ADD COLUMN IF NOT EXISTS driver_name TEXT NULL,
ADD COLUMN IF NOT EXISTS driver_phone TEXT NULL,
ADD COLUMN IF NOT EXISTS tracking_status TEXT NULL DEFAULT 'pending',
ADD COLUMN IF NOT EXISTS tracking_history JSONB NOT NULL DEFAULT '[]'::jsonb;

-- Ensure stores has location/postal code columns
ALTER TABLE public.stores
ADD COLUMN IF NOT EXISTS postal_code TEXT NULL DEFAULT '12430',
ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION NULL DEFAULT -6.303112,
ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION NULL DEFAULT 106.779493;

-- Ensure addresses has location/postal code columns
ALTER TABLE public.addresses
ADD COLUMN IF NOT EXISTS postal_code TEXT NULL DEFAULT '12950',
ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION NULL DEFAULT -6.244179,
ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION NULL DEFAULT 106.783529;

-- Indexes for efficient shipping lookups
CREATE INDEX IF NOT EXISTS idx_orders_courier_code ON public.orders(courier_code);
CREATE INDEX IF NOT EXISTS idx_orders_waybill_id ON public.orders(waybill_id);
CREATE INDEX IF NOT EXISTS idx_orders_tracking_status ON public.orders(tracking_status);
