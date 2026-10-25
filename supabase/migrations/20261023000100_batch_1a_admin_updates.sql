-- Migration: batch_1a_admin_updates
-- #1 Training report & documentation, #2 donation distribution date/amount,
-- #5 product discount/tax price breakdown. All changes are additive.

-- #1: Post-training report & documentation (jsonb array of image URLs)
ALTER TABLE public.trainings
ADD COLUMN IF NOT EXISTS report_summary TEXT NULL,
ADD COLUMN IF NOT EXISTS documentation_urls JSONB NOT NULL DEFAULT '[]'::jsonb,
ADD COLUMN IF NOT EXISTS material_url TEXT NULL;

-- #2: Distribution date & amount per donation
ALTER TABLE public.donations
ADD COLUMN IF NOT EXISTS distributed_at TIMESTAMPTZ NULL,
ADD COLUMN IF NOT EXISTS distributed_amount NUMERIC(12,2) NULL CHECK (distributed_amount IS NULL OR distributed_amount > 0);

-- Backfill donations already marked as distributed before these columns existed
UPDATE public.donations
SET distributed_at = updated_at,
    distributed_amount = amount
WHERE status = 'distributed'
  AND distributed_at IS NULL;

-- #5: Price breakdown. products.price stays the final selling price
-- (checkout and mobile keep reading it); the admin panel computes it
-- server-side from these columns.
ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS original_price NUMERIC(12,2) NULL CHECK (original_price IS NULL OR original_price >= 0),
ADD COLUMN IF NOT EXISTS discount_percent NUMERIC(5,2) NOT NULL DEFAULT 0 CHECK (discount_percent >= 0 AND discount_percent <= 100),
ADD COLUMN IF NOT EXISTS discount_amount NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
ADD COLUMN IF NOT EXISTS tax_percent NUMERIC(5,2) NOT NULL DEFAULT 0 CHECK (tax_percent >= 0 AND tax_percent <= 100);

NOTIFY pgrst, 'reload schema';
