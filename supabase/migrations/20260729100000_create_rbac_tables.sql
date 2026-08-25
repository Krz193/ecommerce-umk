-- Migration: Create Dynamic Role and Permission Management (RBAC) Tables

create table if not exists public.permissions (
    id uuid primary key default gen_random_uuid(),
    slug text not null unique,
    name text not null,
    category text not null default 'general',
    created_at timestamptz not null default now()
);

create table if not exists public.roles (
    id uuid primary key default gen_random_uuid(),
    slug text not null unique,
    name text not null,
    description text,
    is_system boolean not null default false,
    created_at timestamptz not null default now()
);

create table if not exists public.role_permissions (
    role_id uuid not null references public.roles(id) on delete cascade,
    permission_id uuid not null references public.permissions(id) on delete cascade,
    primary key (role_id, permission_id)
);

create table if not exists public.user_roles (
    user_id uuid not null references public.users(id) on delete cascade,
    role_id uuid not null references public.roles(id) on delete cascade,
    primary key (user_id, role_id)
);

-- Indexing for fast RLS and query lookups
create index if not exists idx_role_permissions_role_id on public.role_permissions(role_id);
create index if not exists idx_role_permissions_permission_id on public.role_permissions(permission_id);
create index if not exists idx_user_roles_user_id on public.user_roles(user_id);
create index if not exists idx_user_roles_role_id on public.user_roles(role_id);

-- Dynamic Postgres Helper Function for Supabase RLS Policy Evaluation
create or replace function public.has_permission(p_permission_slug text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        -- Check 1: Direct fallback if user is system super admin
        select 1 from public.users u
        where u.id = auth.uid() and u.role = 'admin'
        union all
        -- Check 2: Check dynamic RBAC assignment
        select 1
        from public.user_roles ur
        join public.role_permissions rp on rp.role_id = ur.role_id
        join public.permissions p on p.id = rp.permission_id
        where ur.user_id = auth.uid()
          and p.slug = p_permission_slug
    );
$$;

-- Enable RLS on RBAC tables
alter table public.permissions enable row level security;
alter table public.roles enable row level security;
alter table public.role_permissions enable row level security;
alter table public.user_roles enable row level security;

-- Policies for RBAC access
create policy "Authenticated users can read permissions"
on public.permissions for select to authenticated using (true);

create policy "Authenticated users can read roles"
on public.roles for select to authenticated using (true);

create policy "Authenticated users can read role permissions"
on public.role_permissions for select to authenticated using (true);

create policy "Authenticated users can read user roles"
on public.user_roles for select to authenticated using (true);

-- Seed core system permissions
insert into public.permissions (slug, name, category) values
    ('categories.manage', 'Kelola Kategori Produk', 'catalog'),
    ('stores.manage', 'Kelola & Moderasi Toko UMK', 'store'),
    ('products.moderate', 'Kelola & Moderasi Produk', 'catalog'),
    ('orders.view', 'Lihat Transaksi & Pesanan', 'finance'),
    ('refunds.manage', 'Kelola Sengketa & Refund', 'finance'),
    ('users.manage', 'Kelola User & Role System', 'system'),
    ('reports.view', 'Lihat Laporan & Ringkasan', 'reports'),
    ('audit_logs.view', 'Lihat Log Audit System', 'system')
on conflict (slug) do nothing;

-- Seed default system roles
insert into public.roles (slug, name, description, is_system) values
    ('super_admin', 'Super Admin', 'Akses penuh ke seluruh fitur dan pengaturan sistem', true),
    ('content_moderator', 'Moderator Konten', 'Akses moderasi toko, produk, dan katalog kategori', false),
    ('finance_officer', 'Staf Keuangan & Dispute', 'Akses transaksi, laporan keuangan, dan sengketa refund', false)
on conflict (slug) do nothing;

-- Map default role permissions for Content Moderator
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
cross join public.permissions p
where r.slug = 'content_moderator'
  and p.slug in ('categories.manage', 'stores.manage', 'products.moderate')
on conflict do nothing;

-- Map default role permissions for Finance Officer
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
cross join public.permissions p
where r.slug = 'finance_officer'
  and p.slug in ('orders.view', 'refunds.manage', 'reports.view')
on conflict do nothing;

notify pgrst, 'reload schema';
