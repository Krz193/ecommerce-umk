<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use Illuminate\Support\Facades\DB;
use Inertia\Inertia;
use Inertia\Response;

class DashboardController extends Controller
{
    public function __invoke(): Response
    {
        $db = DB::connection('marketplace');

        return Inertia::render('dashboard', [
            'metrics' => [
                'stores_pending' => $db->table('stores')->where('status', 'pending')->count(),
                'stores_active' => $db->table('stores')->where('status', 'active')->count(),
                'products_published' => $db->table('products')->where('status', 'published')->count(),
                'orders_processing' => $db->table('orders')->where('status', 'processing')->count(),
                'payments_pending' => $db->table('payments')->where('status', 'pending')->count(),
                'payments_paid' => $db->table('payments')->where('status', 'paid')->count(),
            ],
            'recentStores' => $db->table('stores')
                ->select(['id', 'name', 'status', 'phone', 'created_at'])
                ->orderByDesc('created_at')
                ->limit(5)
                ->get(),
            'recentOrders' => $db->table('orders')
                ->join('stores', 'stores.id', '=', 'orders.store_id')
                ->select([
                    'orders.id',
                    'orders.order_number',
                    'orders.status',
                    'orders.payment_status',
                    'orders.total_amount',
                    'orders.created_at',
                    'stores.name as store_name',
                ])
                ->orderByDesc('orders.created_at')
                ->limit(5)
                ->get(),
        ]);
    }
}
