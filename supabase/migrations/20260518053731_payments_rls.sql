grant select, insert
on public.payments
to authenticated;

alter table public.payments
enable row level security;

-- =========================================================
-- CUSTOMER POLICIES
-- =========================================================

create policy "Users can view own payments"
on public.payments
for select
to authenticated
using (
    exists (
        select 1
        from public.orders
        where orders.id = payments.order_id
          and orders.user_id = auth.uid()
    )
);

create policy "Users can create own payments"
on public.payments
for insert
to authenticated
with check (
    exists (
        select 1
        from public.orders
        where orders.id = payments.order_id
          and orders.user_id = auth.uid()
    )
);

-- =========================================================
-- SELLER POLICIES
-- =========================================================

create policy "Store assistants can view store payments"
on public.payments
for select
to authenticated
using (
    exists (
        select 1
        from public.orders o
        join public.store_assistants sa
          on sa.store_id = o.store_id
        where o.id = payments.order_id
          and sa.user_id = auth.uid()
    )
);