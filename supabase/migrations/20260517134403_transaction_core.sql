create table public.carts (
    id uuid primary key default gen_random_uuid(),

    user_id uuid not null
        references public.users(id)
        on delete cascade,

    store_id uuid not null
        references public.stores(id)
        on delete cascade,

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),

    unique(user_id, store_id)
);

create table public.cart_items (
    id uuid primary key default gen_random_uuid(),

    cart_id uuid not null
        references public.carts(id)
        on delete cascade,

    product_id uuid not null
        references public.products(id)
        on delete cascade,

    quantity integer not null
        check (quantity > 0),

    created_at timestamptz not null default now(),

    unique(cart_id, product_id)
);

create table public.orders (
    id uuid primary key default gen_random_uuid(),

    user_id uuid not null
        references public.users(id)
        on delete cascade,

    store_id uuid not null
        references public.stores(id)
        on delete cascade,

    order_number text not null unique,

    status text not null default 'pending',

    subtotal numeric not null check (subtotal >= 0),
    shipping_cost numeric not null default 0 check (shipping_cost >= 0),
    application_fee numeric not null default 0 check (application_fee >= 0),
    total_amount numeric not null check (total_amount >= 0),

    payment_status text not null default 'pending',

    shipping_name text not null,
    shipping_phone text not null,
    shipping_address text not null,
    shipping_city text not null,
    shipping_postal_code text,

    placed_at timestamptz,
    paid_at timestamptz,
    completed_at timestamptz,
    cancelled_at timestamptz,

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table public.order_items (
    id uuid primary key default gen_random_uuid(),

    order_id uuid not null
        references public.orders(id)
        on delete cascade,

    product_id uuid
        references public.products(id)
        on delete set null,

    product_name text not null,
    product_price numeric not null check (product_price >= 0),

    quantity integer not null
        check (quantity > 0),

    subtotal numeric not null
        check (subtotal >= 0)
);

create table public.payments (
    id uuid primary key default gen_random_uuid(),

    order_id uuid not null unique
        references public.orders(id)
        on delete cascade,

    provider text not null,

    provider_transaction_id text,

    status text not null default 'pending',

    amount numeric not null
        check (amount >= 0),

    paid_at timestamptz,
    expired_at timestamptz,

    raw_response jsonb,

    created_at timestamptz not null default now()
);

create table public.refunds (
    id uuid primary key default gen_random_uuid(),

    order_id uuid not null
        references public.orders(id)
        on delete cascade,

    reason text not null,

    status text not null default 'requested',

    admin_notes text,

    requested_at timestamptz not null default now(),
    resolved_at timestamptz,

    created_at timestamptz not null default now()
);

create index idx_carts_user_id
on public.carts(user_id);

create index idx_cart_items_cart_id
on public.cart_items(cart_id);

create index idx_orders_user_id
on public.orders(user_id);

create index idx_orders_store_id
on public.orders(store_id);

create index idx_orders_status
on public.orders(status);

create index idx_orders_payment_status
on public.orders(payment_status);

create index idx_order_items_order_id
on public.order_items(order_id);

create index idx_payments_order_id
on public.payments(order_id);

create index idx_refunds_order_id
on public.refunds(order_id);

create trigger update_carts_updated_at
before update on public.carts
for each row
execute function public.update_updated_at_column();

create trigger update_orders_updated_at
before update on public.orders
for each row
execute function public.update_updated_at_column();

alter table public.carts enable row level security;
alter table public.cart_items enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.payments enable row level security;
alter table public.refunds enable row level security;