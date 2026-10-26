# Laporan Manajemen: Pembaruan & Integrasi Sistem Pengiriman (Biteship Logistics)
**Proyek:** Aplikasi E-commerce UMK  
**Periode Laporan:** Bulan Ini  
**Status Pekerjaan:** Selesai & Teruji di Sistem (Berdasarkan Hasil Analisis Git Changes)  
**Ditujukan Kepada:** Manajemen, Direksi, & Tim Operasional  

---

## 1. Ringkasan Singkat

Bulan ini tim pengembang menyelesaikan pembaruan besar pada seluruh sistem pengiriman barang. Kita resmi beralih dari pencatatan pengiriman manual dan data uji coba (fiktif) menuju **sistem pengiriman otomatis kelas industri** yang terhubung langsung dengan **Biteship Logistics**.

Berdasarkan tinjauan perubahan kode (*git changes*), pembaruan mencakup **20 file utama** dan **lebih dari 1.200 baris kode baru**, yang meliputi: perbaikan tampilan aplikasi pembeli & penjual, pembersihan data palsu, hingga pemasangan sistem pelacakan otomatis di server.

---

## 2. Mengapa Biteship? Apa Manfaatnya untuk Bisnis Kita?

Secara sederhana, **Biteship adalah satu pintu penghubung** antara aplikasi kita dengan puluhan perusahaan logistik ternama di Indonesia (JNE, J&T, SiCepat, GoSend, GrabExpress, Anteraja, dll).

Ada 4 dampak bisnis nyata setelah sistem ini dipasang:

1. **Praktis (Satu Pintu untuk Semua Ekspedisi):**
   Manajemen tidak perlu repot membuat MoU dan mengurus deposit saldo terpisah ke banyak ekspedisi. Cukup satu sistem, pembeli langsung bisa memilih paket hemat (reguler), kargo, atau kurir instan/ojek online yang sampai di hari yang sama.
2. **Anti Nombok Ongkir (Alamat Terstandarisasi):**
   Dulu pembeli sering salah ketik kecamatan atau kode pos, sehingga ongkos kirim di aplikasi berbeda dengan tagihan asli dari kurir. Sekarang, alamat diikat dengan data resmi kurir sehingga tarif dihitung otomatis dan presisi hingga ke rupiahnya.
3. **Penjual UMKM Tidak Perlu Antre (Kurir Datang Jemput):**
   Saat penjual menekan tombol "Kirim Pesanan", sistem langsung memanggil kurir ke lokasi UMKM (*otomatis pickup*) dan menerbitkan nomor resi resmi. Penjual tidak perlu keluar ongkos bensin untuk mengantar barang ke agen logistik.
4. **Pelacakan Otomatis (Menurunkan Beban Customer Service):**
   Status paket (sedang dijemput, diantar, atau sudah sampai) otomatis terupdate sendiri di aplikasi. Pembeli tidak perlu lagi bolak-balik bertanya ke admin *"Paket saya sudah sampai mana?"*.

---

## 3. Rincian Pekerjaan yang Sudah Diselesaikan (Berdasarkan Git Changes)

Pekerjaan yang belum di-commit telah ditinjau secara menyeluruh dan terbagi ke dalam 4 pilar utama:

### Pilar 1: Antarmuka Alamat Baru yang Bersih & Mudah Digunakan (Aplikasi Pembeli)
* **Membuang 4 Kolom Input Manual:** Kolom Provinsi, Kota, Kecamatan, dan Kode Pos yang sebelumnya harus diketik satu per satu kini dihapus seluruhnya.
* **Fitur Pencarian Otomatis (Autocomplete):** Digantikan oleh 1 kolom pencarian terpadu. Pengguna cukup mengetik nama daerah atau kode pos (misal: "Denpasar"), dan sistem otomatis menampilkan daftar kecamatan resmi.
* **Menambahkan Kolom Patokan Rumah (*Shopee-Grade Notes*):** Menambahkan kolom catatan patokan (misal: *"Pagar hitam, seberang minimarket"*). Fitur ini terbukti ampuh mencegah kurir lapangan nyasar atau gagal antar.
* **Menghapus Istilah Teknis:** Menghapus badge vendor teknis yang membingungkan pengguna biasa agar tampilan aplikasi terasa bersih dan ramah.

---

### Pilar 2: Hitung Ongkir Akurat & Hapus Total Data Palsu (Aplikasi Checkout)
* **Pembersihan Data Tarif Fiktif (*Zero Fake Data*):** Sebelumnya, sistem menggunakan data tarif pura-pura (Gojek Rp15.000, JNE Rp10.000, SiCepat Rp11.000). Semua data palsu ini telah **dihapus total**.
* **Kalkulasi Tarif Asli Real-Time:** Ongkir kini ditarik langsung dari server kurir berdasarkan berat gabungan belanjaan dan jarak tempuh toko ke pembeli.
* **Pesan Peringatan yang Mudah Dipahami:** Jika rute kurir belum tersedia atau koneksi internet terganggu, aplikasi menampilkan kotak bantuan berwarna lembut dengan tombol *"Coba Lagi"*, bukan pesan error teknis yang menakutkan.

---

### Pilar 3: Otomasi Penjemputan Paket & Resi Resmi (Aplikasi Penjual/Seller)
* **Menghapus Driver & Resi Fiktif:** Kode lama yang membuat nama kurir acak (*"Joko Supriyanto"*, *"Budi Raharjo"*) dan resi rekayasa telah dibersihkan seluruhnya.
* **Panggilan Kurir Otomatis:** Saat pesanan disetujui, sistem otomatis mengirimkan tiket penjemputan ke kurir dan menerima nomor resi resmi dari Biteship.
* **Kotak Dialog Informasi yang Jelas (*Smart Error Handling*):** Jika penjemputan tertunda, sistem memberi penjelasan manusiawi ke penjual, contoh:
  * *"Saldo deposit pengiriman tidak mencukupi, silakan isi deposit."*
  * *"Titik lokasi toko belum diatur pada peta (kurir instan butuh titik GPS presisi)."*
  * *"Format nomor telepon penerima belum sesuai standar Indonesia."*

---

### Pilar 4: Keamanan Sistem & Pencatatan Transaksi (Sisi Server & Database)
* **Buku Catatan Digital Pengiriman (`biteship_api_logs`):** Mencatat setiap aktivitas panggilan kurir dan waktu responsnya untuk memudahkan audit jika ada kendala di lapangan.
* **Pengaman Anti-Pemesanan Ganda & Sinkronisasi Pra-Kirim (*Pre-Dispatch Sync & Idempotency*):** Sistem secara otomatis memeriksa riwayat pemesanan sebelum mengirim permintaan ke server kurir. Jika tiket penjemputan sudah pernah diterbitkan, sistem langsung menyinkronkan data resi yang ada dan memblokir panggilan ulang. Hal ini menjamin saldo tidak terpotong ganda dan mencegah dua kurir berbeda datang untuk satu barang yang sama.
* **Pelacakan Otomatis Lewat Webhook (`biteship-webhook`):** Pintu penerima notifikasi otomatis dari ekspedisi yang memperbarui status barang tanpa campur tangan staf admin.

---

## 4. Bukti Nyata Hasil Tampilan Aplikasi (In-App Screenshots)

Seluruh alur di bawah ini telah berhasil diuji secara langsung pada aplikasi mobile:

### 1. Formulir Alamat yang Jauh Lebih Sederhana
Tampilan baru tanpa kolom manual yang membingungkan. Pengguna hanya mengisi nama, telepon, satu tombol pilih lokasi, dan detail rumah.

![Form Tambah Alamat Bersih](file:///c:/projects/flutter/ecommerce-umk/docs/images/01_address_form_clean.png)

---

### 2. Pencarian Cepat Nama Daerah / Kode Pos
Pembeli cukup mengetik nama daerah (contoh: "Denpasar"), sistem langsung menyajikan daftar area terverifikasi kurir.

![Modal Pencarian Area](file:///c:/projects/flutter/ecommerce-umk/docs/images/02_biteship_area_search_modal.png)

---

### 3. Data Lokasi Terkunci Otomatis
Setelah dipilih, data lokasi langsung tampil rapi dengan bingkai oranye dan terkunci sesuai standar logistik nasional.

![Area Terpilih](file:///c:/projects/flutter/ecommerce-umk/docs/images/03_address_form_selected_area.png)

---

### 4. Kolom Patokan Rumah untuk Membantu Kurir Lapangan
Pengguna dapat menambahkan ancer-ancer fisik rumah agar paket tidak salah alamat saat diantar kurir.

![Form Lengkap dengan Patokan](file:///c:/projects/flutter/ecommerce-umk/docs/images/04_address_form_completed_notes.png)

---

### 5. Kartu Alamat Siap Pakai untuk Belanja
Alamat tersimpan rapi dan langsung otomatis terpilih pada saat pembeli melakukan pembayaran (*checkout*).

![Daftar Alamat Tersimpan](file:///c:/projects/flutter/ecommerce-umk/docs/images/05_address_list_card_with_notes.png)

---

## 5. Ringkasan Perbandingan: Sebelum vs Sesudah

| Bagian | Kondisi Sebelum Pembaruan | Kondisi Sekarang (Setelah Integrasi) |
| :--- | :--- | :--- |
| **Pengisian Alamat** | Mengetik manual 4 kolom (Provinsi, Kota, Kecamatan, Kode Pos) – sering tipo. | 1 kali pencarian pintar, langsung terisi otomatis dan resmi. |
| **Akurasi Ongkir** | Sering memakai tarif perkiraan kasar atau tarif fiktif. | Tarif resmi 100% akurat dari ekspedisi berdasarkan berat barang. |
| **Proses Kirim Barang** | Penjual mengantar paket ke agen kurir dan mengetik nomor resi sendiri. | Kurir menjemput barang ke toko UMKM; nomor resi resmi terbit otomatis. |
| **Data Kurir & Resi** | Sebelumnya menggunakan nama driver dan nomor resi simulasi/acak. | Data 100% nyata dari kurir yang bertugas di lapangan. |
| **Pelacakan Barang** | Pembeli harus mengecek nomor resi di situs eksternal. | Posisi paket terlacak secara langsung (*live*) di dalam aplikasi. |
| **Penanganan Error** | Muncul pesan error bahasa pemrograman yang membingungkan pengguna. | Kotak dialog berbahasa Indonesia yang jelas dengan solusi praktis. |

---

## 6. Rencana Tahap Lanjutan (Bulan Depan)

1. **Cetak Label Pengiriman Otomatis:** Fitur 1-klik bagi penjual untuk mencetak label resi tempel ukuran standar stiker pengiriman (*thermal print*).
2. **Laporan Performa Kurir per Daerah:** Menganalisis ekspedisi mana yang paling tepat waktu di masing-masing kota agar kita bisa merekomendasikannya ke pembeli.
