create table products (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    price numeric not null check (price >= 0),
    stock integer not null default 0 check (stock >= 0),
    created_at timestamp with time zone default now()
);