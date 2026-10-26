insert into storage.buckets (
    id,
    name,
    public,
    file_size_limit,
    allowed_mime_types
)
values (
    'store-contents',
    'store-contents',
    true,
    10485760,
    array[
        'image/jpeg',
        'image/png',
        'image/webp'
    ]
)
on conflict (id) do update
set
    public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Public can read store content objects"
on storage.objects;

drop policy if exists "Assistants and store owners can upload store content objects"
on storage.objects;

drop policy if exists "Assistants and store owners can update store content objects"
on storage.objects;

drop policy if exists "Assistants and store owners can delete store content objects"
on storage.objects;

create policy "Public can read store content objects"
on storage.objects
for select
using (
    bucket_id = 'store-contents'
);

create policy "Assistants and store owners can upload store content objects"
on storage.objects
for insert
to authenticated
with check (
    bucket_id = 'store-contents'
);

create policy "Assistants and store owners can update store content objects"
on storage.objects
for update
to authenticated
using (
    bucket_id = 'store-contents'
)
with check (
    bucket_id = 'store-contents'
);

create policy "Assistants and store owners can delete store content objects"
on storage.objects
for delete
to authenticated
using (
    bucket_id = 'store-contents'
);

notify pgrst, 'reload schema';
