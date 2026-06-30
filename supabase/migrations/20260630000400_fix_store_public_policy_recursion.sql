drop policy if exists "Customers can view stores with published products"
on public.stores;

create or replace function public.store_has_published_products(
    store_uuid uuid
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
    select exists (
        select 1
        from public.products
        where products.store_id = store_uuid
          and products.status = 'published'
    );
$$;

revoke execute on function public.store_has_published_products(uuid)
from public;

grant execute on function public.store_has_published_products(uuid)
to authenticated;

create policy "Customers can view stores with published products"
on public.stores
for select
to authenticated
using (
    public.store_has_published_products(id)
);
