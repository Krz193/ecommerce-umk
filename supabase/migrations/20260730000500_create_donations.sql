-- Migration: create_donations
-- Supports Voluntary UMK Donations (Excel A11, A20, A58)

CREATE TABLE IF NOT EXISTS public.donations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NULL REFERENCES public.users(id) ON DELETE SET NULL,
    store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
    order_id UUID NULL REFERENCES public.orders(id) ON DELETE SET NULL,
    amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    donor_name VARCHAR(255) NOT NULL DEFAULT 'Hamba Allah (Anonim)',
    donor_email VARCHAR(255) NULL,
    donor_phone VARCHAR(50) NULL,
    note TEXT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'paid', -- pending, paid, distributed
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_donations_store_id ON public.donations(store_id);
CREATE INDEX IF NOT EXISTS idx_donations_user_id ON public.donations(user_id);
CREATE INDEX IF NOT EXISTS idx_donations_status ON public.donations(status);

ALTER TABLE public.donations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view donations summary" ON public.donations
    FOR SELECT TO authenticated, anon USING (true);

CREATE POLICY "Authenticated users can create donations" ON public.donations
    FOR INSERT TO authenticated WITH CHECK (true);

GRANT ALL ON public.donations TO service_role, authenticated, anon;
