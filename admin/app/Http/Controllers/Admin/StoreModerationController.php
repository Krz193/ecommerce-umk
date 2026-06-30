<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Inertia\Inertia;
use Inertia\Response;

class StoreModerationController extends Controller
{
    public function index(Request $request): Response
    {
        $status = $request->string('status')->toString();
        $search = $request->string('search')->toString();

        $stores = DB::connection('marketplace')
            ->table('stores')
            ->leftJoin('users as owners', 'owners.id', '=', 'stores.owner_id')
            ->select([
                'stores.id',
                'stores.name',
                'stores.slug',
                'stores.status',
                'stores.phone',
                'stores.address',
                'stores.created_at',
                'stores.suspended_at',
                'owners.full_name as owner_name',
                'owners.phone as owner_phone',
            ])
            ->when($status !== '', fn ($query) => $query->where('stores.status', $status))
            ->when($search !== '', function ($query) use ($search): void {
                $query->where(function ($query) use ($search): void {
                    $query->where('stores.name', 'ilike', "%{$search}%")
                        ->orWhere('stores.slug', 'ilike', "%{$search}%")
                        ->orWhere('owners.full_name', 'ilike', "%{$search}%");
                });
            })
            ->orderByDesc('stores.created_at')
            ->paginate(20)
            ->withQueryString();

        return Inertia::render('admin/stores/index', [
            'stores' => $stores,
            'filters' => [
                'status' => $status,
                'search' => $search,
            ],
        ]);
    }

    public function show(string $store): Response
    {
        $db = DB::connection('marketplace');

        $storeRow = $db->table('stores')
            ->leftJoin('users as owners', 'owners.id', '=', 'stores.owner_id')
            ->select([
                'stores.*',
                'owners.full_name as owner_name',
                'owners.phone as owner_phone',
                'owners.username as owner_username',
            ])
            ->where('stores.id', $store)
            ->firstOrFail();

        return Inertia::render('admin/stores/show', [
            'store' => $storeRow,
            'metrics' => [
                'products' => $db->table('products')->where('store_id', $store)->count(),
                'published_products' => $db->table('products')->where('store_id', $store)->where('status', 'published')->count(),
                'orders' => $db->table('orders')->where('store_id', $store)->count(),
                'processing_orders' => $db->table('orders')->where('store_id', $store)->where('status', 'processing')->count(),
            ],
            'recentProducts' => $db->table('products')
                ->leftJoin('categories', 'categories.id', '=', 'products.category_id')
                ->select([
                    'products.id',
                    'products.name',
                    'products.status',
                    'products.price',
                    'products.stock',
                    'products.thumbnail_url',
                    'categories.name as category_name',
                ])
                ->where('products.store_id', $store)
                ->orderByDesc('products.created_at')
                ->limit(8)
                ->get(),
        ]);
    }

    public function approve(string $store): RedirectResponse
    {
        DB::connection('marketplace')
            ->table('stores')
            ->where('id', $store)
            ->update([
                'status' => 'active',
                'suspended_at' => null,
                'updated_at' => now(),
            ]);

        return back()->with('success', 'Store approved.');
    }

    public function suspend(string $store): RedirectResponse
    {
        DB::connection('marketplace')
            ->table('stores')
            ->where('id', $store)
            ->update([
                'status' => 'suspended',
                'suspended_at' => now(),
                'updated_at' => now(),
            ]);

        return back()->with('success', 'Store suspended.');
    }
}
