-- Create product_recommendations table for Admin curated recommendations

create table public.product_recommendations (
    id uuid primary key default gen_random_uuid(),
    product_id uuid not null unique references public.products(id) on delete cascade,
    priority integer not null default 0,
    badge_text text,
    is_active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index idx_product_recommendations_priority on public.product_recommendations(priority desc);
create index idx_product_recommendations_is_active on public.product_recommendations(is_active);

-- Enable RLS
alter table public.product_recommendations enable row level security;

-- Grants
grant select on public.product_recommendations to authenticated, anon;
-- Admin write access will be via service_role or admin RLS policy if setup. We'll use service_role for backend (Laravel).

-- Policies
create policy "Anyone can view active recommendations"
on public.product_recommendations for select
using (is_active = true);

-- Add update trigger for updated_at
create trigger update_product_recommendations_updated_at
before update on public.product_recommendations
for each row
execute function public.update_updated_at_column();
