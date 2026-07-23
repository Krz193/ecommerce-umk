<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use Illuminate\Support\Facades\DB;
use Inertia\Inertia;
use Inertia\Response;

class ReportController extends Controller
{
    public function index(): Response
    {
        $db = DB::connection('marketplace');

        return Inertia::render('admin/reports/index', [
            'storeReports' => $db->table('stores')
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
                ->get(),
            'stockReports' => $db->table('products')
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
                ->where('products.stock', '<=', 5)
                ->orderBy('products.stock')
                ->limit(20)
                ->get(),
            'financeSummary' => [
                'paid_revenue' => $db->table('orders')->where('payment_status', 'paid')->sum('total_amount'),
                'application_fee' => $db->table('orders')->where('payment_status', 'paid')->sum('application_fee'),
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
