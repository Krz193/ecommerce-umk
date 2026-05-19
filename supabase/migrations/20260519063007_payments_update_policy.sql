create policy "Users can update own payments"
on public.payments
for update
to authenticated
using (
    exists (
        select 1
        from public.orders o
        where o.id = payments.order_id
          and o.user_id = auth.uid()
    )
)
with check (
    exists (
        select 1
        from public.orders o
        where o.id = payments.order_id
          and o.user_id = auth.uid()
    )
);