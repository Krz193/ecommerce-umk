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

# Excel Requirements Completed (Updated Latest Sprint)

| Excel Cell | Excel Area | Excel Requirement | Implementation State |
| ---------- | ---------- | ----------------- | -------------------- |
| B5 | User Admin | CRUD user (Admin, UMK, Pembeli, Asisten UMK) | **Completed**: Admin User Management CRUD (Create, Edit Profile, Change Role `buyer`/`seller`/`assistant`/`admin`, Delete User) |
| B6 | User Admin | CRUD Role | **Completed**: Dynamic Role Management (Create custom role, edit role details, delete custom role) |
| B7 | User Admin | CRUD Permission | **Completed**: Dynamic Permission Matrix (Checkbox matrix per role, `has_permission()` Postgres helper, `role_permissions` join) |
| B12 | User Admin | Pengelolaan rekomendasi produk ke pembeli | **Completed**: Dynamic UMK product recommendation & promotion binding (`store_contents` with `product_id` binding) |
| B27 | User UMK | CRUD promosi | **Completed**: Admin & Assistant UMK Content & Promotion CRUD (`store_contents`: banner, promo, storytelling, social, educational) |
| B74 | User Asisten UMK | Pengelolaan profile asisten UMK | **Completed**: Assistant role transition, assistant dashboard, and store assignment |
| B75 | User Asisten UMK | Pencatatan otomatis log asistensi UMK | **Completed**: Assistant Assistance Log page and assistance activity logger |
| B76 | User Asisten UMK | CRUD Content UMK | **Completed**: Admin & Assistant UMK Content & Promotion CRUD (`store_contents`) |
| B23 | User UMK | Pengelolaan profile UMK | Completed through seller store onboarding/dashboard/profile fields |
| B24 | User UMK | CRUD produk | Completed through seller product create/edit/list/publish/draft & Admin Product CRUD |
| B25 | User UMK | CRUD karakteristik (tipe, ukuran, warna, dll) | Completed for MVP through product type, size, and color fields in seller create/edit and buyer product display. |
| B26 | User UMK | CRUD barang masuk | Completed for MVP through seller stock-in form, read-only current stock, stock movement history, atomic stock-in RPC, and tracked adjustment for corrections. |
| B28 | User UMK | Input hasil stock opname | Completed for MVP through seller Stock Opname input with system stock, physical count, note, and tracked stock movement adjustment. |
| B29 | User UMK | Approval pembayaran | Completed as automated payment lifecycle through Midtrans webhook, not manual approval |
| B30 | User UMK | CRUD pengiriman sisi UMK | **Completed**: Integrated Biteship logistics (Ojek Instan Gojek/Grab & Regular Expeditions JNE/SiCepat) with pickup booking, waybill/resi tracking, and driver milestones |
| B31 | User UMK | CRUD pembatalan dan refund transaksi sisi UMK | Completed for MVP through seller cancellation/refund request creation and request history on seller order detail. |
| B35 | User UMK | Display informasi pembelian | Completed through order list/detail |
| B36 | User UMK | Display informasi pembayaran | Completed through payment page and order/payment status |
| B38 | User UMK | Display laporan barang | Completed for MVP through seller dashboard goods report, product metrics, and low-stock alerts. |
| B39 | User UMK | Display laporan keuangan | Completed for MVP through seller dashboard financial report with paid revenue, completed revenue, pending payment value, and paid order count. |
| B40 | User UMK | Display laporan pembeli | Completed for MVP through seller dashboard buyer report with unique buyers, paid buyers, repeat buyers, and buyer order count. |
| B41 | User UMK | Display laporan pengiriman | Completed for MVP through seller dashboard shipment report with ready-to-ship, in-transit, delivered, and tracking coverage metrics. |
| B45 | User Pembeli | Searching produk | Completed in Flutter Home |
| B46 | User Pembeli | Display produk, promosi, dan rekomendasi | Completed for MVP through product listing and simple in-stock product recommendations. |
| B47 | User Pembeli | CRUD keranjang pemesanan | Completed through cart add/update/remove/quantity flow |
| B48 | User Pembeli | CRUD pembelian (check out) | **Completed**: Checkout flow with live Biteship courier/ojek selector, dynamic price calculation, and order confirmation |
| B49 | User Pembeli | CRUD pembayaran | **Completed**: Midtrans payment creation with dynamic gross amount including real shipping cost |
| B50 | User Pembeli | Display invoice dan kwitansi | Completed for MVP through formal invoice/receipt section in order detail. |
| B51 | User Pembeli | CRUD pengiriman sisi Pembeli | **Completed**: Delivery method choice (Ojek Instant vs Regular Courier), live shipment progress, driver info, and confirm received |
| B52 | User Pembeli | Display informasi progres pengiriman | **Completed**: Dynamic order tracking with courier service, waybill ID, driver name & phone, and webhook status updates |
| B53 | User Pembeli | CRUD pengiriman dengan Ojek | **Completed**: Integrated Gojek & Grab Instant delivery options via Biteship engine with real-time driver allocation display |
| B55 | User Pembeli | CRUD pembatalan dan refund transaksi sisi Pembeli | Completed for MVP through buyer cancellation/refund request creation and request history on order detail. |
| B59 | User Pembeli | CRUD Comment dan Star | Completed through buyer 1-5 star rating and comment CRUD on delivered order items, product review summary, and product detail review list. |
| B32 | User UMK | Approval Comment Pembeli | Completed through seller store owner review display and seller reply capability on product reviews. |
| B13 | User Admin | CRUD Comment Sistem sisi Admin | **Completed**: Admin System Feedback & Helpdesk management (`system_feedbacks`: status update, admin notes, delete, audit logs) |
| B33 | User UMK | CRUD Comment Sistem ke Admin | **Completed**: Mobile Feedback & Helpdesk center in Flutter (`/feedback`) with category selection, ticket submission, and user history tracking |
| B64 | User Ekspedisi | CRUD pengiriman sisi Ekspedisi | **Completed via Third-Party Logistics API (Biteship)**: Replaced standalone courier login with unified automated API for JNE, SiCepat, J&T, and Anteraja |
| B70 | User Ojek | Display informasi pengiriman dilengkapi peta | **Completed via Third-Party Ojek API (Biteship)**: Direct Gojek/Grab driver dispatch and tracking coordinates |
| B71 | User Ojek | Input status pengiriman | **Completed via Biteship Webhook**: Automated real-time driver status updates (`allocated`, `picking_up`, `dropping_off`, `delivered`) |

---

# Admin Features Completed Outside Explicit Excel Wording

| Feature | Current Implementation |
| ------- | ---------------------- |
| Admin authentication | Completed through Laravel admin auth and `is_admin` guard |
| Category Master CRUD | Completed: list/create/edit/deactivate/delete categories |
| Store moderation & Admin CRUD | Completed: list/detail/approve/suspend/create onboarding store/edit/delete |
| Product moderation & Admin CRUD | Completed: list/detail/archive/restore/create product/edit/delete |
| UMK Content & Promotion CRUD | Completed: list/create/edit/delete banners, promos, storytelling, social, educational guides |
| Dynamic Roles & Permission Matrix (RBAC) | Completed: create custom roles, permission matrix checkboxes, Supabase `has_permission()` Postgres helper |
| Order/payment & Logistics lookup | Completed: shows customer, payment, items, courier, shipping cost, waybill, and driver details |
| Audit logs | Completed for store/product/user/role/content/refund case admin actions |
| Manual refund/cancellation case tracking | Completed as admin case workflow |

---

# Deferred / Post-MVP Backlog

| Excel Cell | Excel Area | Deferred Requirement |
| ---------- | ---------- | -------------------- |
| B8 | User Admin | CRUD training |
| B9 | User Admin | CRUD training UMK |
| B10 | User Admin | CRUD asistensi UMK |
| B11 | User Admin | Display dan pengelolaan donasi UMK |
| B18 | User Admin | Display laporan ekspedisi per UMK |
| B19 | User Admin | Display laporan asisten UMK |
| B20 | User Admin | Display laporan donasi UMK |
| B44 | User Pembeli | Pengelolaan profile UMK |
| B54 | User Pembeli | Display informasi progres pengiriman dengan peta |
| B56 | User Pembeli | Call Pembeli vs Ojek |
| B57 | User Pembeli | Message Pembeli vs Ojek |
| B58 | User Pembeli | CRUD donasi UMK |
| B62 | User Ekspedisi | Pengelolaan profile ekspedisi |
| B63 | User Ekspedisi | Approval pengiriman |
| B65 | User Ekspedisi | CRUD pembatalan sisi Ekspedisi |
| B68 | User Ojek | Pengelolaan profile ekspedisi |
| B69 | User Ojek | Approval pengiriman |
| B79 | Kebutuhan umum lainnya | Sistem notifikasi, sistem kalender, dan modul umum lainnya |
