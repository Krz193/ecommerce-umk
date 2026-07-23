-- Fix RLS policies for product_reviews (Excel B59 & B32)

drop policy if exists "Buyers can insert review for delivered order" on public.product_reviews;
drop policy if exists "Buyers or store owners can update review" on public.product_reviews;
drop policy if exists "Buyers can delete their review" on public.product_reviews;
drop policy if exists "Anyone can view approved reviews" on public.product_reviews;

create policy "Anyone can view approved reviews"
on public.product_reviews for select
using (
    is_approved = true
    or user_id = auth.uid()
    or exists (
        select 1 from public.products p
        join public.stores s on p.store_id = s.id
        where p.id = product_reviews.product_id
        and s.owner_id = auth.uid()
    )
);

create policy "Buyers can insert review for completed order"
on public.product_reviews for insert
with check (
    auth.uid() = user_id
    and exists (
        select 1 from public.orders o
        where o.id = product_reviews.order_id
        and o.user_id = auth.uid()
    )
);

create policy "Buyers or store owners can update review"
on public.product_reviews for update
using (
    auth.uid() = user_id
    or exists (
        select 1 from public.products p
        join public.stores s on p.store_id = s.id
        where p.id = product_reviews.product_id
        and s.owner_id = auth.uid()
    )
);

create policy "Buyers can delete their review"
on public.product_reviews for delete
using (
    auth.uid() = user_id
);
