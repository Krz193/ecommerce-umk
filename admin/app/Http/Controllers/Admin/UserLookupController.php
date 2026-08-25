<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Services\AdminAuditLogger;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
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

    public function store(Request $request, AdminAuditLogger $auditLogger): RedirectResponse
    {
        $validated = $request->validate([
            'full_name' => ['required', 'string', 'max:255'],
            'username' => ['nullable', 'string', 'max:255'],
            'phone' => ['nullable', 'string', 'max:50'],
            'role' => ['required', 'string', 'in:buyer,seller,assistant,admin'],
        ]);

        $db = DB::connection('marketplace');

        if (filled($validated['username'] ?? null)) {
            $exists = $db->table('users')->where('username', $validated['username'])->exists();
            if ($exists) {
                return back()->withErrors(['username' => 'Username sudah digunakan.']);
            }
        }

        $id = (string) Str::uuid();

        $db->table('users')->insert([
            'id' => $id,
            'full_name' => $validated['full_name'],
            'username' => $validated['username'] ?? null,
            'phone' => $validated['phone'] ?? null,
            'role' => $validated['role'],
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $auditLogger->log(
            $request,
            'user.create',
            'user',
            $id,
            "User {$validated['full_name']} dibuat secara manual dengan role {$validated['role']}.",
            [
                'full_name' => $validated['full_name'],
                'role' => $validated['role'],
            ],
        );

        return back()->with('success', 'User berhasil ditambahkan.');
    }

    public function update(Request $request, AdminAuditLogger $auditLogger, string $user): RedirectResponse
    {
        $validated = $request->validate([
            'full_name' => ['required', 'string', 'max:255'],
            'username' => ['nullable', 'string', 'max:255'],
            'phone' => ['nullable', 'string', 'max:50'],
            'role' => ['required', 'string', 'in:buyer,seller,assistant,admin'],
        ]);

        $db = DB::connection('marketplace');
        $existing = $db->table('users')->where('id', $user)->firstOrFail();

        if (filled($validated['username'] ?? null)) {
            $usernameExists = $db->table('users')
                ->where('username', $validated['username'])
                ->where('id', '!=', $user)
                ->exists();

            if ($usernameExists) {
                return back()->withErrors(['username' => 'Username sudah digunakan oleh user lain.']);
            }
        }

        $db->table('users')->where('id', $user)->update([
            'full_name' => $validated['full_name'],
            'username' => $validated['username'] ?? null,
            'phone' => $validated['phone'] ?? null,
            'role' => $validated['role'],
            'updated_at' => now(),
        ]);

        $auditLogger->log(
            $request,
            'user.update',
            'user',
            $user,
            "User {$validated['full_name']} diperbarui (role: {$existing->role} -> {$validated['role']}).",
            [
                'previous_role' => $existing->role,
                'role' => $validated['role'],
                'full_name' => $validated['full_name'],
            ],
        );

        return back()->with('success', 'Informasi user berhasil diperbarui.');
    }

    public function destroy(Request $request, AdminAuditLogger $auditLogger, string $user): RedirectResponse
    {
        $db = DB::connection('marketplace');
        $existing = $db->table('users')->where('id', $user)->firstOrFail();

        $storesCount = $db->table('stores')->where('owner_id', $user)->count();
        $ordersCount = $db->table('orders')->where('user_id', $user)->count();

        if ($storesCount > 0 || $ordersCount > 0) {
            return back()->withErrors([
                'user' => "User tidak dapat dihapus karena memiliki {$storesCount} toko dan {$ordersCount} transaksi terhubung.",
            ]);
        }

        $db->table('users')->where('id', $user)->delete();

        $auditLogger->log(
            $request,
            'user.delete',
            'user',
            $user,
            "User {$existing->full_name} ({$existing->role}) dihapus permanen.",
            ['full_name' => $existing->full_name],
        );

        return back()->with('success', 'User berhasil dihapus.');
    }
}
