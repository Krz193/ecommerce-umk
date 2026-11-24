-- Migration: Content Monitoring & Engagement Unification on store_contents
-- 1. Merge engagement metrics into public.store_contents
-- 2. Enforce external social_platform and external_url proof links
-- 3. Restrict store_contents: Assistant UMK = CRUD, Store Owner (UMK) = Read-Only, Public = Revoked
-- 4. Allow Store Owners & Assistants to view creator full_name via non-recursive SECURITY DEFINER helper
-- 5. Restore public.assistance_logs to Read-Only automatic log

-- 1. Add engagement metrics columns to store_contents
ALTER TABLE public.store_contents
    ADD COLUMN IF NOT EXISTS reach_count INTEGER NOT NULL DEFAULT 0 CHECK (reach_count >= 0),
    ADD COLUMN IF NOT EXISTS likes_count INTEGER NOT NULL DEFAULT 0 CHECK (likes_count >= 0),
    ADD COLUMN IF NOT EXISTS comments_count INTEGER NOT NULL DEFAULT 0 CHECK (comments_count >= 0),
    ADD COLUMN IF NOT EXISTS shares_count INTEGER NOT NULL DEFAULT 0 CHECK (shares_count >= 0),
    ADD COLUMN IF NOT EXISTS inquiries_count INTEGER NOT NULL DEFAULT 0 CHECK (inquiries_count >= 0);

-- 2. Backfill existing records and enforce external platform + proof link
UPDATE public.store_contents
SET social_platform = 'instagram'
WHERE social_platform IS NULL
   OR social_platform NOT IN ('instagram', 'tiktok', 'youtube', 'facebook', 'whatsapp', 'marketplace');

UPDATE public.store_contents
SET external_url = 'https://instagram.com'
WHERE external_url IS NULL
   OR btrim(external_url) = '';

ALTER TABLE public.store_contents
    ALTER COLUMN social_platform SET NOT NULL,
    ALTER COLUMN external_url SET NOT NULL;

ALTER TABLE public.store_contents DROP CONSTRAINT IF EXISTS store_contents_social_platform_check;
ALTER TABLE public.store_contents ADD CONSTRAINT store_contents_social_platform_check CHECK (
    social_platform IN ('instagram', 'tiktok', 'youtube', 'facebook', 'whatsapp', 'marketplace')
);

ALTER TABLE public.store_contents DROP CONSTRAINT IF EXISTS store_contents_external_url_not_blank_check;
ALTER TABLE public.store_contents ADD CONSTRAINT store_contents_external_url_not_blank_check CHECK (
    btrim(external_url) <> ''
);

-- 3. Update RLS & Grants on store_contents
REVOKE SELECT ON public.store_contents FROM anon;

DROP POLICY IF EXISTS "Public can view active store contents" ON public.store_contents;
DROP POLICY IF EXISTS "Store owners can manage store contents" ON public.store_contents;
DROP POLICY IF EXISTS "Store owners can view store contents" ON public.store_contents;
DROP POLICY IF EXISTS "Store assistants can manage store contents" ON public.store_contents;

CREATE POLICY "Store owners can view store contents"
ON public.store_contents
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.stores s
        WHERE s.id = store_contents.store_id
          AND s.owner_id = auth.uid()
    )
);

CREATE POLICY "Store assistants can manage store contents"
ON public.store_contents
FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.store_assistants sa
        WHERE sa.store_id = store_contents.store_id
          AND sa.user_id = auth.uid()
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM public.store_assistants sa
        WHERE sa.store_id = store_contents.store_id
          AND sa.user_id = auth.uid()
    )
);

-- 4. Allow store owners and assistants to read assistant creator profile safely without RLS recursion
CREATE OR REPLACE FUNCTION public.can_view_assistant_profile(target_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT auth.uid() IS NOT NULL
       AND (
           EXISTS (
               SELECT 1
               FROM public.store_contents sc
               JOIN public.stores s ON s.id = sc.store_id
               WHERE sc.created_by = target_user_id
                 AND (
                     s.owner_id = auth.uid()
                     OR EXISTS (
                         SELECT 1
                         FROM public.store_assistants sa
                         WHERE sa.store_id = s.id
                           AND sa.user_id = auth.uid()
                     )
                 )
           )
           OR EXISTS (
               SELECT 1
               FROM public.assistance_logs al
               JOIN public.stores s ON s.id = al.store_id
               WHERE al.assistant_id = target_user_id
                 AND (
                     s.owner_id = auth.uid()
                     OR EXISTS (
                         SELECT 1
                         FROM public.store_assistants sa
                         WHERE sa.store_id = s.id
                           AND sa.user_id = auth.uid()
                     )
                 )
           )
       );
$$;

REVOKE EXECUTE ON FUNCTION public.can_view_assistant_profile(uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.can_view_assistant_profile(uuid) TO authenticated;

DROP POLICY IF EXISTS "Store owners and assistants can view content creators" ON public.users;
CREATE POLICY "Store owners and assistants can view content creators"
ON public.users
FOR SELECT
TO authenticated
USING (public.can_view_assistant_profile(id));

-- 5. Restore assistance_logs to Read-Only automatic activity log
DROP POLICY IF EXISTS "Assistants and store owners can update assistance logs" ON public.assistance_logs;
DROP POLICY IF EXISTS "Assistants and store owners can delete assistance logs" ON public.assistance_logs;
REVOKE UPDATE, DELETE ON public.assistance_logs FROM authenticated;

NOTIFY pgrst, 'reload schema';
