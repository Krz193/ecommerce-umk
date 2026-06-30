create or replace function public.is_seller()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1
        from public.users
        where id = auth.uid()
        and role = 'seller'
    );
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1
        from public.users
        where id = auth.uid()
        and role = 'admin'
    );
$$;

create or replace function public.is_store_owner(
    store_uuid uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1
        from public.stores
        where id = store_uuid
        and owner_id = auth.uid()
    );
$$;
