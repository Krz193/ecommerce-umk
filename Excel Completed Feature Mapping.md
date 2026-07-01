# Excel Completed Feature Mapping

## Marketplace UMK

This document maps the Excel requirement list to the current MVP implementation state.

Excel reference:

* Column `A`: tahap
* Column `B`: rincian requirement
* Example: `B45` means the requirement is in column B, row 45.

Legend:

* `Completed`: implemented and usable in current Flutter/Admin scope
* `Partial`: foundation exists but not full Excel scope
* `Deferred`: intentionally not implemented in MVP

---

# Excel Requirements Completed

| Excel Cell | Excel Area | Excel Requirement | Current Implementation |
| ---------- | ---------- | ----------------- | ---------------------- |
| B23 | User UMK | Pengelolaan profile UMK | Completed through seller store onboarding/dashboard/profile fields |
| B24 | User UMK | CRUD produk | Completed through seller product create/edit/list/publish/draft |
| B29 | User UMK | Approval pembayaran | Completed as automated payment lifecycle through Midtrans webhook, not manual approval |
| B35 | User UMK | Display informasi pembelian | Completed through order list/detail |
| B36 | User UMK | Display informasi pembayaran | Completed through payment page and order/payment status |
| B45 | User Pembeli | Searching produk | Completed in Flutter Home |
| B47 | User Pembeli | CRUD keranjang pemesanan | Completed through cart add/update/remove/quantity flow |
| B48 | User Pembeli | CRUD pembelian (check out) | Completed through checkout flow |
| B49 | User Pembeli | CRUD pembayaran | Completed through Midtrans payment creation/status flow |

---

# Admin MVP Features Completed Outside Explicit Excel Wording

| Feature | Current Implementation |
| ------- | ---------------------- |
| Admin authentication | Completed through Laravel admin auth and `is_admin` guard |
| Store moderation | Completed: list/detail/approve/suspend/unsuspend |
| Product moderation | Completed: list/detail/archive/restore |
| Order/payment lookup | Completed as read-only admin support screen |
| Audit logs | Completed for store/product/refund case admin actions |
| Manual refund/cancellation case tracking | Completed as admin case workflow |
| MVP reports | Completed for UMK summary, finance summary, and low-stock products |

---

# Partial / Needs Later Expansion

| Excel Cell | Excel Area | Requirement | Missing Scope |
| ---------- | ---------- | ----------- | ------------- |
| B5 | User Admin - Basis Web Responsive | CRUD user (Admin, UMK, Pembeli, Expedisi, Gojek, Asisten UMK) | Admin user auth and marketplace user lookup completed; broad CRUD for all roles deferred |
| B14 | User Admin - Basis Web Responsive | Display laporan UMK | Admin Reports has UMK summary; full reporting module not implemented |
| B15 | User Admin - Basis Web Responsive | Display laporan barang per UMK | Admin Reports has product/low-stock summary; full report/export not implemented |
| B16 | User Admin - Basis Web Responsive | Display laporan keuangan per UMK | Admin Reports has paid revenue/application fee summary; ledger/report export not implemented |
| B17 | User Admin - Basis Web Responsive | Display laporan pembeli per UMK | User/order lookup exists; full buyer report not implemented |
| B25 | User UMK | CRUD karakteristik (tipe, ukuran, warna, dll) | Category and core product fields exist; variants for type/size/color not implemented |
| B26 | User UMK | CRUD barang masuk | Stock management exists; formal goods-in workflow not implemented |
| B30 | User UMK | CRUD pengiriman sisi UMK | Seller can ship order with provider/tracking; full shipment CRUD/API not implemented |
| B31 | User UMK | CRUD pembatalan dan refund transaksi sisi UMK | Admin refund case tracking exists; seller-side request flow not implemented |
| B34 | User UMK | Display informasi keranjang pemesanan | Cart UI exists for buyer; seller cart visibility is not separately implemented |
| B38 | User UMK | Display laporan barang | Seller dashboard metrics and low-stock alerts exist; full report/export not implemented |
| B39 | User UMK | Display laporan keuangan | Admin Reports exists; seller finance ledger not implemented |
| B41 | User UMK | Display laporan pengiriman | Shipment provider/tracking exists; full delivery report not implemented |
| B46 | User Pembeli | Display produk, promosi, dan rekomendasi | Product display exists; promotion/recommendation deferred |
| B50 | User Pembeli | Display invoice dan kwitansi | Order detail receipt/summary exists; formal invoice/print/export not implemented |
| B51 | User Pembeli | CRUD pengiriman sisi Pembeli | Shipping snapshot and confirm received exist; full shipment CRUD not implemented |
| B52 | User Pembeli | Display informasi progres pengiriman | Order timeline and tracking fields exist; GPS tracking not implemented |
| B55 | User Pembeli | CRUD pembatalan dan refund transaksi sisi Pembeli | Buyer refund request UI not implemented |
| B27 | User UMK | CRUD promosi | Promotion module not implemented |
| B28 | User UMK | Input hasil stock opname | Formal stock opname workflow not implemented |
| B32 | User UMK | Approval Comment Pembeli | Review/comment module not implemented |
| B33 | User UMK | CRUD Comment Sistem ke Admin | Comment/ticket module not implemented |
| B40 | User UMK | Display laporan pembeli | Full buyer analytics report not implemented |
| B59 | User Pembeli | CRUD Comment dan Star | Review/star module not implemented |
| B18 | User Admin | Display laporan ekspedisi per UMK | Expedition module not implemented |
| B19 | User Admin | Display laporan asisten UMK | Assistant module not implemented |
| B20 | User Admin | Display laporan donasi UMK | Donation module not implemented |

---

# Deferred From Excel

| Excel Cell | Excel Area | Deferred Requirement |
| ---------- | ---------- | -------------------- |
| B6 | User Admin - Basis Web Responsive | CRUD Role |
| B7 | User Admin - Basis Web Responsive | CRUD Permission |
| B8 | User Admin - Basis Web Responsive | CRUD training |
| B9 | User Admin - Basis Web Responsive | CRUD training UMK |
| B10 | User Admin - Basis Web Responsive | CRUD asistensi UMK |
| B11 | User Admin - Basis Web Responsive | Display dan pengelolaan donasi UMK |
| B12 | User Admin - Basis Web Responsive | Pengelolaan rekomendasi produk ke pembeli |
| B13 | User Admin - Basis Web Responsive | CRUD Comment Sistem sisi Admin |
| B44 | User Pembeli | Pengelolaan profile UMK |
| B53 | User Pembeli | CRUD pengiriman dengan Ojek |
| B54 | User Pembeli | Display informasi progres pengiriman dengan peta |
| B56 | User Pembeli | Call Pembeli vs Ojek |
| B57 | User Pembeli | Message Pembeli vs Ojek |
| B58 | User Pembeli | CRUD donasi UMK |
| B62 | User Ekspedisi | Pengelolaan profile ekspedisi |
| B63 | User Ekspedisi | Approval pengiriman |
| B64 | User Ekspedisi | CRUD pengiriman sisi Ekspedisi |
| B65 | User Ekspedisi | CRUD pembatalan sisi Ekspedisi |
| B68 | User Ojek | Pengelolaan profile ekspedisi |
| B69 | User Ojek | Approval pengiriman |
| B70 | User Ojek | Display informasi pengiriman dilengkapi peta |
| B71 | User Ojek | Input status pengiriman |
| B74 | User Asisten UMK | Pengelolaan profile asisten UMK |
| B75 | User Asisten UMK | Pencatatan otomatis log asistensi UMK |
| B76 | User Asisten UMK | CRUD Content UMK |
| B79 | Kebutuhan umum lainnya | Sistem notifikasi, sistem kalender, dan modul umum lainnya |

---

# Notes

* Excel is treated as full backlog, not strict MVP scope.
* Core e-commerce MVP is currently focused on buyer checkout, seller fulfillment, and admin moderation.
* Role/permission CRUD should be revisited when Asisten UMK or multiple admin operator levels become real requirements.
