alter table public.orders
add column shipping_provider text,
add column tracking_number text;

create policy "Users can complete own shipped orders"
on public.orders
for update
to authenticated
using (
    auth.uid() = user_id
    and status = 'shipped'
)
with check (
    auth.uid() = user_id
    and status = 'completed'
);
