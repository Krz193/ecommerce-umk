drop policy if exists "Users can manage own addresses"
on public.addresses;

create policy "Users can manage own addresses"
on public.addresses
for all
to authenticated
using (
    auth.uid() = user_id
);

drop policy if exists "Users can view own profile"
on public.users;

create policy "Users can view own profile"
on public.users
for select
to authenticated
using (
    auth.uid() = id
);

drop policy if exists "Users can update own profile"
on public.users;

create policy "Users can update own profile"
on public.users
for update
to authenticated
using (
    auth.uid() = id
);

drop policy if exists "Store assistants can view assignment"
on public.store_assistants;

create policy "Store assistants can view assignment"
on public.store_assistants
for select
to authenticated
using (
    user_id = auth.uid()
);

drop policy if exists "Store owners can manage assistants"
on public.store_assistants;

create policy "Store owners can manage assistants"
on public.store_assistants
for all
to authenticated
using (
    exists (
        select 1
        from stores
        where stores.id = store_assistants.store_id
        and stores.owner_id = auth.uid()
    )
);

drop policy if exists "Store owners can manage own store"
on public.stores;

create policy "Store owners can manage own store"
on public.stores
for all
to authenticated
using (
    auth.uid() = owner_id
);