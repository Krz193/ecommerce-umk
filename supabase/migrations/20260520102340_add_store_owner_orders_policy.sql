/*
|--------------------------------------------------------------------------
| Store Owner Orders Access Policy
|--------------------------------------------------------------------------
|
| Allows store owners to access and
| manage operational order lifecycle.
|
*/

create policy "Store owners can view store orders"
on orders
for select
to authenticated
using (
    exists (
        select 1
        from stores
        where stores.id = orders.store_id
        and stores.owner_id = auth.uid()
    )
);

create policy "Store owners can update store orders"
on orders
for update
to authenticated
using (
    exists (
        select 1
        from stores
        where stores.id = orders.store_id
        and stores.owner_id = auth.uid()
    )
)
with check (
    exists (
        select 1
        from stores
        where stores.id = orders.store_id
        and stores.owner_id = auth.uid()
    )
);