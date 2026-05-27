create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin

    insert into public.users (
        id,
        full_name,
        username,
        role
    )
    values (
        new.id,

        coalesce(
            new.raw_user_meta_data->>'full_name',
            'New User'
        ),

        coalesce(
            new.raw_user_meta_data->>'username',
            split_part(new.email, '@', 1)
        ),

        'buyer'
    );

    insert into public.addresses (
        user_id,
        recipient_name,
        recipient_phone,
        city,
        postal_code,
        full_address,
        is_default
    )
    values (
        new.id,

        coalesce(
            new.raw_user_meta_data->>'full_name',
            'New User'
        ),

        '08123456789',

        'Denpasar',

        '80000',

        'Default development address',

        true
    );

    return new;
end;
$$;