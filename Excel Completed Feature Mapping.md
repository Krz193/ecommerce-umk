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
| B25 | User UMK | CRUD karakteristik (tipe, ukuran, warna, dll) | Completed for MVP through product type, size, and color fields in seller create/edit and buyer product display. |
| B26 | User UMK | CRUD barang masuk | Completed for MVP through seller stock-in form, read-only current stock, stock movement history, atomic stock-in RPC, and tracked adjustment for corrections. |
| B28 | User UMK | Input hasil stock opname | Completed for MVP through seller Stock Opname input with system stock, physical count, note, and tracked stock movement adjustment. |
| B29 | User UMK | Approval pembayaran | Completed as automated payment lifecycle through Midtrans webhook, not manual approval |
| B30 | User UMK | CRUD pengiriman sisi UMK | Completed for MVP through seller shipment input with courier and tracking number. |
| B31 | User UMK | CRUD pembatalan dan refund transaksi sisi UMK | Completed for MVP through seller cancellation/refund request creation and request history on seller order detail. |
| B35 | User UMK | Display informasi pembelian | Completed through order list/detail |
| B36 | User UMK | Display informasi pembayaran | Completed through payment page and order/payment status |
| B38 | User UMK | Display laporan barang | Completed for MVP through seller dashboard goods report, product metrics, and low-stock alerts. |
| B39 | User UMK | Display laporan keuangan | Completed for MVP through seller dashboard financial report with paid revenue, completed revenue, pending payment value, and paid order count. |
| B40 | User UMK | Display laporan pembeli | Completed for MVP through seller dashboard buyer report with unique buyers, paid buyers, repeat buyers, and buyer order count. |
| B41 | User UMK | Display laporan pengiriman | Completed for MVP through seller dashboard shipment report with ready-to-ship, in-transit, delivered, and tracking coverage metrics. |
| B45 | User Pembeli | Searching produk | Completed in Flutter Home |
| B46 | User Pembeli | Display produk, promosi, dan rekomendasi | Completed for MVP through product listing and simple in-stock product recommendations. Promotion engine remains post-MVP. |
| B47 | User Pembeli | CRUD keranjang pemesanan | Completed through cart add/update/remove/quantity flow |
| B48 | User Pembeli | CRUD pembelian (check out) | Completed through checkout flow |
| B49 | User Pembeli | CRUD pembayaran | Completed through Midtrans payment creation/status flow |
| B50 | User Pembeli | Display invoice dan kwitansi | Completed for MVP through formal invoice/receipt section in order detail. |
| B51 | User Pembeli | CRUD pengiriman sisi Pembeli | Completed for MVP through shipment progress display and confirm received. |
| B52 | User Pembeli | Display informasi progres pengiriman | Completed for MVP through order timeline, shipment progress, courier, and tracking number. |
| B55 | User Pembeli | CRUD pembatalan dan refund transaksi sisi Pembeli | Completed for MVP through buyer cancellation/refund request creation and request history on order detail. |
| B59 | User Pembeli | CRUD Comment dan Star | Completed through buyer 1-5 star rating and comment CRUD on delivered order items, product review summary, and product detail review list. |
| B32 | User UMK | Approval Comment Pembeli | Completed through seller store owner review display and seller reply capability on product reviews. |
| B14 | User Admin - Basis Web Responsive | Display laporan UMK | Completed for MVP through Admin Reports UMK summary. |
| B15 | User Admin - Basis Web Responsive | Display laporan barang per UMK | Completed for MVP through Admin Reports product count and low-stock report. |
| B16 | User Admin - Basis Web Responsive | Display laporan keuangan per UMK | Completed for MVP through Admin Reports paid revenue/application fee summary. |
| B17 | User Admin - Basis Web Responsive | Display laporan pembeli per UMK | Completed for MVP through Admin Reports buyer count per store and order lookup. |

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
| B34 | User UMK | Display informasi keranjang pemesanan | Cart UI exists for buyer; seller cart visibility is not separately implemented |
| B27 | User UMK | CRUD promosi | Promotion module not implemented |
| B33 | User UMK | CRUD Comment Sistem ke Admin | Comment/ticket module not implemented |
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
