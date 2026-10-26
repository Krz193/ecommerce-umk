-- Migration: Add notes (patokan kurir) and biteship_area_id to addresses, stores, and orders
ALTER TABLE public.addresses
ADD COLUMN IF NOT EXISTS notes TEXT,
ADD COLUMN IF NOT EXISTS biteship_area_id TEXT;

ALTER TABLE public.stores
ADD COLUMN IF NOT EXISTS notes TEXT,
ADD COLUMN IF NOT EXISTS biteship_area_id TEXT;

ALTER TABLE public.orders
ADD COLUMN IF NOT EXISTS shipping_notes TEXT,
ADD COLUMN IF NOT EXISTS origin_area_id TEXT,
ADD COLUMN IF NOT EXISTS destination_area_id TEXT;

COMMENT ON COLUMN public.addresses.notes IS 'Detail patokan pengiriman seperti blok, unit, warna pagar, atau ancer-ancer (Shopee-grade notes)';
COMMENT ON COLUMN public.orders.shipping_notes IS 'Catatan patokan pengiriman untuk kurir';
