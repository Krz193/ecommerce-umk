-- Migration for Product Reviews and Ratings (Excel B59 & B32)

create table public.product_reviews (
    id uuid primary key default gen_random_uuid(),

    product_id uuid not null
        references public.products(id)
        on delete cascade,

    user_id uuid not null
        references public.users(id)
        on delete cascade,

    order_id uuid not null
        references public.orders(id)
        on delete cascade,

    rating integer not null
        check (rating >= 1 and rating <= 5),

    comment text,

    seller_reply text,
    seller_replied_at timestamptz,

    is_approved boolean not null default true,

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),

    unique(user_id, product_id, order_id)
);

create index idx_product_reviews_product_id
on public.product_reviews(product_id);

create index idx_product_reviews_user_id
on public.product_reviews(user_id);

create index idx_product_reviews_order_id
on public.product_reviews(order_id);

create trigger update_product_reviews_updated_at
before update on public.product_reviews
for each row
execute function public.update_updated_at_column();

-- Enable RLS
alter table public.product_reviews enable row level security;

-- Grants
grant select, insert, update, delete on public.product_reviews to authenticated;
grant select on public.product_reviews to anon;

-- RLS Policies
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

create policy "Buyers can insert review for delivered order"
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
