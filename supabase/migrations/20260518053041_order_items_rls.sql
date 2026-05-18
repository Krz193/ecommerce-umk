grant select, insert
on public.order_items
to authenticated;

alter table public.order_items
enable row level security;

-- =========================================================
-- CUSTOMER POLICIES
-- =========================================================

create policy "Users can view own order items"
on public.order_items
for select
to authenticated
using (
    exists (
        select 1
        from public.orders
        where orders.id = order_items.order_id
          and orders.user_id = auth.uid()
    )
);

create policy "Users can create own order items"
on public.order_items
for insert
to authenticated
with check (
    exists (
        select 1
        from public.orders
        where orders.id = order_items.order_id
          and orders.user_id = auth.uid()
    )
);

-- =========================================================
-- SELLER POLICIES
-- =========================================================

create policy "Store assistants can view store order items"
on public.order_items
for select
to authenticated
using (
    exists (
        select 1
        from public.orders o
        join public.store_assistants sa
          on sa.store_id = o.store_id
        where o.id = order_items.order_id
          and sa.user_id = auth.uid()
    )
);