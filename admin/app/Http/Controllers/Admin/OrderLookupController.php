<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Inertia\Inertia;
use Inertia\Response;

class OrderLookupController extends Controller
{
    public function index(Request $request): Response
    {
        $status = $request->string('status')->toString();
        $paymentStatus = $request->string('payment_status')->toString();
        $search = $request->string('search')->toString();

        $orders = DB::connection('marketplace')
            ->table('orders')
            ->join('stores', 'stores.id', '=', 'orders.store_id')
            ->leftJoin('payments', 'payments.order_id', '=', 'orders.id')
            ->select([
                'orders.id',
                'orders.order_number',
                'orders.status',
                'orders.payment_status',
                'orders.total_amount',
                'orders.shipping_name',
                'orders.created_at',
                'stores.name as store_name',
                'payments.provider',
                'payments.provider_transaction_id',
            ])
            ->when($status !== '', fn ($query) => $query->where('orders.status', $status))
            ->when($paymentStatus !== '', fn ($query) => $query->where('orders.payment_status', $paymentStatus))
            ->when($search !== '', function ($query) use ($search): void {
                $query->where(function ($query) use ($search): void {
                    $query->where('orders.order_number', 'ilike', "%{$search}%")
                        ->orWhere('orders.shipping_name', 'ilike', "%{$search}%")
                        ->orWhere('stores.name', 'ilike', "%{$search}%");
                });
            })
            ->orderByDesc('orders.created_at')
            ->paginate(20)
            ->withQueryString();

        return Inertia::render('admin/orders/index', [
            'orders' => $orders,
            'filters' => [
                'status' => $status,
                'payment_status' => $paymentStatus,
                'search' => $search,
            ],
        ]);
    }

    public function show(string $order): Response
    {
        $db = DB::connection('marketplace');

        $orderRow = $db->table('orders')
            ->join('stores', 'stores.id', '=', 'orders.store_id')
            ->leftJoin('users as buyers', 'buyers.id', '=', 'orders.user_id')
            ->leftJoin('payments', 'payments.order_id', '=', 'orders.id')
            ->select([
                'orders.*',
                'stores.name as store_name',
                'buyers.full_name as buyer_name',
                'buyers.phone as buyer_phone',
                'payments.provider',
                'payments.provider_transaction_id',
                'payments.status as provider_status',
                'payments.amount as payment_amount',
                'payments.paid_at as payment_paid_at',
                'payments.expired_at as payment_expired_at',
            ])
            ->where('orders.id', $order)
            ->firstOrFail();

        return Inertia::render('admin/orders/show', [
            'order' => $orderRow,
            'items' => $db->table('order_items')
                ->select(['product_name', 'product_price', 'quantity', 'subtotal', 'product_thumbnail'])
                ->where('order_id', $order)
                ->get(),
        ]);
    }
}
