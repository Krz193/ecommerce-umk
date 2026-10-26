<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Inertia\Inertia;
use Inertia\Response;

class ReportController extends Controller
{
    public function index(Request $request): Response
    {
        // Filters apply to the shipping (Ekspedisi) and donation reports only.
        $filters = $request->validate([
            'date_from' => ['nullable', 'date'],
            'date_to' => ['nullable', 'date', 'after_or_equal:date_from'],
            'store_id' => ['nullable', 'uuid'],
            'courier_code' => ['nullable', 'string', 'max:50'],
            'order_status' => ['nullable', 'string', 'max:50'],
            'donation_status' => ['nullable', 'in:paid,distributed,cancelled'],
        ]);

        $db = DB::connection('marketplace');

        // 1. Store & Sales Reports (Excel A14, A16, A17)
        $storeReports = $db->table('stores')
            ->leftJoin('products', 'products.store_id', '=', 'stores.id')
            ->leftJoin('orders', 'orders.store_id', '=', 'stores.id')
            ->select([
                'stores.id',
                'stores.name',
                'stores.status',
                DB::raw('count(distinct products.id) as product_count'),
                DB::raw("count(distinct case when products.status = 'published' then products.id end) as published_product_count"),
                DB::raw('count(distinct orders.id) as order_count'),
                DB::raw('count(distinct orders.user_id) as buyer_count'),
                DB::raw("coalesce(sum(case when orders.payment_status = 'paid' then orders.total_amount else 0 end), 0) as paid_revenue"),
            ])
            ->groupBy('stores.id', 'stores.name', 'stores.status')
            ->orderByDesc('paid_revenue')
            ->limit(20)
            ->get();

        // 2. Stock Health Reports (Excel A15)
        $stockReports = $db->table('products')
            ->join('stores', 'stores.id', '=', 'products.store_id')
            ->leftJoin('categories', 'categories.id', '=', 'products.category_id')
            ->select([
                'products.id',
                'products.name',
                'products.status',
                'products.stock',
                'products.price',
                'stores.name as store_name',
                'categories.name as category_name',
            ])
            ->where('products.stock', '<=', 10)
            ->orderBy('products.stock')
            ->limit(20)
            ->get();

        // 3. Shipping & Logistics Reports per UMK (Excel A18)
        $shippingReports = $db->table('orders')
            ->join('stores', 'stores.id', '=', 'orders.store_id')
            ->select([
                'stores.id as store_id',
                'stores.name as store_name',
                DB::raw("coalesce(orders.courier_name, 'JNE Reguler') as courier_name"),
                DB::raw('count(orders.id) as total_shipments'),
                DB::raw("count(case when orders.status in ('shipped', 'completed') then 1 end) as shipped_count"),
                DB::raw("count(case when orders.status = 'completed' then 1 end) as delivered_count"),
                DB::raw('coalesce(sum(orders.shipping_cost), 0) as total_shipping_fee'),
            ])
            ->whereNotNull('orders.store_id')
            ->when($filters['date_from'] ?? null, fn ($q, $v) => $q->whereDate('orders.created_at', '>=', $v))
            ->when($filters['date_to'] ?? null, fn ($q, $v) => $q->whereDate('orders.created_at', '<=', $v))
            ->when($filters['store_id'] ?? null, fn ($q, $v) => $q->where('orders.store_id', $v))
            ->when($filters['courier_code'] ?? null, fn ($q, $v) => $q->where('orders.courier_code', $v))
            ->when($filters['order_status'] ?? null, fn ($q, $v) => $q->where('orders.status', $v))
            ->groupBy('stores.id', 'stores.name', DB::raw("coalesce(orders.courier_name, 'JNE Reguler')"))
            ->orderByDesc('total_shipments')
            ->limit(25)
            ->get();

        // 4. Assistant UMK Activity & Mentoring Reports (Excel A19)
        $assistantReports = $db->table('store_assistants')
            ->join('users', 'users.id', '=', 'store_assistants.user_id')
            ->join('stores', 'stores.id', '=', 'store_assistants.store_id')
            ->leftJoin('assistance_logs', 'assistance_logs.assistant_id', '=', 'users.id')
            ->leftJoin('store_contents', 'store_contents.store_id', '=', 'stores.id')
            ->select([
                'users.id as assistant_id',
                'users.full_name as assistant_name',
                'users.phone as assistant_phone',
                'stores.id as store_id',
                'stores.name as store_name',
                'store_assistants.created_at as assigned_at',
                DB::raw('count(distinct assistance_logs.id) as total_logs'),
                DB::raw('count(distinct store_contents.id) as total_contents_created'),
            ])
            ->groupBy('users.id', 'users.full_name', 'users.phone', 'stores.id', 'stores.name', 'store_assistants.created_at')
            ->orderByDesc('total_logs')
            ->limit(20)
            ->get();

        // 5. Donation Reports per UMK (Excel A20)
        $donationReports = $db->table('donations')
            ->join('stores', 'stores.id', '=', 'donations.store_id')
            ->select([
                'stores.id as store_id',
                'stores.name as store_name',
                DB::raw('count(donations.id) as total_donors'),
                DB::raw("coalesce(sum(case when donations.status in ('paid', 'distributed') then donations.amount else 0 end), 0) as total_donations_collected"),
                DB::raw("coalesce(sum(case when donations.status = 'distributed' then coalesce(donations.distributed_amount, donations.amount) else 0 end), 0) as total_distributed_amount"),
                DB::raw("coalesce(sum(case when donations.status = 'paid' then donations.amount else 0 end), 0) as pending_distribution_amount"),
                DB::raw("max(donations.created_at) as last_donation_at"),
                DB::raw("max(donations.distributed_at) as last_distributed_at"),
            ])
            ->when($filters['date_from'] ?? null, fn ($q, $v) => $q->whereDate('donations.created_at', '>=', $v))
            ->when($filters['date_to'] ?? null, fn ($q, $v) => $q->whereDate('donations.created_at', '<=', $v))
            ->when($filters['store_id'] ?? null, fn ($q, $v) => $q->where('donations.store_id', $v))
            ->when($filters['donation_status'] ?? null, fn ($q, $v) => $q->where('donations.status', $v))
            ->groupBy('stores.id', 'stores.name')
            ->orderByDesc('total_donations_collected')
            ->limit(20)
            ->get();

        return Inertia::render('admin/reports/index', [
            'storeReports' => $storeReports,
            'stockReports' => $stockReports,
            'shippingReports' => $shippingReports,
            'assistantReports' => $assistantReports,
            'donationReports' => $donationReports,
            'filters' => [
                'date_from' => $filters['date_from'] ?? '',
                'date_to' => $filters['date_to'] ?? '',
                'store_id' => $filters['store_id'] ?? '',
                'courier_code' => $filters['courier_code'] ?? '',
                'order_status' => $filters['order_status'] ?? '',
                'donation_status' => $filters['donation_status'] ?? '',
            ],
            'filterOptions' => [
                'stores' => $db->table('stores')->orderBy('name')->get(['id', 'name']),
                'couriers' => $db->table('orders')->whereNotNull('courier_code')->distinct()->orderBy('courier_code')->pluck('courier_code'),
            ],
            'financeSummary' => [
                'paid_revenue' => (float)$db->table('orders')->where('payment_status', 'paid')->sum('total_amount'),
                'application_fee' => (float)$db->table('orders')->where('payment_status', 'paid')->sum('application_fee'),
                'total_shipping' => (float)$db->table('orders')->where('payment_status', 'paid')->sum('shipping_cost'),
                'total_donations' => (float)$db->table('donations')->whereIn('status', ['paid', 'distributed'])->sum('amount'),
                'paid_orders' => $db->table('orders')->where('payment_status', 'paid')->count(),
                'pending_payments' => $db->table('orders')->where('payment_status', 'pending')->count(),
            ],
            'storeSummary' => [
                'total' => $db->table('stores')->count(),
                'active' => $db->table('stores')->where('status', 'active')->count(),
                'pending' => $db->table('stores')->where('status', 'pending')->count(),
                'suspended' => $db->table('stores')->where('status', 'suspended')->count(),
            ],
        ]);
    }
}
