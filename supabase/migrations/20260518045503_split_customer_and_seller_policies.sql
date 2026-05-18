-- Drop old policies
drop policy if exists "Store assistants can manage products"
on public.products;

drop policy if exists "Users can view published products"
on public.products;

drop policy if exists "Customers can view published products"
on public.products;

drop policy if exists "Store assistants can view own store products"
on public.products;

drop policy if exists "Store assistants can create products"
on public.products;

drop policy if exists "Store assistants can update products"
on public.products;

drop policy if exists "Store assistants can delete products"
on public.products;

-- =========================================================
-- CUSTOMER POLICIES
-- =========================================================

create policy "Customers can view published products"
on public.products
for select
to authenticated
using (
    status = 'published'
);

-- =========================================================
-- SELLER POLICIES
-- =========================================================

create policy "Store assistants can view own store products"
on public.products
for select
to authenticated
using (
    exists (
        select 1
        from public.store_assistants sa
        where sa.store_id = products.store_id
          and sa.user_id = auth.uid()
    )
);

create policy "Store assistants can create products"
on public.products
for insert
to authenticated
with check (
    exists (
        select 1
        from public.store_assistants sa
        where sa.store_id = products.store_id
          and sa.user_id = auth.uid()
    )
);

create policy "Store assistants can update products"
on public.products
for update
to authenticated
using (
    exists (
        select 1
        from public.store_assistants sa
        where sa.store_id = products.store_id
          and sa.user_id = auth.uid()
    )
)
with check (
    exists (
        select 1
        from public.store_assistants sa
        where sa.store_id = products.store_id
          and sa.user_id = auth.uid()
    )
);

create policy "Store assistants can delete products"
on public.products
for delete
to authenticated
using (
    exists (
        select 1
        from public.store_assistants sa
        where sa.store_id = products.store_id
          and sa.user_id = auth.uid()
    )
);