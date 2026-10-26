-- Update RPC function to get cart analytics + product breakdown for a seller's store

create or replace function public.get_seller_cart_insights(p_store_id uuid)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
    v_total_items integer := 0;
    v_total_potential_value numeric := 0;
    v_unique_potential_buyers integer := 0;
    v_product_breakdown json := '[]'::json;
    v_result json;
begin
    -- Ensure the user requesting is the store owner or an assistant for the store
    if not exists (
        select 1 from public.stores
        where id = p_store_id
        and (owner_id = auth.uid() or exists (
            select 1 from public.store_assistants
            where store_id = p_store_id and user_id = auth.uid()
        ))
    ) then
        raise exception 'Unauthorized to view cart insights for this store';
    end if;

    -- Calculate total items, potential value, and unique buyers
    select 
        coalesce(sum(ci.quantity), 0),
        coalesce(sum(ci.quantity * p.price), 0),
        count(distinct c.user_id)
    into 
        v_total_items, 
        v_total_potential_value,
        v_unique_potential_buyers
    from 
        public.cart_items ci
    join 
        public.carts c on ci.cart_id = c.id
    join 
        public.products p on ci.product_id = p.id
    where 
        p.store_id = p_store_id;

    -- Calculate product breakdown
    select coalesce(json_agg(
        json_build_object(
            'product_id', sub.product_id,
            'product_name', sub.name,
            'product_image', sub.image_url,
            'price', sub.price,
            'stock', sub.stock,
            'total_quantity', sub.total_qty,
            'total_potential_value', sub.total_value,
            'unique_buyers', sub.buyer_count
        ) order by sub.total_qty desc
    ), '[]'::json)
    into v_product_breakdown
    from (
        select 
            p.id as product_id,
            p.name,
            coalesce(p.thumbnail_url, (
                select pi.image_url 
                from public.product_images pi 
                where pi.product_id = p.id 
                order by pi.sort_order asc 
                limit 1
            )) as image_url,
            p.price,
            p.stock,
            sum(ci.quantity) as total_qty,
            sum(ci.quantity * p.price) as total_value,
            count(distinct c.user_id) as buyer_count
        from public.cart_items ci
        join public.carts c on ci.cart_id = c.id
        join public.products p on ci.product_id = p.id
        where p.store_id = p_store_id
        group by p.id, p.name, p.thumbnail_url, p.price, p.stock
    ) sub;

    -- Construct JSON result
    v_result := json_build_object(
        'total_items_in_carts', v_total_items,
        'total_potential_value', v_total_potential_value,
        'unique_potential_buyers', v_unique_potential_buyers,
        'product_breakdown', v_product_breakdown
    );

    return v_result;
end;
$$;
