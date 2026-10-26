alter table public.store_contents 
add column if not exists product_id uuid references public.products(id) on delete set null;

notify pgrst, 'reload schema';
