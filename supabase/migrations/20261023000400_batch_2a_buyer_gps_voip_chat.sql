-- Migration: Batch 2A — Pembeli GPS Pengiriman (#9), In-App VoIP Call Gojek (#10), & In-App Message Gojek (#11)

-- 1. Extend public.orders with GPS coordinates, tracking URL, and in-app driver messages
ALTER TABLE public.orders
ADD COLUMN IF NOT EXISTS driver_latitude DOUBLE PRECISION NULL,
ADD COLUMN IF NOT EXISTS driver_longitude DOUBLE PRECISION NULL,
ADD COLUMN IF NOT EXISTS shipping_latitude DOUBLE PRECISION NULL DEFAULT -6.244179,
ADD COLUMN IF NOT EXISTS shipping_longitude DOUBLE PRECISION NULL DEFAULT 106.783529,
ADD COLUMN IF NOT EXISTS tracking_url TEXT NULL,
ADD COLUMN IF NOT EXISTS driver_messages JSONB NOT NULL DEFAULT '[]'::jsonb;

-- 2. RPC for Buyer & Driver In-App Messaging (#11 Message Gojek / Driver)
CREATE OR REPLACE FUNCTION public.append_order_driver_message(
    p_order_id UUID,
    p_message TEXT,
    p_sender_role TEXT DEFAULT 'buyer'
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

    -- Authorization check: buyer of order, store owner, or authorized staff
    IF v_order.user_id != auth.uid()
       AND COALESCE(v_user.role, '') NOT IN ('admin', 'assistant')
       AND NOT EXISTS (SELECT 1 FROM public.stores s WHERE s.id = v_order.store_id AND s.owner_id = auth.uid())
    THEN
        RAISE EXCEPTION 'Tidak memiliki akses ke percakapan pengiriman pesanan ini';
    END IF;

    v_entry := jsonb_build_object(
        'id', gen_random_uuid()::text,
        'sender_id', auth.uid()::text,
        'sender_name', COALESCE(v_user.full_name, 'Pengguna'),
        'sender_role', COALESCE(p_sender_role, v_user.role, 'buyer'),
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

GRANT EXECUTE ON FUNCTION public.append_order_driver_message(UUID, TEXT, TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';
