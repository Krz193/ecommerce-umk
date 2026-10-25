-- Migration: Batch 1C — Buyer Non-Logistics Features (#7, #8, #12)

-- 1. #12 Link Donations to UMK Store Content & Enable Buyer CRUD Policies
ALTER TABLE public.donations
    ADD COLUMN IF NOT EXISTS content_id UUID NULL REFERENCES public.store_contents(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_donations_content_id ON public.donations(content_id);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.donations TO authenticated;

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
CREATE POLICY "Buyers can delete own undistributed donations"
ON public.donations FOR DELETE TO authenticated
USING (
    auth.uid() = user_id
    AND status != 'distributed'
);

NOTIFY pgrst, 'reload schema';
