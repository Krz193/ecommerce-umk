create table if not exists public.stock_movements (
    id uuid primary key default gen_random_uuid(),
    product_id uuid not null
        references public.products(id)
        on delete cascade,
    store_id uuid not null
        references public.stores(id)
        on delete cascade,
    movement_type text not null
        check (movement_type in ('stock_in', 'adjustment')),
    quantity integer not null
        check (quantity > 0),
    previous_stock integer not null
        check (previous_stock >= 0),
    new_stock integer not null
        check (new_stock >= 0),
    note text,
    created_by uuid not null
        references public.users(id)
        on delete restrict,
    created_at timestamptz not null default now()
);

create index if not exists idx_stock_movements_product_id
on public.stock_movements(product_id);

create index if not exists idx_stock_movements_store_id
on public.stock_movements(store_id);

create index if not exists idx_stock_movements_created_at
on public.stock_movements(created_at);

alter table public.stock_movements enable row level security;

grant select
on public.stock_movements
to authenticated;

drop policy if exists "Store owners can view own stock movements"
on public.stock_movements;

create policy "Store owners can view own stock movements"
on public.stock_movements
for select
to authenticated
using (
    public.is_store_owner(store_id)
);

create or replace function public.record_stock_in(
    product_uuid uuid,
    quantity_in integer,
    movement_note text default null
)
returns public.products
language plpgsql
security definer
set search_path = public
as $$
declare
    target_product public.products;
    updated_product public.products;
begin
    if quantity_in is null or quantity_in <= 0 then
        raise exception 'Stock-in quantity must be greater than zero';
    end if;

    select products.*
    into target_product
    from public.products
    where products.id = product_uuid
      and public.is_store_owner(products.store_id)
    for update;

    if target_product.id is null then
        raise exception 'Product not found or not owned by current seller';
    end if;

    update public.products
    set stock = target_product.stock + quantity_in
    where id = target_product.id
    returning *
    into updated_product;

    insert into public.stock_movements (
        product_id,
        store_id,
        movement_type,
        quantity,
        previous_stock,
        new_stock,
        note,
        created_by
    )
    values (
        target_product.id,
        target_product.store_id,
        'stock_in',
        quantity_in,
        target_product.stock,
        updated_product.stock,
        nullif(trim(movement_note), ''),
        auth.uid()
    );

    return updated_product;
end;
$$;

grant execute on function public.record_stock_in(uuid, integer, text)
to authenticated;
