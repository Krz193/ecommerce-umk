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

class RoleController extends Controller
{
    public function index(): Response
    {
        $db = DB::connection('marketplace');

        $roles = $db->table('roles')
            ->select(['id', 'name', 'slug', 'description', 'is_system', 'created_at'])
            ->orderBy('is_system', 'desc')
            ->orderBy('name')
            ->get();

        $permissions = $db->table('permissions')
            ->select(['id', 'name', 'slug', 'category', 'created_at'])
            ->orderBy('category')
            ->orderBy('name')
            ->get();

        $rolePermissions = $db->table('role_permissions')
            ->select(['role_id', 'permission_id'])
            ->get();

        // Map permission IDs per role ID for fast frontend checkbox rendering
        $mappedRolePermissions = [];
        foreach ($rolePermissions as $rp) {
            $mappedRolePermissions[$rp->role_id][] = $rp->permission_id;
        }

        $userRolesCount = $db->table('user_roles')
            ->select('role_id', DB::raw('count(*) as count'))
            ->groupBy('role_id')
            ->pluck('count', 'role_id')
            ->toArray();

        return Inertia::render('admin/roles/index', [
            'roles' => $roles,
            'permissions' => $permissions,
            'rolePermissionsMap' => $mappedRolePermissions,
            'userRolesCount' => $userRolesCount,
        ]);
    }

    public function store(Request $request, AdminAuditLogger $auditLogger): RedirectResponse
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'slug' => ['nullable', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'permission_ids' => ['array'],
            'permission_ids.*' => ['string', 'uuid'],
        ]);

        $slug = filled($validated['slug'] ?? null)
            ? Str::slug($validated['slug'])
            : Str::slug($validated['name']);

        $db = DB::connection('marketplace');

        $exists = $db->table('roles')->where('slug', $slug)->exists();
        if ($exists) {
            return back()->withErrors(['slug' => 'Slug role sudah digunakan.']);
        }

        $roleId = (string) Str::uuid();

        $db->table('roles')->insert([
            'id' => $roleId,
            'name' => $validated['name'],
            'slug' => $slug,
            'description' => $validated['description'] ?? null,
            'is_system' => false,
            'created_at' => now(),
        ]);

        if (! empty($validated['permission_ids'] ?? [])) {
            $insertRows = array_map(fn ($permId) => [
                'role_id' => $roleId,
                'permission_id' => $permId,
            ], $validated['permission_ids']);

            $db->table('role_permissions')->insert($insertRows);
        }

        $auditLogger->log(
            $request,
            'role.create',
            'role',
            $roleId,
            "Role dinamis {$validated['name']} dibuat dengan " . count($validated['permission_ids'] ?? []) . " permission.",
            [
                'name' => $validated['name'],
                'slug' => $slug,
                'permissions_count' => count($validated['permission_ids'] ?? []),
            ],
        );

        return back()->with('success', 'Role dinamis berhasil dibuat.');
    }

    public function update(Request $request, AdminAuditLogger $auditLogger, string $role): RedirectResponse
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'permission_ids' => ['array'],
            'permission_ids.*' => ['string', 'uuid'],
        ]);

        $db = DB::connection('marketplace');
        $existing = $db->table('roles')->where('id', $role)->firstOrFail();

        $db->table('roles')->where('id', $role)->update([
            'name' => $validated['name'],
            'description' => $validated['description'] ?? null,
        ]);

        // Sync role_permissions
        $db->table('role_permissions')->where('role_id', $role)->delete();

        if (! empty($validated['permission_ids'] ?? [])) {
            $insertRows = array_map(fn ($permId) => [
                'role_id' => $role,
                'permission_id' => $permId,
            ], $validated['permission_ids']);

            $db->table('role_permissions')->insert($insertRows);
        }

        $auditLogger->log(
            $request,
            'role.update',
            'role',
            $role,
            "Permission role {$validated['name']} diperbarui (" . count($validated['permission_ids'] ?? []) . " permission aktif).",
            [
                'role_name' => $validated['name'],
                'permissions_count' => count($validated['permission_ids'] ?? []),
            ],
        );

        return back()->with('success', 'Hak akses role berhasil diperbarui.');
    }

    public function destroy(Request $request, AdminAuditLogger $auditLogger, string $role): RedirectResponse
    {
        $db = DB::connection('marketplace');
        $existing = $db->table('roles')->where('id', $role)->firstOrFail();

        if ($existing->is_system) {
            return back()->withErrors(['role' => 'System role bawaan tidak dapat dihapus.']);
        }

        $usersCount = $db->table('user_roles')->where('role_id', $role)->count();
        if ($usersCount > 0) {
            return back()->withErrors(['role' => "Role tidak dapat dihapus karena masih digunakan oleh {$usersCount} user."]);
        }

        $db->table('roles')->where('id', $role)->delete();

        $auditLogger->log(
            $request,
            'role.delete',
            'role',
            $role,
            "Role dinamis {$existing->name} dihapus.",
            ['role_name' => $existing->name],
        );

        return back()->with('success', 'Role dinamis berhasil dihapus.');
    }

    public function assignUserRole(Request $request, AdminAuditLogger $auditLogger, string $user): RedirectResponse
    {
        $validated = $request->validate([
            'role_ids' => ['array'],
            'role_ids.*' => ['string', 'uuid'],
        ]);

        $db = DB::connection('marketplace');
        $userRow = $db->table('users')->where('id', $user)->firstOrFail();

        $db->table('user_roles')->where('user_id', $user)->delete();

        if (! empty($validated['role_ids'] ?? [])) {
            $insertRows = array_map(fn ($roleId) => [
                'user_id' => $user,
                'role_id' => $roleId,
            ], $validated['role_ids']);

            $db->table('user_roles')->insert($insertRows);
        }

        $auditLogger->log(
            $request,
            'user.assign_roles',
            'user',
            $user,
            "Penugasan role dinamis untuk {$userRow->full_name} diperbarui.",
            [
                'user_name' => $userRow->full_name,
                'roles_count' => count($validated['role_ids'] ?? []),
            ],
        );

        return back()->with('success', 'Penugasan role user berhasil diperbarui.');
    }
}
