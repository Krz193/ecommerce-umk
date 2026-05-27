alter table public.users
add column role text
not null default 'buyer';

alter table public.users
add constraint users_role_check
check (
    role in (
        'buyer',
        'seller',
        'admin'
    )
);