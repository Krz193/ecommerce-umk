grant select, insert, update, delete
on public.carts
to authenticated;

grant select, insert, update, delete
on public.cart_items
to authenticated;

grant select
on public.products
to authenticated;

grant select
on public.categories
to authenticated;

grant select
on public.product_images
to authenticated;

grant select
on public.stores
to authenticated;

grant select
on public.addresses
to authenticated;