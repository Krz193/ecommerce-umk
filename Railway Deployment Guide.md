# Railway Deployment Guide - Admin Panel (Pilihan 1: SQLite)

Panduan langkah demi langkah deploy Admin Panel Laravel ke akun Railway baru menggunakan **SQLite** (tanpa perlu service database tambahan).

---

## Arsitektur Database
* **Database Lokal Admin (`DB_CONNECTION=sqlite`)**: Menyimpan akun admin, sesi login, dan audit log. Dijalankan langsung di container app (hemat resource akun trial).
* **Database Marketplace (`MARKETPLACE_DB_*`)**: Terhubung langsung ke PostgreSQL Supabase untuk data produk, pesanan, merchant, dan transaksi.

---

## Langkah Setup di Dashboard Railway

### 1. Buat Project & Hubungkan Repo
1. Login ke akun [Railway](https://railway.com/).
2. Di dashboard, klik **+ New Project**.
3. Pilih **Deploy from GitHub repo**.
4. Pilih repository `ecommerce-umk`.

---

### 2. Atur Root Directory
Source code admin berada di subfolder `admin/`:
1. Klik service yang baru dibuat > masuk ke tab **Settings**.
2. Scroll ke bagian **Service** > cari **Root Directory**.
3. Masukkan:
   ```text
   /admin
   ```
4. Klik **Save**.

---

### 3. Atur Build & Start Command
Masih di tab **Settings**, scroll ke bagian **Build** dan **Deploy**:

1. **Build Command**:
   ```bash
   composer install --no-dev --optimize-autoloader && npm ci && npm run build
   ```
2. **Start Command**:
   ```bash
   php artisan migrate --force && php artisan db:seed --force && php artisan serve --host 0.0.0.0 --port $PORT
   ```
   > **Catatan:** Perintah ini otomatis menjalankan migrasi tabel admin dan membuat akun admin utama (`db:seed`) setiap kali container dinyalakan.

---

### 4. Konfigurasi Environment Variables
Buka tab **Variables** pada service admin, klik tombol **RAW Editor** (atau input manual satu per satu), lalu masukkan nilai berikut:

```env
APP_NAME="Marketplace UMK Admin"
APP_ENV=production
APP_KEY=base64:h5B57MUs2lroIb14JgGn3ruFN0g6/WMj2MrPoydwmAI=
APP_DEBUG=false
APP_URL=https://${{RAILWAY_PUBLIC_DOMAIN}}
PORT=8000

DB_CONNECTION=sqlite
DB_DATABASE=/app/database/database.sqlite
SESSION_DRIVER=database

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

### 5. (Opsional) Tambah Persistent Volume untuk SQLite
Agar file database SQLite tidak terhapus saat redeploy atau restart container:
1. Masuk ke tab **Settings** > scroll ke bagian **Volumes**.
2. Klik **Add Volume**.
3. Masukkan **Mount Path**:
   ```text
   /app/database
   ```
4. Simpan volume.

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
