-- Clean up duplicate store assistant rows for existing store_ids, keeping only the latest assigned record
delete from public.store_assistants sa1
using public.store_assistants sa2
where sa1.store_id = sa2.store_id
  and (
      sa1.assigned_at < sa2.assigned_at
      or (sa1.assigned_at = sa2.assigned_at and sa1.id < sa2.id)
  );

-- Drop legacy non-unique/multi-user indices
drop index if exists public.store_assistants_store_user_unique;
alter table public.store_assistants drop constraint if exists store_assistants_store_id_key;

-- Enforce 1 store can only have 1 assistant
alter table public.store_assistants
add constraint store_assistants_store_id_key unique (store_id);

notify pgrst, 'reload schema';
