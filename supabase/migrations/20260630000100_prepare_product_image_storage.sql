insert into storage.buckets (
    id,
    name,
    public,
    file_size_limit,
    allowed_mime_types
)
values (
    'product-images',
    'product-images',
    true,
    5242880,
    array[
        'image/jpeg',
        'image/png',
        'image/webp'
    ]
)
on conflict (id) do update
set
    public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Public can read product image objects"
on storage.objects;

drop policy if exists "Store owners can upload product image objects"
on storage.objects;

drop policy if exists "Store owners can update product image objects"
on storage.objects;

drop policy if exists "Store owners can delete product image objects"
on storage.objects;

create policy "Public can read product image objects"
on storage.objects
for select
using (
    bucket_id = 'product-images'
);

create policy "Store owners can upload product image objects"
on storage.objects
for insert
to authenticated
with check (
    bucket_id = 'product-images'
    and (storage.foldername(storage.objects.name))[1] = 'products'
    and exists (
        select 1
        from public.products
        join public.stores
          on stores.id = products.store_id
        where products.id::text = (storage.foldername(storage.objects.name))[2]
          and stores.owner_id = auth.uid()
    )
);

create policy "Store owners can update product image objects"
on storage.objects
for update
to authenticated
using (
    bucket_id = 'product-images'
    and (storage.foldername(storage.objects.name))[1] = 'products'
    and exists (
        select 1
        from public.products
        join public.stores
          on stores.id = products.store_id
        where products.id::text = (storage.foldername(storage.objects.name))[2]
          and stores.owner_id = auth.uid()
    )
)
with check (
    bucket_id = 'product-images'
    and (storage.foldername(storage.objects.name))[1] = 'products'
    and exists (
        select 1
        from public.products
        join public.stores
          on stores.id = products.store_id
        where products.id::text = (storage.foldername(storage.objects.name))[2]
          and stores.owner_id = auth.uid()
    )
);

create policy "Store owners can delete product image objects"
on storage.objects
for delete
to authenticated
using (
    bucket_id = 'product-images'
    and (storage.foldername(storage.objects.name))[1] = 'products'
    and exists (
        select 1
        from public.products
        join public.stores
          on stores.id = products.store_id
        where products.id::text = (storage.foldername(storage.objects.name))[2]
          and stores.owner_id = auth.uid()
    )
);

grant select, insert, update, delete
on public.product_images
to authenticated;

drop policy if exists "Store owners can view own product images"
on public.product_images;

drop policy if exists "Store owners can create own product images"
on public.product_images;

drop policy if exists "Store owners can update own product images"
on public.product_images;

drop policy if exists "Store owners can delete own product images"
on public.product_images;

create policy "Store owners can view own product images"
on public.product_images
for select
to authenticated
using (
    exists (
        select 1
        from public.products
        join public.stores
          on stores.id = products.store_id
        where products.id = product_images.product_id
          and stores.owner_id = auth.uid()
    )
);

create policy "Store owners can create own product images"
on public.product_images
for insert
to authenticated
with check (
    exists (
        select 1
        from public.products
        join public.stores
          on stores.id = products.store_id
        where products.id = product_images.product_id
          and stores.owner_id = auth.uid()
    )
);

create policy "Store owners can update own product images"
on public.product_images
for update
to authenticated
using (
    exists (
        select 1
        from public.products
        join public.stores
          on stores.id = products.store_id
        where products.id = product_images.product_id
          and stores.owner_id = auth.uid()
    )
)
with check (
    exists (
        select 1
        from public.products
        join public.stores
          on stores.id = products.store_id
        where products.id = product_images.product_id
          and stores.owner_id = auth.uid()
    )
);

create policy "Store owners can delete own product images"
on public.product_images
for delete
to authenticated
using (
    exists (
        select 1
        from public.products
        join public.stores
          on stores.id = products.store_id
        where products.id = product_images.product_id
          and stores.owner_id = auth.uid()
    )
);

create or replace function public.set_product_thumbnail(
    product_uuid uuid,
    image_uuid uuid
)
returns public.products
language plpgsql
security definer
set search_path = public
as $$
declare
    target_image public.product_images;
    updated_product public.products;
begin
    select product_images.*
    into target_image
    from public.product_images
    join public.products
      on products.id = product_images.product_id
    join public.stores
      on stores.id = products.store_id
    where product_images.id = image_uuid
      and product_images.product_id = product_uuid
      and stores.owner_id = auth.uid();

    if target_image.id is null then
        raise exception 'Product image not found or not owned by current seller';
    end if;

    update public.products
    set thumbnail_url = target_image.image_url
    where id = product_uuid
    returning *
    into updated_product;

    return updated_product;
end;
$$;

revoke execute on function public.set_product_thumbnail(uuid, uuid)
from public;

grant execute on function public.set_product_thumbnail(uuid, uuid)
to authenticated;
