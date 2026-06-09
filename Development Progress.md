# Development Progress

## Marketplace UMK

---

# Overview

Dokumen ini digunakan untuk:

* tracking progress development
* menjaga continuity antar session
* membantu AI handoff
* menghindari restart implementation
* menjadi source of truth progress project

Update dokumen ini secara berkala selama development berlangsung.

---

# Current Development Phase

## Current Phase

Buyer Core Flow Stabilization Before Seller Onboarding

---

## Current Focus

* Flutter buyer flow stabilization
* auth/session handling
* stale state prevention
* cart and checkout UX polish
* order/payment synchronization
* preparation before seller onboarding

---

# Overall Project Status

| Module                         | Status        |
| ------------------------------ | ------------- |
| Project Scope                  | ✅ Completed   |
| Business Flow                  | ✅ Completed   |
| Engineering Guideline          | ✅ Completed   |
| Entities & Relationships       | ✅ Completed   |
| Permissions & Access Control   | ✅ Completed   |
| Architecture Decisions         | ✅ Completed   |
| Supabase Setup                 | ✅ Completed   |
| Migration Workflow             | ✅ Completed   |
| Database Schema Planning       | ✅ Completed   |
| Auth System Foundation         | ✅ Completed   |
| Auth UI                        | ✅ Completed   |
| Auth Profile Sync              | ✅ Completed   |
| Role Foundation                | ✅ Completed   |
| Store System Foundation        | ✅ Completed   |
| Product System Foundation      | ✅ Completed   |
| Cart System Foundation         | ✅ Completed   |
| Cart UI                        | ⏳ In Progress |
| Checkout Flow                  | ✅ Completed   |
| Order System Foundation        | ✅ Completed   |
| Order History UI               | ✅ Completed   |
| Order Detail UI                | ✅ Completed   |
| Order Timeline UI              | ⏳ In Progress |
| Payment Foundation             | ✅ Completed   |
| Payment Gateway Integration    | ✅ Completed   |
| Payment Webhook Foundation     | ✅ Completed   |
| Payment Lifecycle Foundation   | ✅ Completed   |
| Payment Page UI                | ✅ Completed   |
| Marketplace RLS                | ✅ Completed   |
| RLS Hardening                  | ✅ Completed   |
| Transactional Checkout Flow    | ✅ Completed   |
| Transaction Persistence        | ✅ Completed   |
| Inventory Deduction Flow       | ✅ Completed   |
| Cart Cleanup Lifecycle         | ✅ Completed   |
| Idempotency Protection         | ✅ Completed   |
| Replay-Safe Settlement Flow    | ✅ Completed   |
| Operational Order Lifecycle    | ✅ Completed   |
| Flutter App Architecture       | ⏳ In Progress |
| Flutter Design System          | ⏳ Pending     |
| Customer App UI                | ⏳ In Progress |
| Seller Operational UI          | ⏳ Pending     |
| Assistant Operational UI       | ⏳ Pending     |
| State Management Structure     | ⏳ In Progress |
| Supabase Client Integration    | ✅ Completed   |
| Seller Balance System          | ⏳ Pending     |
| Notification System            | ⏳ Pending     |
| Laravel Admin Panel            | ⏳ Pending     |
| Testing & QA                   | ⏳ In Progress |
| Deployment                     | ⏳ Pending     |

---

# Completed Foundations

## Business Foundations

* marketplace model finalized
* multi-vendor architecture confirmed
* single-store checkout confirmed
* delegated assistant model confirmed
* manual/semi-manual payout confirmed
* refund flow finalized
* Flutter buyer/seller scope confirmed
* Laravel admin separation confirmed

---

## Technical Foundations

* Supabase as core backend finalized
* Laravel admin separation finalized
* Flutter role scope finalized
* hybrid data access strategy finalized
* modular monolith direction finalized
* RLS-first security approach finalized
* feature-based Flutter structure used
* GoRouter navigation implemented
* Riverpod state management implemented
* service/model/provider layering implemented

---

## Backend Foundations

* Supabase cloud project initialized
* migration-first workflow implemented
* explicit schema versioning implemented
* marketplace core schema implemented
* transaction core schema implemented
* marketplace RLS policies implemented
* RLS public surface hardened
* delegated assistant access implemented
* transactional checkout persistence implemented
* immutable order snapshot strategy implemented
* normalized payment lifecycle foundation implemented
* payment-ready checkout architecture implemented
* checkout edge function implemented
* Midtrans transaction creation implemented
* payment webhook foundation implemented
* replay-safe settlement lifecycle implemented
* idempotent payment lifecycle implemented
* inventory deduction lifecycle implemented
* post-settlement cart cleanup implemented
* webhook-only cart cleanup manually validated
* service-role webhook architecture implemented
* operational order lifecycle implemented
* authenticated operational order mutation implemented
* lifecycle transition guard implemented
* operational order RLS implemented
* role column implemented on `users`
* auth profile trigger implemented
* default development address trigger implemented
* store assistant unique constraint fixed for multi-assistant support
* order status constraint synced with application lifecycle

---

## Flutter Buyer Foundations

* Supabase Flutter initialized
* login UI implemented
* register UI implemented
* route guard implemented
* session redirect implemented
* auth state router refresh implemented
* product list implemented
* product detail implemented
* cart page implemented
* cart quantity update implemented
* checkout page implemented
* payment page implemented
* payment countdown implemented
* read-only payment polling implemented
* payment polling timer cleanup implemented
* order history page implemented
* order detail page implemented
* order timeline UI foundation implemented
* continue payment flow implemented
* orders page realtime-ish refresh implemented
* order detail realtime-ish refresh implemented
* app resume refresh implemented for payment/order flows
* centralized stale-state mitigation implemented for main user-scoped providers
* release-build stale-state validation passed
* release-build cart footer layout validation passed
* full buyer flow fresh account validation passed

---

## Financial Foundations

* seller balance architecture finalized
* financial ledger pattern finalized
* commission-aware transaction model finalized
* normalized payment status architecture implemented

---

# In Progress

## Current Active Work

* buyer flow UI/UX polish
* preparation for seller onboarding

---

# Pending Major Tasks

## Backend & Database

* seller balance implementation
* notification system
* transaction audit improvements
* webhook signature hardening
* seller settlement lifecycle
* shipment lifecycle preparation
* refund-required edge-case handling
* production replacement for development default address trigger
* address CRUD-ready flow
* stale state security audit completion

---

## Flutter App

### Foundation

* improve shared loading states
* improve shared empty states
* improve shared error/snackbar handling
* continue state management hardening
* improve release-build UX polish

### Customer Features

* address CRUD UI
* profile page
* product search
* product filtering
* cart UI polish
* checkout validation polish
* invoice/receipt display
* review/comment/star feature
* wishlist
* notification UI

### Seller Features

* seller onboarding
* create store flow
* store dashboard
* product management
* stock management
* order processing
* order status progression actions

### Assistant Features

* assigned store management
* operational product management
* operational order handling

---

## Laravel Admin

* admin authentication
* moderation dashboard
* seller verification dashboard
* refund management
* analytics/reporting

---

## Integrations

* shipping API integration
* notification/email integration

---

# Deferred Features

## Intentionally Deferred

* multi-store checkout
* automated payout
* split settlement
* full realtime architecture
* advanced promotion engine
* livestream commerce
* loyalty ecosystem
* warehouse distribution system
* AI recommendation engine
* inventory reservation system

---

# Current Risks

## Potential Risks

* marketplace scope expansion
* overengineering transaction flow
* webhook lifecycle complexity
* permission complexity growth
* financial logic inconsistency
* payment reconciliation inconsistency
* inventory race condition under concurrency
* duplicate webhook replay
* optimistic inventory oversell edge-case
* stale state leakage across account switching
* user-scoped providers not invalidated on auth change
* release build behavior differing from debug flow
* temporary development default address leaking into production flow

---

# Current Constraints

## MVP Constraints

* MVP-first approach mandatory
* prioritize maintainability
* prioritize transactional stability
* avoid unnecessary abstraction
* avoid enterprise-level complexity
* keep seller onboarding blocked until buyer auth/session flow is stable
* keep Laravel admin delayed until seller/customer core flow is coherent

---

# Current Architecture Notes

## Important Notes

* admin ecosystem isolated in Laravel
* Flutter app only for customer/seller/assistant
* critical transaction logic server-side only
* direct Supabase access limited to safe operations
* RLS mandatory for sensitive tables
* checkout flow must remain transactional-safe
* payment webhook is source of truth
* immutable order snapshots mandatory
* server-side pricing is authoritative
* payment settlement handled exclusively via webhook
* inventory deducted only after settlement
* payment webhook includes idempotency guard
* order snapshot used for inventory lifecycle
* cart_items cleaned after successful settlement
* carts remain reusable after settlement
* webhook settlement replay safely ignored
* operational order lifecycle protected by RLS
* lifecycle mutation guarded by transition validation
* update-order-status requires authenticated JWT
* seller onboarding should start only after stale state fixes are complete
* user-scoped Riverpod providers must be invalidated on auth changes
* public/global providers may cache normally
* user-owned providers should use `autoDispose`
* do not place auth reset logic inside individual login/logout buttons
* centralized auth state listener is preferred
* current centralized auth-state listener already invalidates cart/orders/address/current user providers
* current cart/orders/order detail/address providers already use explicit user scoping
* release-build account switching validated on physical device

---

# Current Auth Architecture

## Current Auth Flow

User Register
→ Supabase Auth Sign Up
→ `auth.users` Insert
→ Database Trigger
→ `public.users` Insert
→ Default Role: `buyer`
→ Default Development Address Created
→ Session Active
→ Redirect to Home

---

## Current Auth Notes

Implemented:

* login page
* register page
* logout
* GoRouter auth guard
* auth state refresh listener
* route protection
* public profile sync trigger
* default role assignment
* default development address creation

Known notes:

* email confirmation is disabled for development
* default address creation is temporary for testing
* future production flow should replace dummy address with real address input
* user deletion cleanup is not automated yet
* account switching requires provider invalidation to avoid stale data

---

# Current Checkout Architecture

## Current Checkout Flow

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

---

## Current Payment Lifecycle

Pending Payment
→ Midtrans Transaction Created
→ Payment Page Countdown
→ Read-Only Payment Polling
→ Webhook Settlement
→ Payment Status Mutation
→ Order Payment Mutation
→ Inventory Deduction
→ Cart Cleanup
→ Idempotency Protection
→ Processing Order
→ Shipped Order
→ Completed Order

Important implementation note:

* payment polling reads Midtrans status through `check-payment-status`
* `check-payment-status` does not mutate payment/order records
* webhook remains the authoritative database mutation path
* Flutter payment page no longer clears cart client-side after polling sees `paid`
* cart cleanup happens through webhook settlement lifecycle only and has been manually validated

---

## Current Checkout Validation

Implemented validations:

* authenticated request validation
* cart ownership validation
* address ownership validation
* empty cart validation
* product existence validation
* product published validation
* stock validation
* single-store validation
* server-side total calculation

---

# Current Persistence Strategy

### Users

Users currently implement:

* profile row in `public.users`
* role column
* auth-triggered profile creation
* default role as `buyer`

### Addresses

Addresses currently implement:

* user ownership
* default development address for testing
* RLS ownership protection

Production note:

* address CRUD UI is still pending
* dummy address trigger should be replaced later with real user input flow

### Orders

Orders currently implement:

* immutable shipping snapshots
* normalized order statuses
* normalized payment statuses
* unique order numbers
* server-side pricing authority
* user-owned order access
* store-owner/assistant operational access foundation

### Order Items

Order items currently implement:

* immutable product snapshots
* product_name snapshot
* product_price snapshot
* subtotal snapshot
* product_thumbnail snapshot

### Payments

Payments currently implement:

* provider abstraction
* provider transaction ID support
* expiration lifecycle support
* raw_response JSONB support
* one-payment-per-order strategy
* webhook settlement lifecycle
* idempotent settlement protection
* replay-safe settlement handling
* frontend countdown support

---

# Current Inventory Strategy

## Current Inventory Model

Current inventory strategy uses:

* optimistic inventory lifecycle
* settlement-based inventory deduction
* no temporary reservation system
* immutable order snapshot inventory source

Current behavior:

* stock validated during checkout
* stock deducted after settlement
* duplicate settlement ignored safely
* insufficient inventory protected during settlement

Known MVP tradeoff:

* oversell edge-case still possible under concurrency
* manual refund flow may be required later

Reasoning:

* simpler transactional architecture
* avoid reservation orchestration complexity
* avoid abandoned checkout cleanup lifecycle
* prioritize maintainability for MVP

---

# Current State Management Strategy

## Riverpod Provider Rules

User-scoped providers should:

* use `autoDispose`
* filter by current authenticated user when querying user-owned data
* be invalidated on auth state changes
* not rely on stale cached data after logout/login/register

Public/global providers may:

* cache normally
* avoid unnecessary invalidation on auth changes

Examples of user-scoped providers:

* `cartProvider`
* `ordersProvider`
* `orderDetailProvider`
* `addressProvider`
* `currentUserProvider`

Examples of public/global providers:

* product listing
* category listing
* published store listing

---

## Known Stale State Issue

Observed in release build:

1. login with test account
2. cart contains one item
3. checkout blocked because address is missing
4. logout
5. register/login new account
6. old cart item still appears

Root cause:

* Riverpod provider cache survived auth transition
* provider data was not invalidated on auth change

Fix direction:

* centralize auth-state reset in app-level listener
* invalidate user-scoped providers on auth changes
* use `autoDispose` for user-scoped providers
* add missing `user_id` filters where appropriate

Do not fix this by:

* adding manual reset logic only inside logout button
* relying only on navigation
* assuming Supabase session changes reset provider memory automatically

---

# Current Migration State

## Implemented Migrations

* auth_and_users
* marketplace_core
* marketplace_rls
* transaction_core
* cart_rls
* marketplace_table_grants
* split_customer_and_seller_policies
* cleanup_product_mega_policies
* grant_store_assistant_read
* cart_items_rls
* add_order_status_constraints
* orders_rls
* order_items_rls
* payment_status_constraints
* payments_rls
* payments_update_grant
* payments_update_policy
* payments_service_role_grants
* orders_service_role_grants
* inventory_service_role_grants
* cart_cleanup_service_role_grants
* add_shipped_at_to_orders
* store_owner_orders_rls
* add_cart_constraints_and_policies
* add_product_thumbnail_to_order_items
* add_user_role
* fix_store_assistant_unique_constraint
* sync_order_status_constraint
* harden_public_policies
* create_role_helper_functions
* create_auth_profile_trigger
* add_default_address_on_signup
* fix_default_address_trigger

---

# Next Immediate Priority

## Next Step

1. commit buyer/auth/session stabilization
2. start seller onboarding

---

# Blockers

## Current Blockers

No backend blocker currently.

Current frontend blocker:

No buyer/auth/session blocker currently.

---

# Development Principles Reminder

## Always Prioritize

* stable checkout flow
* transaction consistency
* maintainable structure
* explicit ownership
* readable architecture
* MVP delivery speed
* auth/session correctness
* user data isolation

---

# Important Reminder for AI Agents

## DO NOT

* restart architecture direction
* replace Supabase infrastructure
* introduce premature microservices
* redesign finalized business flow
* overabstract domain logic
* move seller onboarding ahead of buyer auth/session stabilization
* scatter auth reset logic inside UI buttons
* assume Riverpod clears user state automatically on logout

---

## CONTINUE FROM CURRENT STATE

Project sudah memiliki:

* finalized marketplace scope
* finalized business flow
* finalized architecture direction
* finalized permission model
* finalized entity structure
* implemented backend foundation
* implemented migration workflow
* implemented RLS foundation
* implemented transactional checkout persistence
* implemented payment-ready checkout architecture
* implemented webhook payment lifecycle
* implemented replay-safe settlement lifecycle
* implemented inventory deduction lifecycle
* implemented post-settlement cart cleanup
* manually validated webhook-only cart cleanup
* implemented idempotent settlement protection
* implemented authenticated operational order lifecycle
* implemented lifecycle transition validation
* implemented operational order RLS protection
* implemented Flutter auth/register/login flow
* implemented auth-to-public-users sync trigger
* implemented role foundation
* implemented default development address trigger
* implemented buyer checkout/payment/order flow
* implemented realtime-ish order/payment refresh
* identified release-build stale state issue
* implemented centralized user-scoped provider hardening for cart/order/address/current user state
* validated release-build account switching without cart/order/address leakage
* removed client-side cart cleanup from payment page
* manually validated webhook-only cart cleanup
* validated cart footer release-build layout
* validated full buyer flow with fresh account
* ready to commit buyer/auth/session stabilization

Implementation harus melanjutkan fondasi yang sudah ada.
