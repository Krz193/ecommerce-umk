alter table public.store_assistants
drop constraint if exists store_assistants_store_id_key;

create unique index store_assistants_store_user_unique
on public.store_assistants (
    store_id,
    user_id
);