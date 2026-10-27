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
            ->leftJoin('auth.users as au', 'au.id', '=', 'users.id')
            ->select([
                'users.id',
                'users.full_name',
                'users.username',
                'users.phone',
                'users.role',
                'users.created_at',
                'au.email',
                'au.last_sign_in_at',
            ])
            ->when($role !== '', fn ($query) => $query->where('users.role', $role))
            ->when($search !== '', function ($query) use ($search): void {
                $query->where(function ($query) use ($search): void {
                    $query->where('users.full_name', 'ilike', "%{$search}%")
                        ->orWhere('users.username', 'ilike', "%{$search}%")
                        ->orWhere('users.phone', 'ilike', "%{$search}%")
                        ->orWhere('au.email', 'ilike', "%{$search}%");
                });
            })
            ->orderByDesc('users.created_at')
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
            ->leftJoin('auth.users as au', 'au.id', '=', 'users.id')
            ->select([
                'users.id',
                'users.full_name',
                'users.username',
                'users.phone',
                'users.avatar_url',
                'users.role',
                'users.created_at',
                'users.updated_at',
                'au.email',
                'au.last_sign_in_at',
                'au.email_confirmed_at',
            ])
            ->where('users.id', $user)
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
            'email' => ['required', 'string', 'email', 'max:255'],
            'password' => ['required', 'string', 'min:6', 'max:255'],
            'username' => ['nullable', 'string', 'max:255'],
            'phone' => ['nullable', 'string', 'max:50'],
            'role' => ['required', 'string', 'in:buyer,seller,assistant,ekspedisi,ojek,admin'],
        ]);

        $db = DB::connection('marketplace');
        $email = strtolower(trim($validated['email']));
        $username = filled($validated['username'] ?? null)
            ? trim($validated['username'])
            : explode('@', $email)[0];

        $emailExists = $db->table('auth.users')
            ->whereRaw('LOWER(email) = ?', [$email])
            ->exists();
        if ($emailExists) {
            return back()->withErrors(['email' => 'Email login sudah digunakan.']);
        }

        if (filled($username)) {
            $exists = $db->table('users')->where('username', $username)->exists();
            if ($exists) {
                return back()->withErrors(['username' => 'Username sudah digunakan.']);
            }
        }

        $id = (string) Str::uuid();
        $now = now();
        $encryptedPassword = str_replace(
            '$2y$',
            '$2a$',
            password_hash($validated['password'], PASSWORD_BCRYPT, ['cost' => 10]),
        );

        $userMeta = json_encode([
            'sub' => $id,
            'email' => $email,
            'username' => $username,
            'full_name' => $validated['full_name'],
            'email_verified' => true,
            'phone_verified' => false,
        ]);

        $db->transaction(function () use ($db, $id, $email, $encryptedPassword, $userMeta, $validated, $username, $now): void {
            $db->table('auth.users')->insert([
                'instance_id' => '00000000-0000-0000-0000-000000000000',
                'id' => $id,
                'aud' => 'authenticated',
                'role' => 'authenticated',
                'email' => $email,
                'encrypted_password' => $encryptedPassword,
                'email_confirmed_at' => $now,
                'confirmation_token' => '',
                'recovery_token' => '',
                'email_change_token_new' => '',
                'email_change' => '',
                'phone_change' => '',
                'phone_change_token' => '',
                'email_change_token_current' => '',
                'email_change_confirm_status' => 0,
                'reauthentication_token' => '',
                'raw_app_meta_data' => json_encode(['provider' => 'email', 'providers' => ['email']]),
                'raw_user_meta_data' => $userMeta,
                'is_sso_user' => false,
                'is_anonymous' => false,
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            $db->table('auth.identities')->insert([
                'id' => (string) Str::uuid(),
                'user_id' => $id,
                'provider_id' => $id,
                'identity_data' => $userMeta,
                'provider' => 'email',
                'last_sign_in_at' => $now,
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            $db->table('users')->updateOrInsert(
                ['id' => $id],
                [
                    'full_name' => $validated['full_name'],
                    'username' => $username ?: null,
                    'phone' => $validated['phone'] ?? null,
                    'role' => $validated['role'],
                    'created_at' => $now,
                    'updated_at' => $now,
                ],
            );
        });

        $auditLogger->log(
            $request,
            'user.create',
            'user',
            $id,
            "User {$validated['full_name']} ({$email}) dibuat dengan role {$validated['role']}.",
            [
                'full_name' => $validated['full_name'],
                'email' => $email,
                'role' => $validated['role'],
            ],
        );

        return back()->with('success', 'User dan kredensial login berhasil ditambahkan.');
    }

    public function update(Request $request, AdminAuditLogger $auditLogger, string $user): RedirectResponse
    {
        $validated = $request->validate([
            'full_name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'string', 'email', 'max:255'],
            'password' => ['nullable', 'string', 'min:6', 'max:255'],
            'username' => ['nullable', 'string', 'max:255'],
            'phone' => ['nullable', 'string', 'max:50'],
            'role' => ['required', 'string', 'in:buyer,seller,assistant,ekspedisi,ojek,admin'],
        ]);

        $db = DB::connection('marketplace');
        $existing = $db->table('users')->where('id', $user)->firstOrFail();
        $email = strtolower(trim($validated['email']));
        $username = filled($validated['username'] ?? null) ? trim($validated['username']) : null;

        $emailExists = $db->table('auth.users')
            ->whereRaw('LOWER(email) = ?', [$email])
            ->where('id', '!=', $user)
            ->exists();

        if ($emailExists) {
            return back()->withErrors(['email' => 'Email login sudah digunakan oleh user lain.']);
        }

        if (filled($username)) {
            $usernameExists = $db->table('users')
                ->where('username', $username)
                ->where('id', '!=', $user)
                ->exists();

            if ($usernameExists) {
                return back()->withErrors(['username' => 'Username sudah digunakan oleh user lain.']);
            }
        }

        $now = now();
        $passwordChanged = filled($validated['password'] ?? null);

        $db->transaction(function () use ($db, $user, $validated, $email, $username, $now, $passwordChanged): void {
            $db->table('users')->where('id', $user)->update([
                'full_name' => $validated['full_name'],
                'username' => $username,
                'phone' => $validated['phone'] ?? null,
                'role' => $validated['role'],
                'updated_at' => $now,
            ]);

            $userMeta = json_encode([
                'sub' => $user,
                'email' => $email,
                'username' => $username ?? explode('@', $email)[0],
                'full_name' => $validated['full_name'],
                'email_verified' => true,
                'phone_verified' => false,
            ]);

            $authUpdate = [
                'email' => $email,
                'raw_user_meta_data' => $userMeta,
                'updated_at' => $now,
            ];

            if ($passwordChanged) {
                $authUpdate['encrypted_password'] = str_replace(
                    '$2y$',
                    '$2a$',
                    password_hash($validated['password'], PASSWORD_BCRYPT, ['cost' => 10]),
                );
                $authUpdate['email_confirmed_at'] = $now;
            }

            $db->table('auth.users')->where('id', $user)->update($authUpdate);

            $db->table('auth.identities')
                ->where('user_id', $user)
                ->where('provider', 'email')
                ->update([
                    'identity_data' => $userMeta,
                    'updated_at' => $now,
                ]);
        });

        $auditLogger->log(
            $request,
            'user.update',
            'user',
            $user,
            "User {$validated['full_name']} ({$email}) diperbarui (role: {$existing->role} -> {$validated['role']}).",
            [
                'previous_role' => $existing->role,
                'role' => $validated['role'],
                'full_name' => $validated['full_name'],
                'email' => $email,
                'password_changed' => $passwordChanged,
            ],
        );

        return back()->with('success', 'Profil & kredensial login user berhasil diperbarui.');
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

        $db->transaction(function () use ($db, $user): void {
            $db->table('users')->where('id', $user)->delete();
            $db->table('auth.users')->where('id', $user)->delete();
        });

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
