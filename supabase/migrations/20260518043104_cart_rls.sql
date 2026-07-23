create policy "Users can view own carts"
on public.carts
for select to authenticated using(auth.uid() = user_id);