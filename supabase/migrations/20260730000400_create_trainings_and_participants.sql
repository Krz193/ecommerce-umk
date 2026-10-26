-- Migration: create_trainings_and_participants
-- Supports UMK Business Training & Capacity Building (Excel A8 & A9)

CREATE TABLE IF NOT EXISTS public.trainings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    description TEXT NULL,
    instructor VARCHAR(255) NOT NULL DEFAULT 'Tim Ahli / Instruktur UMK',
    schedule_at TIMESTAMPTZ NOT NULL,
    location_or_url TEXT NOT NULL DEFAULT 'Online via Zoom',
    max_participants INTEGER NOT NULL DEFAULT 50,
    status VARCHAR(50) NOT NULL DEFAULT 'upcoming', -- upcoming, ongoing, completed, cancelled
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.training_participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    training_id UUID NOT NULL REFERENCES public.trainings(id) ON DELETE CASCADE,
    store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    status VARCHAR(50) NOT NULL DEFAULT 'registered', -- registered, attended, completed, cancelled
    notes TEXT NULL,
    registered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_training_store UNIQUE (training_id, store_id)
);

CREATE INDEX IF NOT EXISTS idx_trainings_schedule_at ON public.trainings(schedule_at);
CREATE INDEX IF NOT EXISTS idx_trainings_status ON public.trainings(status);
CREATE INDEX IF NOT EXISTS idx_training_participants_store ON public.training_participants(store_id);
CREATE INDEX IF NOT EXISTS idx_training_participants_user ON public.training_participants(user_id);

-- RLS policies for trainings
ALTER TABLE public.trainings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.training_participants ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view trainings" ON public.trainings
    FOR SELECT TO authenticated, anon USING (true);

CREATE POLICY "Store owners can view their training participations" ON public.training_participants
    FOR SELECT TO authenticated USING (
        user_id = auth.uid() OR
        EXISTS (SELECT 1 FROM public.stores WHERE stores.id = training_participants.store_id AND stores.owner_id = auth.uid())
    );

CREATE POLICY "Store owners can register for trainings" ON public.training_participants
    FOR INSERT TO authenticated WITH CHECK (
        user_id = auth.uid() OR
        EXISTS (SELECT 1 FROM public.stores WHERE stores.id = training_participants.store_id AND stores.owner_id = auth.uid())
    );

GRANT ALL ON public.trainings TO service_role, authenticated, anon;
GRANT ALL ON public.training_participants TO service_role, authenticated, anon;
