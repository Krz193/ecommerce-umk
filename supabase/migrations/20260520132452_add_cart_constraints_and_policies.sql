/*
|--------------------------------------------------------------------------
| Cart Constraints And Policies
|--------------------------------------------------------------------------
|
| Enforce single active cart per
| user/store pair and allow users
| to create their own carts.
|
*/

create unique index if not exists
carts_user_store_unique
on carts (
    user_id,
    store_id
);

/*
|--------------------------------------------------------------------------
| Users Can Create Own Carts
|--------------------------------------------------------------------------
*/

create policy "Users can create own carts"
on carts
for insert
to authenticated
with check (
    auth.uid() = user_id
);