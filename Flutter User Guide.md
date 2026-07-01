# Flutter User Guide

## Marketplace UMK Mobile App

---

# Panduan Singkat

Aplikasi ini digunakan untuk dua jenis pengguna:

* **Pembeli**: mencari produk, memasukkan barang ke keranjang, checkout, membayar, dan memantau pesanan.
* **Seller/UMK**: membuat toko, mengelola produk, mengatur stok, dan memproses pesanan.

Panduan ini ditulis untuk pengguna awam. Ikuti bagian yang sesuai dengan peran Anda.

---

# Alur Pembeli

## 1. Membuat Akun atau Login

Gunakan alur ini jika Anda ingin mulai belanja.

Langkah:

1. Buka aplikasi.
2. Jika belum punya akun, pilih **Register**.
3. Isi data akun yang diminta.
4. Jika sudah punya akun, pilih **Login**.
5. Setelah berhasil masuk, aplikasi akan membuka halaman utama atau **Home**.

Catatan:

* Akun baru otomatis menjadi akun pembeli.
* Simpan email dan password yang digunakan untuk login berikutnya.

---

## 2. Mencari Produk

Gunakan alur ini jika Anda ingin menemukan barang yang ingin dibeli.

Langkah:

1. Buka halaman **Home**.
2. Lihat daftar produk yang tersedia.
3. Ketik nama produk di kolom pencarian jika ingin mencari produk tertentu.
4. Pilih kategori jika ingin melihat jenis produk tertentu.
5. Gunakan filter harga atau stok jika diperlukan.
6. Pilih produk untuk membuka detailnya.

Penjelasan:

* Produk yang tampil adalah produk yang sudah dipublikasikan oleh seller.
* Jika produk tidak muncul, kemungkinan produk masih draft, stok habis, toko tidak aktif, atau produk sedang diarsipkan admin.

---

## 3. Melihat Detail Produk

Gunakan alur ini sebelum membeli produk.

Informasi yang bisa dilihat:

* foto utama produk
* foto tambahan produk
* nama produk
* harga
* deskripsi
* stok
* kategori
* informasi toko

Langkah:

1. Pilih produk dari Home.
2. Baca deskripsi produk.
3. Cek foto dan stok produk.
4. Jika produk sesuai, tambahkan ke keranjang.

Catatan:

* Jika stok habis, produk tidak dapat dibeli.
* Foto utama produk dipilih dari foto yang diupload seller.

---

## 4. Memasukkan Produk ke Keranjang

Gunakan alur ini untuk menyimpan produk sebelum checkout.

Langkah:

1. Buka detail produk.
2. Tekan tombol **Add to Cart**.
3. Buka keranjang dari ikon cart.
4. Cek produk yang sudah masuk.
5. Ubah jumlah barang jika perlu.
6. Hapus produk jika tidak jadi dibeli.

Catatan:

* Satu checkout hanya untuk produk dari satu toko.
* Jika ingin membeli dari toko berbeda, lakukan checkout terpisah.

---

## 5. Mengatur Alamat Pengiriman

Gunakan alur ini sebelum melakukan checkout.

Langkah:

1. Buka menu alamat dari Account atau halaman checkout.
2. Tambahkan alamat baru jika belum ada.
3. Isi nama penerima, nomor telepon, kota, kode pos, dan alamat lengkap.
4. Simpan alamat.
5. Pilih alamat tersebut saat checkout.

Catatan:

* Pastikan alamat lengkap dan nomor telepon benar.
* Alamat yang dipilih akan disimpan di data pesanan.

---

## 6. Checkout

Gunakan alur ini saat barang sudah siap dibeli.

Langkah:

1. Buka keranjang.
2. Cek produk dan jumlah barang.
3. Lanjut ke checkout.
4. Pilih alamat pengiriman.
5. Baca ringkasan pesanan.
6. Konfirmasi checkout.
7. Aplikasi membuat pesanan dan membuka halaman pembayaran.

Sistem akan mengecek:

* Anda sudah login
* keranjang tidak kosong
* alamat sudah dipilih
* produk masih tersedia
* stok cukup
* semua produk berasal dari satu toko
* total harga dihitung oleh server

---

## 7. Membayar Pesanan

Gunakan alur ini setelah checkout berhasil.

Langkah:

1. Ikuti instruksi pada halaman pembayaran.
2. Pilih metode pembayaran yang tersedia.
3. Selesaikan pembayaran.
4. Tunggu status pembayaran berubah.
5. Jika pembayaran berhasil, pesanan masuk ke proses seller.

Catatan:

* Pembayaran menggunakan Midtrans.
* Status pembayaran dikonfirmasi oleh sistem otomatis.
* Jika halaman pembayaran tertutup, buka pesanan dari riwayat order.

---

## 8. Melihat Riwayat Pesanan

Gunakan alur ini untuk memantau pembelian.

Langkah:

1. Buka halaman **Orders**.
2. Pilih pesanan.
3. Lihat status pesanan dan status pembayaran.
4. Jika seller sudah mengirim barang, cek ekspedisi dan nomor resi.

Informasi yang tersedia:

* nomor pesanan
* daftar produk
* total pembayaran
* alamat pengiriman
* status pembayaran
* status pesanan
* ekspedisi dan nomor resi jika sudah tersedia

---

## 9. Konfirmasi Barang Diterima

Gunakan alur ini hanya jika barang sudah sampai.

Langkah:

1. Buka detail pesanan.
2. Pastikan barang benar-benar diterima.
3. Tekan **Confirm Received**.
4. Status pesanan menjadi selesai.

Catatan:

* Jangan konfirmasi jika barang belum diterima.
* Setelah dikonfirmasi, pesanan dianggap selesai.

---

# Alur Seller / UMK

## 1. Membuat Toko

Gunakan alur ini jika Anda adalah UMK yang ingin berjualan.

Langkah:

1. Login ke aplikasi.
2. Buka **Account**.
3. Pilih menu untuk menjadi seller atau membuat toko.
4. Isi data toko.
5. Simpan data toko.

Catatan:

* Akun pembeli dapat berubah menjadi seller.
* Toko dapat dikelola dan dimoderasi oleh admin.

---

## 2. Melihat Dashboard Seller

Gunakan dashboard untuk melihat kondisi toko.

Dashboard menampilkan:

* informasi toko
* jumlah produk
* produk published dan draft
* order yang perlu diproses
* peringatan stok rendah

Jika ada peringatan stok rendah, buka produk tersebut dan perbarui stoknya.

---

## 3. Membuat Produk

Gunakan alur ini untuk menambahkan produk baru.

Langkah:

1. Buka menu **Products**.
2. Pilih create product.
3. Isi nama produk.
4. Isi deskripsi.
5. Isi harga.
6. Isi stok.
7. Pilih kategori.
8. Simpan produk.

Catatan:

* Produk baru dapat disimpan sebagai draft.
* Produk draft belum terlihat oleh pembeli.

---

## 4. Upload Foto dan Pilih Thumbnail

Gunakan alur ini agar produk mudah dikenali pembeli.

Langkah:

1. Buka halaman edit produk.
2. Upload satu atau beberapa foto produk.
3. Pilih salah satu foto sebagai thumbnail.
4. Simpan perubahan.

Penjelasan:

* Thumbnail adalah foto utama yang tampil di daftar produk.
* Thumbnail harus berasal dari foto produk yang diupload.
* Cara ini membantu mencegah foto produk yang tidak sesuai.

---

## 5. Publish Produk

Gunakan alur ini agar produk tampil untuk pembeli.

Sebelum publish, pastikan:

* nama produk benar
* harga benar
* stok tersedia
* kategori sudah dipilih
* thumbnail sudah dipilih
* deskripsi cukup jelas

Langkah:

1. Buka edit produk.
2. Cek ulang data produk.
3. Tekan publish.
4. Produk akan tampil di Home pembeli.

Jika produk belum tampil:

* cek apakah produk sudah `published`
* cek apakah toko aktif
* cek apakah produk sedang diarsipkan admin

---

## 6. Mengatur Stok

Gunakan alur ini saat jumlah barang berubah.

Langkah:

1. Buka menu **Products**.
2. Pilih produk.
3. Ubah stok dari halaman edit atau quick stock adjustment.
4. Simpan perubahan.

Catatan:

* Stok tidak boleh kurang dari nol.
* Produk dengan stok rendah akan muncul di dashboard seller.

---

## 7. Memproses Pesanan

Gunakan alur ini saat ada pesanan yang sudah dibayar.

Langkah:

1. Buka menu **Orders**.
2. Pilih pesanan yang perlu diproses.
3. Buka detail pesanan.
4. Siapkan barang.
5. Isi shipping provider atau ekspedisi.
6. Isi tracking number atau nomor resi.
7. Simpan pengiriman.

Catatan:

* Seller menandai pesanan sebagai dikirim.
* Pembeli yang mengonfirmasi barang diterima.

---

# Pengaruh Admin ke Aplikasi Flutter

Admin web dapat mempengaruhi data yang terlihat di aplikasi Flutter.

Contoh:

* Jika admin suspend toko, toko dianggap tidak aktif secara operasional.
* Jika admin archive produk, produk hilang dari Home pembeli.
* Jika admin restore produk, produk kembali published dan muncul lagi di Home.
* Jika ada refund atau pembatalan, admin dapat mencatat case manual di admin panel.

---

# Fitur yang Belum Tersedia

Fitur berikut belum tersedia pada MVP:

* review/comment/star
* wishlist
* notifikasi penuh
* refund request langsung dari pembeli
* refund otomatis ke Midtrans
* seller balance/payout ledger
* integrasi shipping API
* aplikasi ekspedisi
* aplikasi ojek
* map/GPS tracking
* chat/call pembeli dan ojek
* donasi UMK
* training/asistensi
* role Asisten UMK

---

# Checklist Penggunaan

## Pembeli

* bisa register/login
* bisa mencari produk
* bisa filter kategori/harga/stok
* bisa membuka detail produk
* bisa menambahkan produk ke cart
* bisa membuat atau memilih alamat
* bisa checkout
* bisa membuka halaman pembayaran
* bisa melihat riwayat pesanan
* bisa konfirmasi barang diterima

## Seller

* bisa membuat toko
* bisa membuka dashboard seller
* bisa membuat produk
* bisa upload foto produk
* bisa memilih thumbnail
* bisa publish produk
* bisa mengubah stok
* bisa memproses order
* bisa input ekspedisi dan nomor resi

## Admin Interaction

* produk yang diarchive admin hilang dari Home
* produk yang direstore admin muncul lagi di Home
* store yang disuspend/unsuspend admin berubah status
* audit log admin mencatat tindakan penting
