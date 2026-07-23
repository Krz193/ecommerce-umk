-- Update users_role_check constraint to allow 'assistant'
alter table public.users drop constraint if exists users_role_check;
alter table public.users add constraint users_role_check check (
    role in (
        'buyer',
        'seller',
        'assistant',
        'admin'
    )
);

-- Role helper for assistant
create or replace function public.is_assistant()
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
        and role = 'assistant'
    );
$$;

create or replace function public.become_assistant()
returns public.users
language plpgsql
security definer
set search_path = public
as $$
declare
    updated_user public.users;
begin
    if auth.uid() is null then
        raise exception 'Authentication required';
    end if;

    update public.users
    set role = 'assistant'
    where id = auth.uid()
      and role = 'buyer'
    returning *
    into updated_user;

    if not found then
        raise exception 'Only buyer accounts can become assistants';
    end if;

    return updated_user;
end;
$$;

revoke execute on function public.is_assistant() from public, anon;
grant execute on function public.is_assistant() to authenticated;

revoke execute on function public.become_assistant() from public, anon;
grant execute on function public.become_assistant() to authenticated;

-- Create store_contents table for CRUD Content UMK
create table if not exists public.store_contents (
    id uuid primary key default gen_random_uuid(),
    store_id uuid not null references public.stores(id) on delete cascade,
    created_by uuid not null references public.users(id) on delete cascade,
    title text not null,
    content_type text not null check (content_type in ('banner', 'promo', 'storytelling', 'social', 'educational')),
    body text,
    media_urls text[] default array[]::text[],
    is_active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists idx_store_contents_store_id on public.store_contents(store_id);
create index if not exists idx_store_contents_created_by on public.store_contents(created_by);

grant select, insert, update, delete on public.store_contents to authenticated;
grant select on public.store_contents to anon;

alter table public.store_contents enable row level security;

create policy "Public can view active store contents"
on public.store_contents for select to public
using (is_active = true);

create policy "Store owners can manage store contents"
on public.store_contents for all to authenticated
using (
    exists (
        select 1 from public.stores s
        where s.id = store_contents.store_id
          and s.owner_id = auth.uid()
    )
)
with check (
    exists (
        select 1 from public.stores s
        where s.id = store_contents.store_id
          and s.owner_id = auth.uid()
    )
);

create policy "Store assistants can manage store contents"
on public.store_contents for all to authenticated
using (
    exists (
        select 1 from public.store_assistants sa
        where sa.store_id = store_contents.store_id
          and sa.user_id = auth.uid()
    )
)
with check (
    exists (
        select 1 from public.store_assistants sa
        where sa.store_id = store_contents.store_id
          and sa.user_id = auth.uid()
    )
);

notify pgrst, 'reload schema';
