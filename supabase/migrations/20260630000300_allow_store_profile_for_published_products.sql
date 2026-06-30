create policy "Customers can view stores with published products"
on public.stores
for select
to authenticated
using (
    exists (
        select 1
        from public.products
        where products.store_id = stores.id
          and products.status = 'published'
    )
);
