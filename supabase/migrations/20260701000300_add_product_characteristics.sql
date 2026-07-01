alter table public.products
add column if not exists product_type text,
add column if not exists size text,
add column if not exists color text;
