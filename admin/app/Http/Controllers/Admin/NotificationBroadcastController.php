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

class NotificationBroadcastController extends Controller
{
    public function index(Request $request): Response
    {
        $search = $request->string('search')->toString();
        $category = $request->string('category')->toString();
        $readState = $request->string('read_state')->toString();

        $db = DB::connection('marketplace');

        $notifications = $db->table('notifications')
            ->leftJoin('users', 'users.id', '=', 'notifications.user_id')
            ->leftJoin('auth.users as au', 'au.id', '=', 'users.id')
            ->select([
                'notifications.id',
                'notifications.user_id',
                'notifications.category',
                'notifications.type',
                'notifications.title',
                'notifications.body',
                'notifications.target_route',
                'notifications.is_read',
                'notifications.read_at',
                'notifications.created_at',
                'users.full_name as user_name',
                'users.role as user_role',
                'au.email as user_email',
            ])
            ->when($category !== '', fn ($q) => $q->where('notifications.category', $category))
            ->when($readState === 'unread', fn ($q) => $q->where('notifications.is_read', false))
            ->when($readState === 'read', fn ($q) => $q->where('notifications.is_read', true))
            ->when($search !== '', function ($q) use ($search): void {
                $q->where(function ($sub) use ($search): void {
                    $sub->where('notifications.title', 'ilike', "%{$search}%")
                        ->orWhere('notifications.body', 'ilike', "%{$search}%")
                        ->orWhere('users.full_name', 'ilike', "%{$search}%")
                        ->orWhere('au.email', 'ilike', "%{$search}%");
                });
            })
            ->orderByDesc('notifications.created_at')
            ->paginate(25)
            ->withQueryString();

        $stats = [
            'total' => $db->table('notifications')->count(),
            'unread' => $db->table('notifications')->where('is_read', false)->count(),
            'promo' => $db->table('notifications')->where('category', 'promo')->count(),
            'transaction' => $db->table('notifications')->where('category', 'transaction')->count(),
            'system' => $db->table('notifications')->where('category', 'system')->count(),
        ];

        $users = $db->table('users')
            ->leftJoin('auth.users as au', 'au.id', '=', 'users.id')
            ->select([
                'users.id',
                'users.full_name',
                'users.role',
                'au.email',
            ])
            ->orderBy('users.full_name')
            ->limit(500)
            ->get();

        return Inertia::render('admin/notifications/index', [
            'notifications' => $notifications,
            'stats' => $stats,
            'filters' => [
                'search' => $search,
                'category' => $category,
                'read_state' => $readState,
            ],
            'users' => $users,
        ]);
    }

    public function store(Request $request, AdminAuditLogger $auditLogger): RedirectResponse
    {
        $validated = $request->validate([
            'target_mode' => ['required', 'string', 'in:all,role,user'],
            'target_role' => ['nullable', 'required_if:target_mode,role', 'string', 'in:buyer,seller,assistant,ekspedisi,ojek'],
            'target_user_id' => ['nullable', 'required_if:target_mode,user', 'string', 'uuid'],
            'category' => ['required', 'string', 'in:promo,system,transaction'],
            'title' => ['required', 'string', 'max:255'],
            'body' => ['required', 'string', 'max:2000'],
            'target_route' => ['nullable', 'string', 'max:255'],
        ]);

        $db = DB::connection('marketplace');

        $recipientIds = match ($validated['target_mode']) {
            'user' => $db->table('users')
                ->where('id', $validated['target_user_id'])
                ->pluck('id')
                ->all(),
            'role' => $db->table('users')
                ->where('role', $validated['target_role'])
                ->pluck('id')
                ->all(),
            default => $db->table('users')
                ->whereIn('role', ['buyer', 'seller', 'assistant', 'ekspedisi', 'ojek'])
                ->pluck('id')
                ->all(),
        };

        if (empty($recipientIds)) {
            return back()->withErrors([
                'target_mode' => 'Tidak ditemukan pengguna tujuan yang sesuai dengan filter target.',
            ]);
        }

        $now = now();
        $targetRoute = filled($validated['target_route'] ?? null)
            ? trim((string) $validated['target_route'])
            : null;
        $metaJson = json_encode([
            'broadcast_by_admin' => true,
            'target_mode' => $validated['target_mode'],
            'target_role' => $validated['target_role'] ?? null,
        ]);

        $rows = array_map(fn (string $userId): array => [
            'id' => (string) Str::uuid(),
            'user_id' => $userId,
            'category' => $validated['category'],
            'type' => 'admin_broadcast',
            'title' => $validated['title'],
            'body' => $validated['body'],
            'target_route' => $targetRoute,
            'data' => $metaJson,
            'is_read' => false,
            'read_at' => null,
            'created_at' => $now,
        ], $recipientIds);

        $db->transaction(function () use ($db, $rows): void {
            foreach (array_chunk($rows, 200) as $chunk) {
                $db->table('notifications')->insert($chunk);
            }
        });

        $recipientCount = count($recipientIds);

        $auditLogger->log(
            $request,
            'notification.broadcast',
            'notification',
            $rows[0]['id'],
            "Broadcast notifikasi '{$validated['title']}' dikirim ke {$recipientCount} pengguna.",
            [
                'target_mode' => $validated['target_mode'],
                'target_role' => $validated['target_role'] ?? null,
                'target_user_id' => $validated['target_user_id'] ?? null,
                'category' => $validated['category'],
                'recipient_count' => $recipientCount,
            ],
        );

        return back()->with('success', "Notifikasi berhasil dikirim ke {$recipientCount} pengguna.");
    }

    public function destroy(Request $request, AdminAuditLogger $auditLogger, string $notification): RedirectResponse
    {
        $db = DB::connection('marketplace');
        $existing = $db->table('notifications')->where('id', $notification)->firstOrFail();

        $db->table('notifications')->where('id', $notification)->delete();

        $auditLogger->log(
            $request,
            'notification.delete',
            'notification',
            $notification,
            "Notifikasi '{$existing->title}' dihapus oleh admin.",
            ['user_id' => $existing->user_id, 'category' => $existing->category],
        );

        return back()->with('success', 'Notifikasi berhasil dihapus.');
    }
}
