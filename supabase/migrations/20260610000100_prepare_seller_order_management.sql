create policy "Store owners can view store order items"
on public.order_items
for select
to authenticated
using (
    exists (
        select 1
        from public.orders
        join public.stores
          on stores.id = orders.store_id
        where orders.id = order_items.order_id
          and stores.owner_id = auth.uid()
    )
);

create policy "Store owners can view store payments"
on public.payments
for select
to authenticated
using (
    exists (
        select 1
        from public.orders
        join public.stores
          on stores.id = orders.store_id
        where orders.id = payments.order_id
          and stores.owner_id = auth.uid()
    )
);
