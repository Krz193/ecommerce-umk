-- Migration: create_system_feedbacks
-- Excel Reference: B13 (Admin Comment Sistem) & B33 (User Comment Sistem ke Admin)

CREATE TABLE IF NOT EXISTS public.system_feedbacks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    user_role TEXT NOT NULL DEFAULT 'buyer',
    category TEXT NOT NULL DEFAULT 'saran',
    subject TEXT NOT NULL,
    message TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    admin_notes TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Performance indexes
CREATE INDEX IF NOT EXISTS idx_system_feedbacks_user_id ON public.system_feedbacks(user_id);
CREATE INDEX IF NOT EXISTS idx_system_feedbacks_status ON public.system_feedbacks(status);
CREATE INDEX IF NOT EXISTS idx_system_feedbacks_created_at ON public.system_feedbacks(created_at DESC);

-- Enable Row Level Security (RLS)
ALTER TABLE public.system_feedbacks ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Authenticated users can insert their own feedback" ON public.system_feedbacks;
DROP POLICY IF EXISTS "Authenticated users can view their own feedback" ON public.system_feedbacks;
DROP POLICY IF EXISTS "Service role full access on system_feedbacks" ON public.system_feedbacks;

-- RLS Policies
CREATE POLICY "Authenticated users can insert their own feedback"
ON public.system_feedbacks
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Authenticated users can view their own feedback"
ON public.system_feedbacks
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "Service role full access on system_feedbacks"
ON public.system_feedbacks
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Permissions
GRANT SELECT, INSERT ON public.system_feedbacks TO authenticated;
GRANT ALL ON public.system_feedbacks TO service_role, postgres;
