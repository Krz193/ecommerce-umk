-- RPC function to securely update shipping details on orders without RLS blockage
CREATE OR REPLACE FUNCTION public.set_order_shipping_details(
    p_order_id UUID,
    p_courier_name TEXT,
    p_courier_code TEXT,
    p_courier_service_code TEXT,
    p_courier_service_type TEXT,
    p_shipping_cost NUMERIC
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_updated_order JSONB;
BEGIN
    UPDATE public.orders
    SET 
        courier_name = p_courier_name,
        courier_code = p_courier_code,
        courier_service_code = p_courier_service_code,
        courier_service_type = p_courier_service_type,
        shipping_cost = p_shipping_cost,
        updated_at = NOW()
    WHERE id = p_order_id
    RETURNING to_jsonb(orders.*) INTO v_updated_order;

    RETURN v_updated_order;
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_order_shipping_details TO authenticated, anon, service_role;
