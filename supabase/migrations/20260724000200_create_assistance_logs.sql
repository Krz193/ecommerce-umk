-- Create assistance_logs table for automatic logging of UMK assistance actions
create table if not exists public.assistance_logs (
    id uuid primary key default gen_random_uuid(),
    assistant_id uuid not null references public.users(id) on delete cascade,
    store_id uuid not null references public.stores(id) on delete cascade,
    action_type text not null check (
        action_type in (
            'create_product',
            'update_product',
            'update_stock',
            'ship_order',
            'create_content',
            'update_content',
            'update_profile',
            'other'
        )
    ),
    title text not null,
    description text,
    metadata jsonb default '{}'::jsonb,
    created_at timestamptz not null default now()
);

create index if not exists idx_assistance_logs_assistant_id on public.assistance_logs(assistant_id);
create index if not exists idx_assistance_logs_store_id on public.assistance_logs(store_id);
create index if not exists idx_assistance_logs_created_at on public.assistance_logs(created_at desc);

grant select, insert on public.assistance_logs to authenticated;

alter table public.assistance_logs enable row level security;

-- Policy: Assistant can view logs for actions they performed
create policy "Assistants can view own assistance logs"
on public.assistance_logs for select to authenticated
using (
    auth.uid() = assistant_id
    or exists (
        select 1 from public.store_assistants sa
        where sa.store_id = assistance_logs.store_id
          and sa.user_id = auth.uid()
    )
    or exists (
        select 1 from public.stores s
        where s.id = assistance_logs.store_id
          and s.owner_id = auth.uid()
    )
);

-- Policy: Assistants can insert assistance logs
create policy "Assistants can insert assistance logs"
on public.assistance_logs for insert to authenticated
with check (
    auth.uid() = assistant_id
);

-- Helper RPC function to record assistance log activity
create or replace function public.log_assistance_activity(
    p_store_id uuid,
    p_action_type text,
    p_title text,
    p_description text default null,
    p_metadata jsonb default '{}'::jsonb
)
returns public.assistance_logs
language plpgsql
security definer
set search_path = public
as $$
declare
    v_new_log public.assistance_logs;
begin
    if auth.uid() is null then
        raise exception 'Authentication required';
    end if;

    insert into public.assistance_logs (
        assistant_id,
        store_id,
        action_type,
        title,
        description,
        metadata
    )
    values (
        auth.uid(),
        p_store_id,
        p_action_type,
        p_title,
        p_description,
        p_metadata
    )
    returning * into v_new_log;

    return v_new_log;
end;
$$;

revoke execute on function public.log_assistance_activity(uuid, text, text, text, jsonb) from public, anon;
grant execute on function public.log_assistance_activity(uuid, text, text, text, jsonb) to authenticated;

notify pgrst, 'reload schema';
