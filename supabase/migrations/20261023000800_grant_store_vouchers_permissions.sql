-- Grant CRUD permissions on store_vouchers to authenticated users (governed by RLS)
GRANT ALL ON TABLE public.store_vouchers TO authenticated, service_role;
GRANT SELECT ON TABLE public.store_vouchers TO anon;
