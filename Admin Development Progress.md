# Admin Development Progress

## Marketplace UMK Laravel Admin

---

# Overview

Dokumen ini digunakan untuk:

* tracking progress development Laravel Admin
* menjaga continuity antar session khusus admin web
* membantu AI handoff untuk pekerjaan Laravel
* menghindari pencampuran scope Flutter app dan Supabase Edge Function
* menjadi source of truth progress admin project

Update dokumen ini secara berkala selama development admin berlangsung.

---

# Current Development Phase

## Current Phase

Laravel Admin MVP Foundation

---

## Current Focus

* Laravel admin app foundation
* admin authentication and access guard
* store moderation workflow
* product moderation workflow
* order and payment lookup for operational support

---

## Current Change Context

Perubahan admin yang akan berjalan difokuskan ke Laravel saja:

* Admin app foundation: Laravel project structure, environment, database connection, route layout
* Admin auth: login, session, admin-only middleware, logout
* Store moderation: list stores, detail store, approve/reject/suspend workflow
* Product moderation: list products, detail product, hide/unhide or moderation status workflow
* Order/payment lookup: read-only order, payment, buyer, seller, and store inspection
* Manual operation notes: cancellation/refund note tracking and lightweight audit trail

Current repo verification:

* Laravel admin implementation has not started yet
* Flutter mobile core e-commerce is the current production-facing client
* Supabase remains the source of truth database
* Laravel admin should use server-side privileged access carefully
* Admin MVP scope is intentionally smaller than the Excel full backlog

---

# Overall Admin Project Status

| Module                         | Status      |
| ------------------------------ | ----------- |
| Admin Scope                    | ✅ Completed |
| Admin Architecture Direction   | ✅ Completed |
| Laravel Project Setup          | ⏳ Pending   |
| Environment Configuration      | ⏳ Pending   |
| Database Connection            | ⏳ Pending   |
| Admin Authentication           | ⏳ Pending   |
| Admin Authorization Guard      | ⏳ Pending   |
| Admin Layout                   | ⏳ Pending   |
| Dashboard Summary              | ⏳ Pending   |
| User Lookup                    | ⏳ Pending   |
| Store Moderation               | ⏳ Pending   |
| Product Moderation             | ⏳ Pending   |
| Order Lookup                   | ⏳ Pending   |
| Payment Lookup                 | ⏳ Pending   |
| Manual Cancellation Tracking   | ⏳ Pending   |
| Manual Refund Tracking         | ⏳ Pending   |
| Audit Trail                    | ⏳ Pending   |
| Admin Testing & QA             | ⏳ Pending   |
| Admin Deployment               | ⏳ Pending   |

---

# Completed Foundations

## Business Foundations

* Laravel admin separation confirmed
* Flutter app remains customer/seller/assistant client
* admin role is operational and moderation-focused
* manual/semi-manual payout direction confirmed
* refund/cancellation should start as manual operational flow
* Excel backlog is treated as broad post-MVP backlog, not initial admin scope

---

## Technical Foundations

* Supabase is the source of truth database
* Laravel admin should not duplicate marketplace domain logic unnecessarily
* admin actions must be explicit and auditable
* read-heavy admin screens should start simple before analytics/reporting
* privileged access must be isolated from Flutter client access
* admin should not bypass important lifecycle constraints casually

---

# In Progress

## Current Active Work

No Laravel admin code work has started yet.

---

# Pending Major Tasks

## Laravel App Foundation

* create or identify Laravel admin app directory
* configure `.env` for database and app secrets
* connect Laravel to Supabase Postgres
* define admin route group
* create admin layout shell
* prepare local run and build commands

---

## Admin Auth & Access

* implement admin login page
* implement admin session handling
* create admin-only middleware
* decide admin identity source:
  * existing `public.users.role = admin`
  * separate Laravel admin users table
  * environment-seeded first admin account
* implement logout
* protect all admin routes

---

## Store Moderation

MVP workflow:

* list stores by status
* view store detail
* view store owner profile
* approve pending store
* reject or suspend problematic store
* record moderation reason
* show basic store product/order context

---

## Product Moderation

MVP workflow:

* list products with store and seller context
* filter by status, category, store, and stock condition
* view product detail and image thumbnail
* hide/unhide or moderation-flag product
* record moderation reason
* keep seller product management inside Flutter seller app

---

## Order & Payment Lookup

MVP workflow:

* list orders
* filter by order status and payment status
* view order detail with buyer, seller, store, items, shipment, and payment
* inspect Midtrans transaction reference stored in database
* keep payment mutation controlled by webhook and established backend functions

---

## Manual Operations

Initial manual admin support:

* cancellation case tracking
* refund case tracking
* admin internal notes
* simple audit log for moderation and manual operation changes
* no automated payout or split settlement yet

---

# Deferred Admin Features

## Intentionally Deferred

* broad analytics/reporting dashboard
* Excel-style full reporting modules
* training/asistensi modules
* donation modules
* courier/ojek admin operations
* map/GPS monitoring
* call/message management
* automated refund execution
* automated seller payout
* advanced role and permission management
* recommendation/promotion management
* warehouse/distribution admin

---

# Current Risks

## Potential Risks

* admin scope becoming too broad before MVP moderation exists
* privileged Laravel access bypassing RLS/lifecycle rules without audit
* duplicated business logic between Laravel and Supabase Edge Functions
* direct payment mutation causing mismatch with webhook source of truth
* unclear admin identity model
* missing audit trail for moderation and manual operations
* exposing service-role credentials to the wrong runtime or client
* overbuilding analytics before operational workflows are usable

---

# Current Constraints

## MVP Constraints

* keep Laravel admin separate from Flutter app
* start with operational moderation, not broad ERP/reporting
* keep payment settlement source of truth in webhook flow
* keep order lifecycle mutation aligned with existing backend rules
* avoid implementing automated payouts in MVP admin
* require audit trail for sensitive admin actions
* do not expose service-role credentials to any browser client code

---

# Current Architecture Notes

## Important Notes

* Laravel Admin is a separate web admin surface
* Flutter app remains the buyer/seller/assistant application
* Supabase database is the shared persistence layer
* Supabase Edge Functions remain responsible for checkout, payment webhook, payment status check, and operational order mutation
* Laravel admin may read operational data directly from Postgres
* Laravel admin writes should be limited to explicit admin workflows
* admin moderation should not replace seller product management
* admin payment screens should start read-only except manual case tracking
* audit logging should be introduced before sensitive moderation actions expand

---

# Current Admin Auth Direction

## Proposed Admin Auth Flow

Admin User
→ Laravel Login Page
→ Laravel Session
→ Admin Guard/Middleware
→ Admin Dashboard
→ Moderation/Lookup Screens

Open decision:

* whether admin identity comes from existing `public.users.role = admin` or a separate Laravel-controlled admin users table

Recommended MVP direction:

* use a separate Laravel admin authentication table for the web panel
* keep public marketplace users separate from privileged admin operators
* map admin actions to audit log entries with admin user ID

---

# Current Admin Data Strategy

## Read Strategy

Initial admin pages should read:

* users
* stores
* products
* product images
* categories
* orders
* order items
* payments

## Write Strategy

Initial admin writes should be limited to:

* store moderation status
* product moderation visibility/status if schema supports it
* manual cancellation/refund case notes
* audit log records

Schema changes may be needed for:

* admin users
* admin audit logs
* moderation notes
* refund/cancellation cases
* product moderation flags if current product status is not enough

---

# Current Migration State

## Implemented Admin Migrations

No Laravel-admin-specific migrations implemented yet.

Related marketplace migrations already available in Supabase:

* marketplace_core
* marketplace_rls
* transaction_core
* add_user_role
* prepare_store_onboarding
* prepare_seller_product_management
* prepare_seller_order_management
* add_order_shipment_fields
* prepare_product_image_storage
* seed_core_categories
* allow_store_profile_for_published_products
* fix_store_public_policy_recursion

---

# Next Immediate Priority

## Laravel Admin MVP Next Steps

1. Admin project foundation
   * create or confirm Laravel admin app directory
   * configure environment
   * connect to Supabase Postgres
   * create admin route group and base layout

2. Admin authentication
   * implement admin login/logout
   * implement admin session guard
   * protect admin routes
   * decide admin identity storage

3. Store moderation
   * list pending/active/suspended stores
   * view store detail and owner context
   * approve or suspend store
   * record admin reason and audit entry

4. Product moderation
   * list products with store/category/status context
   * view product detail and image
   * prepare hide/unhide or moderation flag flow

5. Order/payment lookup
   * list orders
   * view order detail
   * view payment status and provider transaction reference
   * keep mutation read-only until manual case tracking exists

## Admin MVP Priority Decision

Build first:

1. Laravel foundation
2. admin auth and guard
3. store moderation
4. product moderation
5. order/payment lookup
6. manual cancellation/refund case notes
7. audit trail

Defer:

* advanced analytics
* broad reporting
* donation/training/asistensi modules
* courier/ojek operational tools
* automated payout/refund execution
* complex role-permission matrix

---

# Blockers

## Current Blockers

Current admin foundation blocker:

Laravel admin app directory and stack choice have not been created or confirmed yet.

Current admin auth blocker:

Admin identity model has not been finalized.

Current moderation blocker:

Admin-specific audit/moderation schema has not been implemented yet.

---

# Development Principles Reminder

## Always Prioritize

* operational usefulness
* privileged access safety
* auditability
* clear moderation workflows
* minimal MVP scope
* no duplicate payment settlement logic
* maintainable Laravel structure
* separation from Flutter client concerns

---

# Important Reminder for AI Agents

## DO NOT

* mix Flutter app progress into this admin document
* implement broad Excel backlog before admin MVP moderation
* expose Supabase service-role credentials to frontend/browser code
* mutate payment settlement directly from admin without a designed backend flow
* duplicate checkout logic in Laravel admin
* turn admin panel into courier/donation/training platform during MVP
* bypass existing order lifecycle constraints without audit
* assume Laravel admin has already been scaffolded

---

## CONTINUE FROM CURRENT STATE

Admin project saat ini memiliki:

* finalized separation from Flutter app
* confirmed Laravel direction for admin web
* confirmed MVP-first admin scope
* confirmed Supabase as shared database/source of truth
* confirmed initial priority: admin foundation, auth, store moderation, product moderation, order/payment lookup
* no Laravel admin implementation yet
* no admin-specific migration yet
* open decision for admin identity model

Implementation harus melanjutkan dari Laravel admin foundation, bukan dari Flutter mobile app.
