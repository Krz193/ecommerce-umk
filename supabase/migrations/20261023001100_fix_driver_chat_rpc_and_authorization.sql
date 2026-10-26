-- Migration: Fix driver chat RPC authorization and accept optional sender name
-- Allows buyer, driver, or logistics partner to exchange messages in driver_messages

DROP FUNCTION IF EXISTS public.append_order_driver_message(UUID, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.append_order_driver_message(UUID, TEXT, TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.append_order_driver_message(
    p_order_id UUID,
    p_message TEXT,
    p_sender_role TEXT DEFAULT 'buyer',
    p_sender_name TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_order public.orders;
    v_user public.users;
    v_entry JSONB;
    v_updated JSONB;
    v_sender_name TEXT;
    v_role TEXT;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;

    IF COALESCE(TRIM(p_message), '') = '' THEN
        RAISE EXCEPTION 'Pesan tidak boleh kosong';
    END IF;

    SELECT * INTO v_user FROM public.users WHERE id = auth.uid();
    SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pesanan tidak ditemukan';
    END IF;

    -- Authorization check:
    -- 1. Buyer of order (v_order.user_id = auth.uid())
    -- 2. Claimed driver of order (v_order.driver_id = auth.uid())
    -- 3. Driver/partner with logistics role ('ojek', 'ekspedisi')
    -- 4. Authorized staff / admin / assistant
    -- 5. Store owner
    IF v_order.user_id != auth.uid()
       AND COALESCE(v_order.driver_id, '00000000-0000-0000-0000-000000000000'::uuid) != auth.uid()
       AND COALESCE(v_user.role, '') NOT IN ('admin', 'assistant', 'ojek', 'ekspedisi')
       AND NOT EXISTS (SELECT 1 FROM public.stores s WHERE s.id = v_order.store_id AND s.owner_id = auth.uid())
    THEN
        RAISE EXCEPTION 'Tidak memiliki akses ke percakapan pengiriman pesanan ini';
    END IF;

    v_role := COALESCE(NULLIF(TRIM(p_sender_role), ''), v_user.role, 'buyer');
    v_sender_name := COALESCE(
        NULLIF(TRIM(p_sender_name), ''),
        NULLIF(TRIM(v_user.full_name), ''),
        CASE 
            WHEN v_role IN ('ojek', 'driver', 'ekspedisi') THEN 'Kurir / Ojek'
            ELSE 'Pengguna'
        END
    );

    v_entry := jsonb_build_object(
        'id', gen_random_uuid()::text,
        'sender_id', auth.uid()::text,
        'sender_name', v_sender_name,
        'sender_role', v_role,
        'message', TRIM(p_message),
        'sent_at', NOW()
    );

    v_updated := COALESCE(v_order.driver_messages, '[]'::jsonb) || jsonb_build_array(v_entry);

    UPDATE public.orders
    SET driver_messages = v_updated,
        updated_at = NOW()
    WHERE id = p_order_id;

    RETURN v_updated;
END;
$$;

GRANT EXECUTE ON FUNCTION public.append_order_driver_message(UUID, TEXT, TEXT, TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';
