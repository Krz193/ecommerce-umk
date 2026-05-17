create extension if not exists pgcrypto;

create or replace function public.update_updated_at_column()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create table public.users (
    id uuid primary key references auth.users(id) on delete cascade,
    full_name text not null,
    username text unique,
    phone text,
    avatar_url text,
    is_phone_verified boolean not null default false,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table public.addresses (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.users(id) on delete cascade,
    label text,
    recipient_name text not null,
    recipient_phone text not null,
    province text not null,
    city text not null,
    district text,
    postal_code text,
    full_address text not null,
    is_default boolean not null default false,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create trigger update_users_updated_at
before update on public.users
for each row
execute function public.update_updated_at_column();

create trigger update_addresses_updated_at
before update on public.addresses
for each row
execute function public.update_updated_at_column();

alter table public.users enable row level security;
alter table public.addresses enable row level security;

create policy "Users can view own profile"
on public.users
for select
using (auth.uid() = id);

create policy "Users can update own profile"
on public.users
for update
using (auth.uid() = id);

create policy "Users can manage own addresses"
on public.addresses
for all
using (auth.uid() = user_id);