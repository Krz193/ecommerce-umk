-- Create RPC function to get cart analytics for a seller's store

create or replace function public.get_seller_cart_insights(p_store_id uuid)
returns json
language plpgsql
security definer -- Needs security definer to bypass RLS on cart_items since sellers can't normally see other users' carts
set search_path = public
as $$
declare
    v_total_items integer := 0;
    v_total_potential_value numeric := 0;
    v_unique_potential_buyers integer := 0;
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

    -- Calculate total items and potential value
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

    -- Construct JSON result
    v_result := json_build_object(
        'total_items_in_carts', v_total_items,
        'total_potential_value', v_total_potential_value,
        'unique_potential_buyers', v_unique_potential_buyers
    );

    return v_result;
end;
$$;
