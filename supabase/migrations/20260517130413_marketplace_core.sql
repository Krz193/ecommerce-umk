create table public.stores (
    id uuid primary key default gen_random_uuid(),
    owner_id uuid not null references public.users(id) on delete cascade,

    name text not null,
    slug text not null unique,
    description text,

    logo_url text,
    banner_url text,

    phone text,
    address text,

    payout_account_name text,
    payout_account_number text,
    payout_provider text,

    status text not null default 'pending',

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    suspended_at timestamptz
);

create table public.store_assistants (
    id uuid primary key default gen_random_uuid(),

    store_id uuid not null unique
        references public.stores(id)
        on delete cascade,

    user_id uuid not null
        references public.users(id)
        on delete cascade,

    assigned_by uuid not null
        references public.users(id)
        on delete cascade,

    assigned_at timestamptz not null default now(),
    created_at timestamptz not null default now()
);

create table public.categories (
    id uuid primary key default gen_random_uuid(),

    name text not null,
    slug text not null unique,

    icon_url text,

    is_active boolean not null default true,

    created_at timestamptz not null default now()
);

create table public.products (
    id uuid primary key default gen_random_uuid(),

    store_id uuid not null
        references public.stores(id)
        on delete cascade,

    category_id uuid
        references public.categories(id)
        on delete set null,

    name text not null,
    slug text not null unique,
    description text,

    price numeric not null check (price >= 0),
    stock integer not null default 0 check (stock >= 0),

    thumbnail_url text,

    weight numeric,

    status text not null default 'draft',

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    archived_at timestamptz
);

create table public.product_images (
    id uuid primary key default gen_random_uuid(),

    product_id uuid not null
        references public.products(id)
        on delete cascade,

    image_url text not null,

    sort_order integer not null default 0,

    created_at timestamptz not null default now()
);

create index idx_stores_owner_id
on public.stores(owner_id);

create index idx_store_assistants_user_id
on public.store_assistants(user_id);

create index idx_products_store_id
on public.products(store_id);

create index idx_products_category_id
on public.products(category_id);

create index idx_products_status
on public.products(status);

create trigger update_stores_updated_at
before update on public.stores
for each row
execute function public.update_updated_at_column();

create trigger update_products_updated_at
before update on public.products
for each row
execute function public.update_updated_at_column();

alter table public.stores enable row level security;
alter table public.store_assistants enable row level security;
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.product_images enable row level security;