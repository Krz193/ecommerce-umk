# Admin Panel Guide

## Marketplace UMK Laravel Admin

---

# Overview

Admin panel digunakan untuk operasional internal:

* store moderation
* product moderation
* marketplace user lookup
* order/payment lookup
* manual refund/cancellation case tracking
* audit logs
* MVP reports

Admin panel berjalan di Laravel dan membaca marketplace data dari Supabase Postgres melalui connection `marketplace`.

---

# Login Admin

1. Jalankan admin app.
2. Buka `http://127.0.0.1:8000`.
3. Login dengan email/password admin dari `admin/.env`.
4. User harus memiliki `is_admin = true`.

Catatan:

* Admin auth memakai tabel Laravel admin lokal.
* Marketplace buyer/seller tetap berada di Supabase `public.users`.
* Admin role/permission matrix belum diperlukan untuk MVP single-admin/operator.

---

# Dashboard

Dashboard menampilkan:

* pending stores
* active stores
* published products
* processing orders
* pending payments
* paid payments
* recent stores
* recent orders

Gunakan dashboard untuk orientasi cepat sebelum masuk ke detail operasional.

---

# Store Moderation

Menu: `/stores`

Admin dapat:

* melihat daftar store
* filter store berdasarkan status
* search store, slug, atau owner
* membuka detail store
* approve store
* suspend store
* unsuspend store

Behavior:

* `Approve` memakai confirm modal tanpa reason.
* `Unsuspend` memakai confirm modal tanpa reason.
* `Suspend` wajib mengisi moderation reason.
* Semua action dicatat di audit logs.

Efek database:

* approve/unsuspend: `stores.status = active`, `suspended_at = null`
* suspend: `stores.status = suspended`, `suspended_at = now()`

---

# Product Moderation

Menu: `/products`

Admin dapat:

* melihat daftar produk
* filter berdasarkan status
* search produk, store, atau kategori
* membuka detail produk
* melihat thumbnail dan gallery
* archive product
* restore product

Behavior:

* `Archive` wajib reason.
* `Restore` wajib reason.
* Archive mengubah produk menjadi draft dan mengisi `archived_at`.
* Restore menghapus `archived_at` dan mengubah produk kembali ke `published`.
* Restored product akan muncul lagi di Flutter Home.
* Semua action dicatat di audit logs.

---

# Marketplace User Lookup

Menu: `/users`

Admin dapat:

* melihat user marketplace
* filter berdasarkan role
* search nama, username, atau phone
* membuka detail user
* melihat store terkait
* melihat recent orders

Catatan:

* User lookup saat ini read-only.
* Suspend/activate user belum dibuat karena schema status user marketplace belum difinalkan.

---

# Order dan Payment Lookup

Menu: `/orders`

Admin dapat:

* melihat daftar order
* filter order status
* filter payment status
* search order, buyer, atau store
* membuka detail order
* melihat buyer, store, items, shipment, payment provider, dan provider transaction ID
* membuat refund case dari order detail

Catatan:

* Payment mutation tetap read-only.
* Settlement tetap dikendalikan Midtrans webhook.
* Admin tidak mengubah status payment langsung dari panel ini.

---

# Refund Case Tracking

Menu: `/refund-cases`

Admin dapat:

* melihat refund/cancellation cases
* membuat case manual
* update status case
* membuka detail case
* melihat order summary
* melihat payment snapshot
* melihat item list
* melihat timeline audit log

Status case:

* `open`
* `reviewing`
* `resolved`
* `rejected`

Catatan:

* Case tracking tidak otomatis melakukan refund Midtrans.
* Fitur ini adalah operational tracking untuk admin.
* Setiap update case wajib reason dan masuk audit log.

---

# Audit Logs

Menu: `/audit-logs`

Audit logs menampilkan:

* time
* admin
* action
* target type
* target ID
* reason

Action yang dicatat:

* `store.approve`
* `store.unsuspend`
* `store.suspend`
* `product.archive`
* `product.restore`
* `refund_case.create`
* `refund_case.update`

---

# Reports

Menu: `/reports`

Reports MVP menampilkan:

* paid revenue
* application fee
* paid orders
* pending payments
* UMK financial summary
* product count per store
* published product count per store
* order count per store
* low stock report

Catatan:

* Ini adalah MVP report, bukan analytics/reporting final.
* Export file belum tersedia.

---

# Local Commands

Run migration admin lokal:

```powershell
cd C:\projects\flutter\ecommerce-umk\admin
php artisan migrate
```

Run admin dev server:

```powershell
composer run dev
```

Type check:

```powershell
npm run types:check
```

Route check:

```powershell
php artisan route:list
```

---

# QA Checklist

## Admin Auth

* admin can login
* non-admin cannot access dashboard
* logout works

## Store Moderation

* approve pending store
* suspend active store with reason
* unsuspend suspended store
* audit log is created

## Product Moderation

* archive product with reason
* product disappears from Flutter Home
* restore product with reason
* product appears again in Flutter Home
* audit log is created

## Refund Case

* create case from order detail
* update case status
* open case detail
* timeline shows audit entries

## Reports

* reports page opens without query error
* finance summary matches rough order data
* low stock report lists stock `<= 5`
