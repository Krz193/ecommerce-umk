grant select, insert, update
on public.orders
to authenticated;

alter table public.orders
enable row level security;

-- =========================================================
-- CUSTOMER POLICIES
-- =========================================================

create policy "Users can view own orders"
on public.orders
for select
to authenticated
using (
    auth.uid() = user_id
);

create policy "Users can create own orders"
on public.orders
for insert
to authenticated
with check (
    auth.uid() = user_id
);

-- =========================================================
-- SELLER POLICIES
-- =========================================================

create policy "Store assistants can view store orders"
on public.orders
for select
to authenticated
using (
    exists (
        select 1
        from public.store_assistants sa
        where sa.store_id = orders.store_id
          and sa.user_id = auth.uid()
    )
);

create policy "Store assistants can update store orders"
on public.orders
for update
to authenticated
using (
    exists (
        select 1
        from public.store_assistants sa
        where sa.store_id = orders.store_id
          and sa.user_id = auth.uid()
    )
)
with check (
    exists (
        select 1
        from public.store_assistants sa
        where sa.store_id = orders.store_id
          and sa.user_id = auth.uid()
    )
);