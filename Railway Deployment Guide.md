# Railway Deployment Guide - Admin Panel

Panduan langkah demi langkah deploy Admin Panel Laravel ke Railway menggunakan **Railway PostgreSQL** (Direkomendasikan) atau **SQLite**.

---

## Arsitektur Database
* **Database Admin (`DB_CONNECTION=pgsql`)**: Menyimpan akun admin, sesi login, audit log, dan kasus refund. Dijalankan pada service **Postgres** bawaan Railway.
* **Database Marketplace (`MARKETPLACE_DB_*`)**: Terhubung langsung ke PostgreSQL Supabase untuk data produk, pesanan, merchant, dan transaksi.

---

## Langkah Setup di Dashboard Railway

### 1. Buat Service PostgreSQL (Database Admin)
1. Di dashboard Railway project Anda, klik **+ Create** / **+ New**.
2. Pilih **Database** > pilih **Add PostgreSQL**.
3. Service **Postgres** dengan `postgres-volume` akan otomatis dibuat dan berjalan.

---

### 2. Buat Service Web (ecommerce-umk) & Hubungkan Repo
1. Klik **+ Create** > pilih **GitHub Repo** > pilih repository `ecommerce-umk`.
2. Klik service `ecommerce-umk` > masuk ke tab **Settings**.
3. Di bagian **Service** > set **Root Directory** ke:
   ```text
   /admin
   ```
4. Klik **Save**.
5. **PENTING (Volume):** Service `ecommerce-umk` **TIDAK MEMERLUKAN VOLUME**. Jika ada volume menempel di `ecommerce-umk`, hapus volume tersebut di tab **Settings** > **Volumes** agar tidak menimpa folder kode aplikasi.

---

### 3. Pilih Builder & Atur Build / Start Command
Masih di tab **Settings**:

1. **Builder**:
   Pilih **Railpack (Default)**.

2. **Build Command**:
   ```bash
   npm run build
   ```

3. **Start Command**:
   ```bash
   php artisan migrate --force && php artisan db:seed --force && php artisan serve --host 0.0.0.0 --port $PORT
   ```

---

### 4. Konfigurasi Environment Variables
Buka tab **Variables** pada service `ecommerce-umk`, klik tombol **RAW Editor**, lalu masukkan nilai berikut:

```env
APP_NAME="Marketplace UMK Admin"
APP_ENV=production
APP_KEY=base64:h5B57MUs2lroIb14JgGn3ruFN0g6/WMj2MrPoydwmAI=
APP_DEBUG=false
APP_URL=https://${{RAILWAY_PUBLIC_DOMAIN}}
PORT=8000

DB_CONNECTION=pgsql
DB_HOST=${{Postgres.PGHOST}}
DB_PORT=${{Postgres.PGPORT}}
DB_DATABASE=${{Postgres.PGDATABASE}}
DB_USERNAME=${{Postgres.PGUSER}}
DB_PASSWORD=${{Postgres.PGPASSWORD}}
SESSION_DRIVER=database
CACHE_STORE=file
QUEUE_CONNECTION=sync

MARKETPLACE_DB_CONNECTION=marketplace
MARKETPLACE_DB_HOST=aws-1-ap-southeast-1.pooler.supabase.com
MARKETPLACE_DB_PORT=5432
MARKETPLACE_DB_DATABASE=postgres
MARKETPLACE_DB_USERNAME=postgres.eiihrwjmvmbqtispwttp
MARKETPLACE_DB_PASSWORD=P2wlFNhBx7wsKPfN
MARKETPLACE_DB_SSLMODE=require

ADMIN_NAME="Marketplace Admin"
ADMIN_EMAIL=admin@ecommerceumk.com
ADMIN_PASSWORD="K9#vX!m8$pL2wZ5Q"
```

---

### 5. Catatan tentang Volume
* **Jika menggunakan PostgreSQL (Direkomendasikan):**
  Anda **TIDAK PERLU** menambahkan volume pada service `ecommerce-umk`. Data database admin otomatis tersimpan di service `Postgres` (`postgres-volume`). Pastikan tidak ada volume yang menempel di `ecommerce-umk`.
* **Jika menggunakan SQLite:**
  Tambahkan volume di `ecommerce-umk` dengan Mount Path `/data` (jangan `/app/database`).

---

### 6. Generate Domain & Verifikasi
1. Masuk tab **Settings** > scroll ke bagian **Networking**.
2. Klik **Generate Domain**.
3. Tunggu deployment berstatus `ACTIVE` (hijau).
4. Buka URL domain publik di browser.
5. Login menggunakan kredensial:
   * **Email:** `admin@ecommerceumk.com`
   * **Password:** `K9#vX!m8$pL2wZ5Q`

---

## Troubleshooting & CLI Command
Jika ingin menjalankan migrasi atau cek route manual via Railway CLI:
```bash
# Jalankan migrasi manual
railway run --service admin php artisan migrate --force

# Jalankan seeder admin manual
railway run --service admin php artisan db:seed --force

# Cek daftar route
railway run --service admin php artisan route:list
```
