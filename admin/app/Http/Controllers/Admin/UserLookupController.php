<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Inertia\Inertia;
use Inertia\Response;

class UserLookupController extends Controller
{
    public function index(Request $request): Response
    {
        $role = $request->string('role')->toString();
        $search = $request->string('search')->toString();

        $users = DB::connection('marketplace')
            ->table('users')
            ->select(['id', 'full_name', 'username', 'phone', 'role', 'created_at'])
            ->when($role !== '', fn ($query) => $query->where('role', $role))
            ->when($search !== '', function ($query) use ($search): void {
                $query->where(function ($query) use ($search): void {
                    $query->where('full_name', 'ilike', "%{$search}%")
                        ->orWhere('username', 'ilike', "%{$search}%")
                        ->orWhere('phone', 'ilike', "%{$search}%");
                });
            })
            ->orderByDesc('created_at')
            ->paginate(20)
            ->withQueryString();

        return Inertia::render('admin/users/index', [
            'users' => $users,
            'filters' => [
                'role' => $role,
                'search' => $search,
            ],
        ]);
    }

    public function show(string $user): Response
    {
        $db = DB::connection('marketplace');

        $userRow = $db->table('users')
            ->select(['id', 'full_name', 'username', 'phone', 'avatar_url', 'role', 'created_at', 'updated_at'])
            ->where('id', $user)
            ->firstOrFail();

        return Inertia::render('admin/users/show', [
            'user' => $userRow,
            'stores' => $db->table('stores')
                ->select(['id', 'name', 'slug', 'status', 'created_at'])
                ->where('owner_id', $user)
                ->orderByDesc('created_at')
                ->get(),
            'orders' => $db->table('orders')
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
                ->where('orders.user_id', $user)
                ->orderByDesc('orders.created_at')
                ->limit(10)
                ->get(),
        ]);
    }
}
