# AI Handoff

## Marketplace UMK

---

# Overview

Dokumen ini digunakan sebagai:

* handoff context antar AI session
* quick operational briefing
* implementation continuity reference
* short-term engineering memory

Dokumen ini HARUS mencerminkan kondisi implementasi aktif terbaru secara ringkas dan efisien.

---

# Current Project State

## Current State

Project saat ini sudah memiliki:

* Flutter buyer authentication flow
* Supabase Auth login/register
* auth-to-public-users sync trigger
* role foundation
* default development address trigger
* buyer product browsing
* cart flow
* checkout flow
* immutable order snapshot persistence
* Midtrans transaction creation
* payment page
* payment expiry countdown
* read-only payment polling
* webhook-based payment lifecycle
* replay-safe settlement handling
* inventory deduction lifecycle
* verified webhook-only post-settlement cart cleanup
* order history
* order detail
* realtime-ish order/payment refresh
* operational order lifecycle foundation
* RLS-isolated commerce architecture
* centralized stale-state mitigation implemented for main user-scoped providers
* release-build account switching validation passed
* release-build cart footer layout validation passed
* full buyer flow fresh account validation passed

Core buyer transactional commerce flow sudah berjalan end-to-end.

Saat ini project berada pada fase stabilisasi buyer flow sebelum masuk ke seller onboarding.

---

# Current Architecture Direction

## Finalized Stack

* Flutter → customer, seller, assistant app
* Supabase → primary backend infrastructure
* Laravel → admin & operational platform

---

## Current Marketplace Direction

* multi-vendor marketplace
* UMK-focused ecosystem
* delegated assistant operational model
* single-store checkout MVP
* commission-aware marketplace
* semi-manual payout flow
* Laravel admin separated from Flutter app

---

# Current Implemented Backend State

## Current Implemented Domains

### Identity Domain

* auth.users
* public.users
* addresses
* role foundation

### Marketplace Domain

* stores
* store_assistants
* categories
* products
* product_images

### Transaction Domain

* carts
* cart_items
* orders
* order_items
* payments
* refunds

---

## Current Security State

Implemented:

* actor-isolated RLS
* public surface RLS hardening
* explicit grants strategy
* service-role webhook lifecycle
* authenticated operational mutation
* migration-first workflow
* role helper functions
* store ownership helper foundation
* multi-assistant unique constraint fix

Seluruh perubahan schema wajib melalui:

```text
/supabase/migrations
````

---

# Current Flutter State

## Current Flutter Implemented Features

Implemented:

* Supabase Flutter initialization
* GoRouter routing
* route guard based on session
* login page
* register page
* logout
* auth state router refresh
* product list
* product detail
* cart page
* cart quantity update
* checkout page
* payment page
* payment countdown
* read-only payment polling
* order history page
* order detail page
* order timeline UI foundation
* continue payment flow
* app resume refresh for payment/order sync
* pull-to-refresh for orders
* realtime-ish order detail refresh
* centralized auth-state invalidation for user-scoped providers
* user-scoped provider `autoDispose` hardening for cart/order/address state
* release-build stale state validation passed

---

# Current Auth State

## Current Auth Flow

```text
User Register
→ Supabase Auth Sign Up
→ auth.users Insert
→ Database Trigger
→ public.users Insert
→ Default Role: buyer
→ Default Development Address Created
→ Session Active
→ Redirect to Home
```

---

## Current Auth Notes

Implemented:

* login
* register
* route protection
* redirect authenticated user away from auth routes
* redirect guest user to login
* auth profile sync trigger
* default role assignment
* default development address for testing

Important notes:

* email confirmation is disabled for development
* default address is temporary for testing only
* production should replace dummy address with real address input UI
* user deletion cleanup is not automated yet
* session persistence exists through Supabase
* Riverpod state must be invalidated manually on auth state change

---

# Current Checkout State

## Current Checkout Flow

```text
Client
→ Checkout Edge Function
→ Validate Auth
→ Validate Cart
→ Validate Products
→ Validate Address
→ Calculate Totals
→ Create Order
→ Create Order Items Snapshot
→ Create Payment Record
→ Create Midtrans Transaction
→ Return Success
```

---

## Current Checkout Validation

Implemented validations:

* authenticated request validation
* cart ownership validation
* address ownership validation
* empty cart validation
* product validation
* product published validation
* stock validation
* single-store validation
* server-side total calculation

---

# Current Webhook State

## Current Payment Webhook Flow

```text
Midtrans Webhook
→ Verify Payload
→ Verify Signature
→ Lookup Payment
→ Idempotency Guard
→ Load Order Items
→ Inventory Deduction
→ Cart Cleanup
→ Update Payment
→ Update Order
→ Return Success
```

---

## Current Webhook Behavior

Current behavior:

* settlement is source of truth
* frontend payment page is not source of truth
* duplicate settlement ignored safely
* inventory deducted after settlement only
* cart_items cleaned after settlement
* carts remain reusable
* order_items used as immutable inventory source
* webhook signature verification enabled
* replay-safe settlement lifecycle active

---

# Current Payment State

## Current Payment Flow

```text
Checkout Success
→ Payment Page
→ Countdown Display
→ Read-Only Payment Status Polling
→ App Resume Refresh
→ Webhook Settlement
→ Webhook Mutates Payment/Order To Paid / Expired / Failed
→ Provider Invalidation
→ Order History / Detail Refresh
```

Current payment statuses:

* pending
* paid
* expired
* failed
* refunded

Implemented:

* Midtrans transaction creation
* custom expiry
* timezone handling stabilized
* payment expiry countdown
* read-only payment polling against Midtrans status edge function
* stop polling on final status
* refresh on app resume
* payment status badge
* continue payment flow

Important implementation note:

* `check-payment-status` is read-only and does not mutate database lifecycle
* webhook remains the authoritative DB mutation path for payment/order lifecycle
* Flutter payment page no longer performs client-side cart cleanup after polling sees `paid`
* cart cleanup now happens through webhook settlement lifecycle only and has been manually validated

---

# Current Operational Order State

## Current Order Lifecycle

```text
pending
→ confirmed
→ processing
→ shipped
→ completed
```

Current order statuses:

* pending
* confirmed
* processing
* shipped
* completed
* cancelled

Implemented behavior:

* settlement can move order toward processing lifecycle
* shipped/completed mutation foundation exists
* lifecycle mutation protected by RLS
* invalid lifecycle transition rejected
* order status constraint synced with app lifecycle
* order timeline UI foundation exists

Pending:

* seller-side order progression UI
* seller confirm/process/ship/complete actions
* seller order management page

---

# Current Transaction Direction

## Checkout Direction

* checkout dilakukan via edge/server function
* checkout flow transactional-safe
* checkout pricing server-authoritative
* single-store checkout only pada MVP
* client tidak boleh direct write order/payment lifecycle

---

## Inventory Direction

Current inventory model:

* stock divalidasi saat checkout
* stock dikurangi hanya setelah settlement
* inventory mutation hanya via webhook settlement
* inventory source menggunakan order_items snapshot
* duplicate settlement tidak boleh deduct stock ulang

Known tradeoff:

* oversell masih mungkin terjadi under concurrency
* refund-required flow mungkin dibutuhkan nanti

Reasoning:

* simpler MVP lifecycle
* avoid reservation orchestration complexity
* avoid abandoned checkout cleanup complexity

---

## Payment Direction

* payment webhook adalah source of truth
* frontend redirect bukan source of truth
* payment lifecycle wajib idempotent
* settlement replay wajib di-ignore
* trusted lifecycle berjalan via service-role
* signature verification wajib aktif

---

## Order Direction

* order immutable secara histori
* shipping snapshot wajib dipertahankan
* order item snapshot wajib dipertahankan
* order item menjadi source inventory lifecycle
* order hanya terkait satu store pada MVP
* seller operational lifecycle akan dibangun setelah buyer flow stabil

---

# Current Persistence Architecture

## Users

Users saat ini menggunakan:

* Supabase Auth sebagai identity source
* `public.users` sebagai app profile
* auth trigger untuk profile sync
* role column
* default role sebagai `buyer`

---

## Addresses

Addresses saat ini menggunakan:

* user ownership
* RLS isolation
* default development address trigger untuk testing

Important note:

* default address trigger bersifat sementara
* address CRUD UI belum dibuat
* production flow harus mengganti dummy address dengan input alamat user

---

## Orders

Orders saat ini menggunakan:

* immutable shipping snapshot
* normalized order statuses
* normalized payment statuses
* unique order number
* server-side pricing authority
* operational lifecycle timestamps
* user-owned order visibility
* store owner/assistant operational foundation

---

## Order Items

Order items saat ini menggunakan:

* immutable product snapshot
* product_name snapshot
* product_price snapshot
* quantity snapshot
* subtotal snapshot
* product_thumbnail snapshot

---

## Payments

Payments saat ini menggunakan:

* provider abstraction
* provider_transaction_id
* normalized payment status
* expiration lifecycle support
* raw_response JSONB support
* webhook settlement lifecycle
* replay-safe settlement protection
* signature-verified webhook flow

Current provider:

* Midtrans sandbox

---

# Current User Roles

## Flutter Roles

Planned Flutter roles:

* buyer/customer
* store owner/seller
* Asisten UMK

Current implemented role foundation:

* buyer
* seller
* admin

Current active UI:

* buyer/customer only

---

## Laravel Admin Roles

* admin platform only

Admin tidak menggunakan Flutter app.

---

# Current State Management Notes

## Riverpod State Direction

State management uses:

* Riverpod providers
* service layer for Supabase/API calls
* model layer for data parsing
* page/widgets for UI

Important rules:

* user-scoped providers must use `autoDispose`
* user-scoped providers must be invalidated on auth state change
* user-scoped queries should filter by current authenticated user
* public/global providers may cache normally
* auth reset logic should be centralized at app level
* do not scatter reset logic inside login/logout buttons

---

## Known Stale State Issue

Observed in release build:

```text
Login test account
→ Cart has 1 item
→ Checkout blocked because address missing
→ Logout
→ Register/login new account
→ Old cart item still appears
```

Root cause:

* Riverpod provider cache survived auth transition
* Supabase auth session changed, but app provider state did not reset
* cartProvider and other user-scoped providers need invalidation on auth state change

Fix direction:

* use `autoDispose` for user-scoped providers
* invalidate user-scoped providers from centralized auth listener
* add missing user_id filters where appropriate
* harden order/address providers against cross-account leakage

Providers already hardened in current code:

* cartProvider
* ordersProvider
* orderDetailProvider
* addressProvider
* currentUserProvider

Validated:

* release build account switching does not leak cart/order/address state
* webhook-only payment/cart cleanup flow is manually validated

---

# Current Business Decisions

## Locked Decisions

* single-store checkout
* webhook-driven payment lifecycle
* settlement-based inventory deduction
* immutable transaction snapshots
* Supabase as primary backend
* Laravel hanya untuk admin
* Flutter tidak trusted untuk transaction lifecycle
* avoid premature microservices
* avoid realtime-first architecture
* seller onboarding starts only after buyer auth/session flow is stable

---

# Current Development Priority

## Immediate Priority

1. commit buyer/auth/session stabilization
2. start seller onboarding

---

# Current Risks

## Watch Carefully

* stale state leakage across accounts
* user-scoped providers not invalidated
* release build behavior differing from debug behavior
* webhook replay
* inventory race condition
* oversell edge-case
* financial inconsistency
* permission complexity growth
* temporary development default address accidentally remaining in production flow

---

# Important Engineering Notes

## Architecture Notes

* prioritize transaction consistency
* prioritize immutable transaction history
* inventory mutation hanya via settlement webhook
* settlement replay wajib replay-safe
* critical transaction flow wajib server-authoritative
* operational order mutation wajib authenticated
* lifecycle transition wajib guarded
* auth/session correctness is mandatory before seller onboarding
* user data isolation must be validated in release build

---

## Flutter Notes

Flutter:

* boleh direct read untuk safe/public data
* tidak trusted untuk transaction lifecycle
* checkout tidak boleh direct write order
* pricing calculation tidak boleh trusted dari client
* payment settlement state tidak boleh trusted dari client
* user-scoped provider cache must be cleared on auth changes
* release build account switching must remain validated after auth/session changes

---

## Laravel Notes

Laravel:

* admin-focused only
* operational tooling only
* bukan primary marketplace backend
* should use trusted backend credentials only
* must not expose service-role key to frontend

---

# What NOT To Do

## DO NOT

* redesign finalized architecture randomly
* replace Supabase infrastructure
* introduce premature microservices
* merge admin system into Flutter app
* overcomplicate checkout flow
* trust frontend transaction state
* deduct stock before settlement
* move seller onboarding before auth/session stabilization
* fix stale state only inside login/logout buttons
* assume Riverpod clears provider state automatically after logout
* ignore release-build-only bugs

---

# Current Foundation Summary

## Current Foundation Status

Project saat ini sudah memiliki:

* auth foundation
* Flutter login/register flow
* auth-to-public-users sync trigger
* role foundation
* default development address trigger
* marketplace entities
* transaction entities
* checkout persistence
* Midtrans integration
* payment page
* webhook settlement lifecycle
* replay-safe settlement protection
* inventory deduction lifecycle
* cart cleanup lifecycle
* order history/detail UI
* operational order lifecycle
* authenticated order mutation
* transaction-safe architecture
* RLS-hardened backend
* buyer core flow foundation

Backend saat ini sudah siap untuk:

* continued buyer flow stabilization
* seller onboarding after stale state fixes
* seller balance lifecycle
* notification lifecycle
* operational dashboard foundation

Flutter buyer/auth/session stabilization sudah tervalidasi untuk:

* release-build account switching tanpa cart/order/address leakage
* webhook-only cart cleanup
* cart footer release-build layout
* fresh account checkout/payment/order/cart flow
