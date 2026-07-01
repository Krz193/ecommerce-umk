create or replace function public.record_stock_adjustment(
    product_uuid uuid,
    new_stock_quantity integer,
    movement_note text
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
    if new_stock_quantity is null or new_stock_quantity < 0 then
        raise exception 'New stock quantity cannot be below zero';
    end if;

    if movement_note is null or trim(movement_note) = '' then
        raise exception 'Adjustment reason is required';
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

    if target_product.stock = new_stock_quantity then
        raise exception 'New stock quantity must be different from current stock';
    end if;

    update public.products
    set stock = new_stock_quantity
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
        'adjustment',
        abs(new_stock_quantity - target_product.stock),
        target_product.stock,
        updated_product.stock,
        trim(movement_note),
        auth.uid()
    );

    return updated_product;
end;
$$;

grant execute on function public.record_stock_adjustment(uuid, integer, text)
to authenticated;
