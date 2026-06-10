grant select, insert, update, delete
on public.products
to authenticated;

create policy "Store owners can view own products"
on public.products
for select
to authenticated
using (
    public.is_store_owner(store_id)
);

create policy "Store owners can create own products"
on public.products
for insert
to authenticated
with check (
    public.is_store_owner(store_id)
);

create policy "Store owners can update own products"
on public.products
for update
to authenticated
using (
    public.is_store_owner(store_id)
)
with check (
    public.is_store_owner(store_id)
);

create policy "Store owners can delete own products"
on public.products
for delete
to authenticated
using (
    public.is_store_owner(store_id)
);
