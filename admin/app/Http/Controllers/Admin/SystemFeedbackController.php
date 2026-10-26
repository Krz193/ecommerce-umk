<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\SystemFeedback;
use App\Services\AdminAuditLogger;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Inertia\Inertia;
use Inertia\Response;

class SystemFeedbackController extends Controller
{
    public function index(Request $request): Response
    {
        $status = $request->string('status')->toString();
        $category = $request->string('category')->toString();
        $search = $request->string('search')->toString();

        $query = DB::connection('marketplace')
            ->table('system_feedbacks')
            ->leftJoin('users', 'users.id', '=', 'system_feedbacks.user_id')
            ->select([
                'system_feedbacks.id',
                'system_feedbacks.user_id',
                'system_feedbacks.user_role',
                'system_feedbacks.category',
                'system_feedbacks.subject',
                'system_feedbacks.message',
                'system_feedbacks.status',
                'system_feedbacks.admin_notes',
                'system_feedbacks.created_at',
                'system_feedbacks.updated_at',
                'users.full_name as user_name',
                'users.phone as user_phone',
                'users.username as user_username',
            ])
            ->when($status !== '', fn ($q) => $q->where('system_feedbacks.status', $status))
            ->when($category !== '', fn ($q) => $q->where('system_feedbacks.category', $category))
            ->when($search !== '', function ($q) use ($search): void {
                $q->where(function ($sub) use ($search): void {
                    $sub->where('system_feedbacks.subject', 'ilike', "%{$search}%")
                        ->orWhere('system_feedbacks.message', 'ilike', "%{$search}%")
                        ->orWhere('users.full_name', 'ilike', "%{$search}%")
                        ->orWhere('users.phone', 'ilike', "%{$search}%");
                });
            })
            ->orderByDesc('system_feedbacks.created_at');

        $feedbacks = $query->paginate(20)->withQueryString();

        // Metrics Summary
        $stats = [
            'total' => DB::connection('marketplace')->table('system_feedbacks')->count(),
            'pending' => DB::connection('marketplace')->table('system_feedbacks')->where('status', 'pending')->count(),
            'in_review' => DB::connection('marketplace')->table('system_feedbacks')->where('status', 'in_review')->count(),
            'resolved' => DB::connection('marketplace')->table('system_feedbacks')->where('status', 'resolved')->count(),
        ];

        return Inertia::render('admin/feedbacks/index', [
            'feedbacks' => $feedbacks,
            'stats' => $stats,
            'filters' => [
                'status' => $status,
                'category' => $category,
                'search' => $search,
            ],
        ]);
    }

    public function update(Request $request, AdminAuditLogger $auditLogger, string $systemFeedback): RedirectResponse
    {
        $validated = $request->validate([
            'status' => ['required', 'in:pending,in_review,resolved,rejected'],
            'admin_notes' => ['nullable', 'string', 'max:3000'],
            'reason' => ['nullable', 'string', 'max:500'],
        ]);

        $feedback = DB::connection('marketplace')
            ->table('system_feedbacks')
            ->where('id', $systemFeedback)
            ->firstOrFail();

        $previousStatus = $feedback->status;

        DB::connection('marketplace')
            ->table('system_feedbacks')
            ->where('id', $systemFeedback)
            ->update([
                'status' => $validated['status'],
                'admin_notes' => $validated['admin_notes'] ?? null,
                'updated_at' => now(),
            ]);

        $auditReason = $validated['reason'] ?? "Update status masukan sistem dari {$previousStatus} ke {$validated['status']}";

        $auditLogger->log($request, 'system_feedback.update', 'feedback', $systemFeedback, $auditReason, [
            'feedback_id' => $systemFeedback,
            'previous_status' => $previousStatus,
            'next_status' => $validated['status'],
            'admin_notes' => $validated['admin_notes'] ?? null,
        ]);

        return back()->with('success', 'Status dan catatan masukan sistem berhasil diperbarui.');
    }

    public function destroy(Request $request, AdminAuditLogger $auditLogger, string $systemFeedback): RedirectResponse
    {
        $feedback = DB::connection('marketplace')
            ->table('system_feedbacks')
            ->where('id', $systemFeedback)
            ->firstOrFail();

        DB::connection('marketplace')
            ->table('system_feedbacks')
            ->where('id', $systemFeedback)
            ->delete();

        $auditLogger->log($request, 'system_feedback.delete', 'feedback', $systemFeedback, 'Menghapus tiket masukan sistem', [
            'feedback_id' => $systemFeedback,
            'subject' => $feedback->subject,
            'user_id' => $feedback->user_id,
        ]);

        return back()->with('success', 'Masukan sistem berhasil dihapus.');
    }
}
