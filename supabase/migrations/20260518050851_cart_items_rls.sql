create policy "Users can view own cart items"
on public.cart_items
for select
to authenticated
using (
    exists (
        select 1
        from public.carts
        where carts.id = cart_items.cart_id
          and carts.user_id = auth.uid()
    )
);

create policy "Users can insert own cart items"
on public.cart_items
for insert
to authenticated
with check (
    exists (
        select 1
        from public.carts
        where carts.id = cart_items.cart_id
          and carts.user_id = auth.uid()
    )
);

create policy "Users can update own cart items"
on public.cart_items
for update
to authenticated
using (
    exists (
        select 1
        from public.carts
        where carts.id = cart_items.cart_id
          and carts.user_id = auth.uid()
    )
)
with check (
    exists (
        select 1
        from public.carts
        where carts.id = cart_items.cart_id
          and carts.user_id = auth.uid()
    )
);

create policy "Users can delete own cart items"
on public.cart_items
for delete
to authenticated
using (
    exists (
        select 1
        from public.carts
        where carts.id = cart_items.cart_id
          and carts.user_id = auth.uid()
    )
);