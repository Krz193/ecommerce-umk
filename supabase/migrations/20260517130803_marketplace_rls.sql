create policy "Public can view active categories"
on public.categories
for select
using (is_active = true);

create policy "Public can view published products"
on public.products
for select
using (status = 'published');

create policy "Public can view product images"
on public.product_images
for select
using (
    exists (
        select 1
        from public.products
        where products.id = product_images.product_id
        and products.status = 'published'
    )
);

create policy "Public can view active stores"
on public.stores
for select
using (status = 'active');

create policy "Store owners can manage own store"
on public.stores
for all
using (auth.uid() = owner_id);

create policy "Store owners can manage own products"
on public.products
for all
using (
    exists (
        select 1
        from public.stores
        where stores.id = products.store_id
        and stores.owner_id = auth.uid()
    )
);

create policy "Store assistants can manage assigned store products"
on public.products
for all
using (
    exists (
        select 1
        from public.store_assistants sa
        where sa.store_id = products.store_id
        and sa.user_id = auth.uid()
    )
);

create policy "Store owners can manage assistants"
on public.store_assistants
for all
using (
    exists (
        select 1
        from public.stores
        where stores.id = store_assistants.store_id
        and stores.owner_id = auth.uid()
    )
);

create policy "Store assistants can view assignment"
on public.store_assistants
for select
using (user_id = auth.uid());