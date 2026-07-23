<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Services\AdminAuditLogger;
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
            'assistant' => $db->table('store_assistants')
                ->join('users', 'users.id', '=', 'store_assistants.user_id')
                ->select([
                    'users.id',
                    'users.full_name',
                    'users.phone',
                    'users.role',
                    'store_assistants.assigned_at',
                ])
                ->where('store_assistants.store_id', $store)
                ->first(),
            'candidateUsers' => $db->table('users')
                ->select(['id', 'full_name', 'phone', 'role'])
                ->whereIn('role', ['buyer', 'assistant'])
                ->orderBy('full_name')
                ->limit(100)
                ->get(),
        ]);
    }

    public function approve(Request $request, AdminAuditLogger $auditLogger, string $store): RedirectResponse
    {
        $db = DB::connection('marketplace');
        $previous = $db->table('stores')->where('id', $store)->firstOrFail();
        $isUnsuspend = $previous->status === 'suspended';

        $db->table('stores')->where('id', $store)
            ->update([
                'status' => 'active',
                'suspended_at' => null,
                'updated_at' => now(),
            ]);

        $auditLogger->log(
            $request,
            $isUnsuspend ? 'store.unsuspend' : 'store.approve',
            'store',
            $store,
            $isUnsuspend ? 'Store unsuspended by admin.' : 'Store approved by admin.',
            [
                'previous_status' => $previous->status,
                'next_status' => 'active',
                'store_name' => $previous->name,
            ],
        );

        return back()->with('success', 'Store approved.');
    }

    public function suspend(Request $request, AdminAuditLogger $auditLogger, string $store): RedirectResponse
    {
        $validated = $request->validate([
            'reason' => ['required', 'string', 'min:3', 'max:1000'],
        ]);

        $db = DB::connection('marketplace');
        $previous = $db->table('stores')->where('id', $store)->firstOrFail();

        $db->table('stores')->where('id', $store)
            ->update([
                'status' => 'suspended',
                'suspended_at' => now(),
                'updated_at' => now(),
            ]);

        $auditLogger->log(
            $request,
            'store.suspend',
            'store',
            $store,
            $validated['reason'],
            [
                'previous_status' => $previous->status,
                'next_status' => 'suspended',
                'store_name' => $previous->name,
            ],
        );

        return back()->with('success', 'Store suspended.');
    }

    public function assignAssistant(Request $request, AdminAuditLogger $auditLogger, string $store): RedirectResponse
    {
        $validated = $request->validate([
            'user_id' => ['required', 'string', 'uuid'],
        ]);

        $db = DB::connection('marketplace');
        $storeRow = $db->table('stores')->where('id', $store)->firstOrFail();
        $userRow = $db->table('users')->where('id', $validated['user_id'])->firstOrFail();

        if ($userRow->role === 'buyer') {
            $db->table('users')->where('id', $userRow->id)->update([
                'role' => 'assistant',
                'updated_at' => now(),
            ]);
        }

        // Delete any existing assistant assignment for this store (since 1 store can only have 1 assistant)
        $db->table('store_assistants')
            ->where('store_id', $store)
            ->delete();

        $db->table('store_assistants')->insert([
            'store_id' => $store,
            'user_id' => $userRow->id,
            'assigned_by' => $userRow->id,
            'assigned_at' => now(),
            'created_at' => now(),
        ]);

        $auditLogger->log(
            $request,
            'store.assistant_assigned',
            'store',
            $store,
            "Assigned assistant {$userRow->full_name} to store {$storeRow->name}.",
            [
                'store_name' => $storeRow->name,
                'assistant_id' => $userRow->id,
                'assistant_name' => $userRow->full_name,
            ],
        );

        return back()->with('success', 'Asisten UMK berhasil ditugaskan ke toko.');
    }

    public function removeAssistant(Request $request, AdminAuditLogger $auditLogger, string $store, string $user): RedirectResponse
    {
        $db = DB::connection('marketplace');
        $storeRow = $db->table('stores')->where('id', $store)->firstOrFail();
        $userRow = $db->table('users')->where('id', $user)->firstOrFail();

        $db->table('store_assistants')
            ->where('store_id', $store)
            ->where('user_id', $user)
            ->delete();

        $auditLogger->log(
            $request,
            'store.assistant_removed',
            'store',
            $store,
            "Removed assistant {$userRow->full_name} from store {$storeRow->name}.",
            [
                'store_name' => $storeRow->name,
                'assistant_id' => $userRow->id,
            ],
        );

        return back()->with('success', 'Penugasan Asisten UMK berhasil dihapus.');
    }
}
