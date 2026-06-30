create or replace function public.become_seller()
returns public.users
language plpgsql
security definer
set search_path = public
as $$
declare
    updated_user public.users;
begin
    if auth.uid() is null then
        raise exception 'Authentication required';
    end if;

    update public.users
    set role = 'seller'
    where id = auth.uid()
      and role = 'buyer'
    returning *
    into updated_user;

    if not found then
        raise exception 'Only buyer accounts can become sellers';
    end if;

    return updated_user;
end;
$$;

revoke update on public.users
from authenticated;

grant select
on public.users
to authenticated;

grant update (
    full_name,
    username,
    phone,
    avatar_url
)
on public.users
to authenticated;

revoke execute on function public.is_seller()
from public, anon;

grant execute on function public.is_seller()
to authenticated;

revoke execute on function public.is_admin()
from public, anon;

grant execute on function public.is_admin()
to authenticated;

revoke execute on function public.is_store_owner(uuid)
from public, anon;

grant execute on function public.is_store_owner(uuid)
to authenticated;

revoke execute on function public.become_seller()
from public, anon;

grant execute on function public.become_seller()
to authenticated;

notify pgrst, 'reload schema';
