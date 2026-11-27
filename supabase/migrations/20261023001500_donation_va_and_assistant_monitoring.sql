-- Migration: Donation VA/QRIS Midtrans Payment Fields, Strict RLS, and Mutation Guard

-- 1. Add VA/E-Wallet/QRIS payment lifecycle columns to public.donations
ALTER TABLE public.donations
    ALTER COLUMN status SET DEFAULT 'pending',
    ADD COLUMN IF NOT EXISTS donation_number VARCHAR(100) UNIQUE NULL,
    ADD COLUMN IF NOT EXISTS payment_type VARCHAR(50) NULL,
    ADD COLUMN IF NOT EXISTS payment_channel VARCHAR(50) NULL,
    ADD COLUMN IF NOT EXISTS va_number TEXT NULL,
    ADD COLUMN IF NOT EXISTS biller_code VARCHAR(50) NULL,
    ADD COLUMN IF NOT EXISTS qr_url TEXT NULL,
    ADD COLUMN IF NOT EXISTS deeplink_url TEXT NULL,
    ADD COLUMN IF NOT EXISTS provider_transaction_id TEXT NULL,
    ADD COLUMN IF NOT EXISTS payment_raw_response JSONB NULL,
    ADD COLUMN IF NOT EXISTS expired_at TIMESTAMPTZ NULL,
    ADD COLUMN IF NOT EXISTS paid_at TIMESTAMPTZ NULL;

CREATE INDEX IF NOT EXISTS idx_donations_donation_number ON public.donations(donation_number);

-- 2. Tighten grants & RLS policies on public.donations
REVOKE ALL ON public.donations FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.donations TO authenticated;
GRANT ALL ON public.donations TO service_role;

DROP POLICY IF EXISTS "Anyone can view donations summary" ON public.donations;
DROP POLICY IF EXISTS "Authorized users can view donations" ON public.donations;
CREATE POLICY "Authorized users can view donations"
ON public.donations FOR SELECT TO authenticated
USING (
    auth.uid() = user_id
    OR EXISTS (
        SELECT 1 FROM public.stores s
        WHERE s.id = donations.store_id AND s.owner_id = auth.uid()
    )
    OR EXISTS (
        SELECT 1 FROM public.store_assistants sa
        WHERE sa.store_id = donations.store_id AND sa.user_id = auth.uid()
    )
    OR EXISTS (
        SELECT 1 FROM public.users u
        WHERE u.id = auth.uid() AND u.role = 'admin'
    )
);

DROP POLICY IF EXISTS "Authenticated users can create donations" ON public.donations;
CREATE POLICY "Authenticated users can create donations"
ON public.donations FOR INSERT TO authenticated
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Buyers can update own undistributed donations" ON public.donations;
CREATE POLICY "Buyers can update own undistributed donations"
ON public.donations FOR UPDATE TO authenticated
USING (
    auth.uid() = user_id
    AND status != 'distributed'
)
WITH CHECK (
    auth.uid() = user_id
    AND status != 'distributed'
);

DROP POLICY IF EXISTS "Buyers can delete own undistributed donations" ON public.donations;
DROP POLICY IF EXISTS "Buyers can delete own unpaid donations" ON public.donations;
CREATE POLICY "Buyers can delete own unpaid donations"
ON public.donations FOR DELETE TO authenticated
USING (
    auth.uid() = user_id
    AND status IN ('pending', 'expired', 'failed', 'cancelled')
);

-- 3. Trigger guard to protect paid/distributed donation integrity against direct client tampering
CREATE OR REPLACE FUNCTION public.enforce_buyer_donation_mutation_guard()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_is_admin BOOLEAN := FALSE;
BEGIN
    -- Service role / backend SQL jobs have auth.uid() IS NULL
    IF auth.uid() IS NULL THEN
        RETURN NEW;
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM public.users u
        WHERE u.id = auth.uid() AND u.role = 'admin'
    ) INTO v_is_admin;

    IF v_is_admin THEN
        RETURN NEW;
    END IF;

    IF OLD.status = 'distributed' THEN
        RAISE EXCEPTION 'Donasi yang sudah disalurkan tidak dapat diubah';
    END IF;

    IF OLD.status = 'paid' THEN
        IF NEW.amount IS DISTINCT FROM OLD.amount
           OR NEW.store_id IS DISTINCT FROM OLD.store_id
           OR NEW.status IS DISTINCT FROM OLD.status
           OR NEW.donation_number IS DISTINCT FROM OLD.donation_number
           OR NEW.payment_type IS DISTINCT FROM OLD.payment_type
           OR NEW.payment_channel IS DISTINCT FROM OLD.payment_channel
           OR NEW.va_number IS DISTINCT FROM OLD.va_number
           OR NEW.provider_transaction_id IS DISTINCT FROM OLD.provider_transaction_id THEN
            RAISE EXCEPTION 'Donasi yang sudah lunas tidak dapat diubah nominal, toko, atau status pembayarannya';
        END IF;
        RETURN NEW;
    END IF;

    IF NEW.status IS DISTINCT FROM OLD.status AND NEW.status IN ('paid', 'distributed') THEN
        RAISE EXCEPTION 'Status pembayaran donasi hanya dapat diperbarui oleh sistem pembayaran';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_buyer_donation_mutation_guard ON public.donations;
CREATE TRIGGER trg_enforce_buyer_donation_mutation_guard
BEFORE UPDATE ON public.donations
FOR EACH ROW
EXECUTE FUNCTION public.enforce_buyer_donation_mutation_guard();

NOTIFY pgrst, 'reload schema';
