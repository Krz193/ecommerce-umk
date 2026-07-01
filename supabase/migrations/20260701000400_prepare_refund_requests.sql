alter table public.refunds
add column if not exists requested_by uuid
    references public.users(id)
    on delete set null,
add column if not exists requester_role text
    check (requester_role in ('buyer', 'seller', 'admin')),
add column if not exists request_type text not null default 'refund'
    check (request_type in ('cancellation', 'refund'));

create index if not exists idx_refunds_requested_by
on public.refunds(requested_by);

grant select, insert
on public.refunds
to authenticated;

drop policy if exists "Buyers can view own refund requests"
on public.refunds;

drop policy if exists "Buyers can create own refund requests"
on public.refunds;

drop policy if exists "Store owners can view store refund requests"
on public.refunds;

drop policy if exists "Store owners can create store refund requests"
on public.refunds;

create policy "Buyers can view own refund requests"
on public.refunds
for select
to authenticated
using (
    exists (
        select 1
        from public.orders
        where orders.id = refunds.order_id
          and orders.user_id = auth.uid()
    )
);

create policy "Buyers can create own refund requests"
on public.refunds
for insert
to authenticated
with check (
    requested_by = auth.uid()
    and requester_role = 'buyer'
    and exists (
        select 1
        from public.orders
        where orders.id = refunds.order_id
          and orders.user_id = auth.uid()
          and orders.status not in ('cancelled')
          and orders.payment_status in ('paid', 'pending')
    )
);

create policy "Store owners can view store refund requests"
on public.refunds
for select
to authenticated
using (
    exists (
        select 1
        from public.orders
        where orders.id = refunds.order_id
          and public.is_store_owner(orders.store_id)
    )
);

create policy "Store owners can create store refund requests"
on public.refunds
for insert
to authenticated
with check (
    requested_by = auth.uid()
    and requester_role = 'seller'
    and exists (
        select 1
        from public.orders
        where orders.id = refunds.order_id
          and public.is_store_owner(orders.store_id)
          and orders.status not in ('cancelled', 'completed')
          and orders.payment_status in ('paid', 'pending')
    )
);
