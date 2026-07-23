insert into public.categories (
    name,
    slug,
    is_active
)
values
    ('Makanan & Minuman', 'makanan-minuman', true),
    ('Fashion', 'fashion', true),
    ('Kerajinan', 'kerajinan', true),
    ('Kesehatan & Kecantikan', 'kesehatan-kecantikan', true),
    ('Rumah Tangga', 'rumah-tangga', true),
    ('Digital & Jasa', 'digital-jasa', true)
on conflict (slug) do update
set
    name = excluded.name,
    is_active = excluded.is_active;
