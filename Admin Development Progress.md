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

* Laravel admin app has been installed under `admin/`
* Laravel admin scaffold includes `artisan`, `composer.json`, and `.env.example`
* Admin stack currently uses Laravel React starter kit with Inertia and Fortify
* Laravel framework requirement is `^13.17`
* PHP requirement is `^8.3`
* Admin MVP foundation routes implemented: dashboard, stores, products, orders
* Admin middleware guard implemented with local Laravel `users.is_admin`
* Marketplace database connection configured as separate `marketplace` connection
* Marketplace Supabase connection manually validated through Laravel tinker against `stores`
* Laravel admin login and marketplace data access manually validated in browser
* PHP syntax check passed for new admin controllers
* `npm run types:check` passed for admin React/Inertia pages
* `php artisan route:list` validated dashboard, store, product, and order routes
* Store moderation action labels polished: suspended stores now show `Unsuspend` instead of `Approve`
* Store list action alignment polished with separate `Detail` and `Actions` columns
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
| Laravel Project Setup          | ✅ Completed |
| Environment Configuration      | ✅ Completed |
| Database Connection            | ✅ Completed |
| Admin Authentication           | ✅ Completed |
| Admin Authorization Guard      | ✅ Completed |
| Admin Layout                   | ⏳ In Progress |
| Dashboard Summary              | ✅ Completed |
| User Lookup                    | ⏳ Pending   |
| Store Moderation               | ⏳ In Progress |
| Product Moderation             | ⏳ In Progress |
| Order Lookup                   | ✅ Completed |
| Payment Lookup                 | ✅ Completed |
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

* Laravel app scaffold exists under `admin/`
* Laravel React starter kit selected for admin web UI
* Inertia Laravel is available for server-driven React pages
* Laravel Fortify is available for authentication foundation
* Laravel Pint, Larastan/PHPStan, and Pest are available for code quality/testing
* Supabase is the source of truth database
* Laravel admin should not duplicate marketplace domain logic unnecessarily
* admin actions must be explicit and auditable
* read-heavy admin screens should start simple before analytics/reporting
* privileged access must be isolated from Flutter client access
* admin should not bypass important lifecycle constraints casually

---

# In Progress

## Current Active Work

Laravel admin MVP foundation has started.

Current implementation surface:

* `admin/artisan`
* `admin/composer.json`
* `admin/.env.example`
* `admin/config/database.php`
* `admin/routes/web.php`
* `admin/app/Http/Middleware/EnsureAdminUser.php`
* `admin/app/Http/Controllers/Admin/`
* `admin/resources/js/pages/admin/`

Implemented this pass:

* separate `marketplace` database connection for Supabase/Postgres marketplace reads and controlled admin writes
* local Laravel admin guard using `users.is_admin`
* seeded admin account support through `ADMIN_NAME`, `ADMIN_EMAIL`, and `ADMIN_PASSWORD`
* dashboard metrics and recent store/order summary
* store moderation list/detail with approve and suspend actions
* product moderation list/detail with archive and restore actions
* read-only order/payment lookup list/detail

Next active work is filling real `.env`, running migrations/seeders, connecting to Supabase Postgres, and manually validating in browser.
Real `.env`, admin login, and Supabase marketplace connection have now been manually validated. Next active work is audit trail, moderation reason capture, and browser QA for each moderation/lookup screen.

---

# Pending Major Tasks

## Laravel App Foundation

* create or identify Laravel admin app directory - completed: `admin/`
* configure `.env` for database and app secrets - pending local values
* connect Laravel to Supabase Postgres - implementation prepared through `marketplace` connection
* define admin route group - completed
* create admin layout shell - started using existing starter-kit layout and admin sidebar nav
* prepare local run and build commands

---

## Admin Auth & Access

* implement admin login page
* implement admin session handling
* create admin-only middleware - completed
* decide admin identity source:
  * existing `public.users.role = admin`
  * separate Laravel admin users table
  * environment-seeded first admin account
* implement logout
* protect all admin routes - completed for dashboard, stores, products, orders, and settings

---

## Store Moderation

MVP workflow:

* list stores by status
* view store detail
* view store owner profile
* approve pending store - implemented
* unsuspend suspended store - implemented through active status restore
* reject or suspend problematic store - suspend implemented, reject reason pending schema
* record moderation reason
* show basic store product/order context
* separate detail and action columns for cleaner table alignment - implemented

---

## Product Moderation

MVP workflow:

* list products with store and seller context
* filter by status, category, store, and stock condition
* view product detail and image thumbnail
* hide/unhide or moderation-flag product - archive/restore implemented using `archived_at` and draft status
* record moderation reason
* keep seller product management inside Flutter seller app

---

## Order & Payment Lookup

MVP workflow:

* list orders
* filter by order status and payment status
* view order detail with buyer, seller, store, items, shipment, and payment
* inspect Midtrans transaction reference stored in database
* keep payment mutation controlled by webhook and established backend functions - implemented as read-only admin lookup

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

Implemented Laravel-admin-specific migrations:

* `2026_07_01_000001_add_is_admin_to_users_table`

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
   * confirm Laravel admin scaffold under `admin/` - completed
   * configure environment - completed for local development
   * connect to Supabase Postgres - completed and manually validated
   * create admin route group and base layout - started

2. Admin authentication
   * implement admin login/logout - available from starter kit
   * implement admin session guard - available from starter kit
   * protect admin routes - completed with `admin` middleware
   * decide admin identity storage - selected local Laravel admin users table for MVP

3. Store moderation
   * list pending/active/suspended stores - implemented
   * view store detail and owner context - implemented
   * approve, suspend, and unsuspend store - implemented
   * record admin reason and audit entry

4. Product moderation
   * list products with store/category/status context - implemented
   * view product detail and image - implemented
   * prepare hide/unhide or moderation flag flow - archive/restore implemented

5. Order/payment lookup
   * list orders - implemented
   * view order detail - implemented
   * view payment status and provider transaction reference - implemented
   * keep mutation read-only until manual case tracking exists - implemented

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

No Laravel app scaffold blocker currently.

Current admin environment blocker:

No local environment or Supabase credential blocker currently.

Current admin auth blocker:

No admin identity model blocker currently. MVP uses local Laravel admin users with `is_admin`.

Current moderation blocker:

Admin-specific audit/moderation schema has not been implemented yet, so moderation reason/audit trail is still pending.

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
* Laravel admin app installed under `admin/`
* Laravel React starter kit with Inertia/Fortify available
* local Laravel admin users table selected for admin identity
* admin guard implemented through `users.is_admin`
* admin dashboard, store moderation, product moderation, and order/payment lookup pages implemented
* Laravel admin login and marketplace data access manually validated
* store approve/suspend/unsuspend UI context polished
* confirmed MVP-first admin scope
* confirmed Supabase as shared database/source of truth
* confirmed initial priority: admin foundation, auth, store moderation, product moderation, order/payment lookup
* Laravel admin MVP domain implementation has started
* admin-specific `is_admin` migration added
* audit/moderation reason schema still pending

Implementation harus melanjutkan dari browser QA, audit trail, moderation reason schema, dan manual refund/cancellation case tracking, bukan dari Flutter mobile app.
