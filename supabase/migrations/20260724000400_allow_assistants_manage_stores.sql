-- Helper function to break RLS policy recursion between stores and store_assistants
create or replace function public.is_store_assistant_user(target_store_id uuid, target_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1
        from public.store_assistants
        where store_id = target_store_id
          and user_id = target_user_id
    );
$$;

revoke execute on function public.is_store_assistant_user(uuid, uuid) from public, anon;
grant execute on function public.is_store_assistant_user(uuid, uuid) to authenticated;

-- Allow store assistants to view and update store profiles they assist without policy recursion
drop policy if exists "Store assistants can view store profile" on public.stores;
create policy "Store assistants can view store profile"
on public.stores for select to authenticated
using (
    public.is_store_assistant_user(id, auth.uid())
);

drop policy if exists "Store assistants can update store profile" on public.stores;
create policy "Store assistants can update store profile"
on public.stores for update to authenticated
using (
    public.is_store_assistant_user(id, auth.uid())
)
with check (
    public.is_store_assistant_user(id, auth.uid())
);

notify pgrst, 'reload schema';
