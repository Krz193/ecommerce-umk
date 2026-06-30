create unique index if not exists
stores_owner_unique
on public.stores (
    owner_id
);

grant select, insert, update
on public.stores
to authenticated;

drop policy if exists "Store owners can manage own store"
on public.stores;

create policy "Store owners can view own store"
on public.stores
for select
to authenticated
using (
    auth.uid() = owner_id
);

create policy "Sellers can create own store"
on public.stores
for insert
to authenticated
with check (
    auth.uid() = owner_id
    and public.is_seller()
);

create policy "Store owners can update own store"
on public.stores
for update
to authenticated
using (
    auth.uid() = owner_id
)
with check (
    auth.uid() = owner_id
);
