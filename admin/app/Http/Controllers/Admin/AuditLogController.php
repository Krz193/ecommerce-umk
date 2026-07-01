<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AdminAuditLog;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

class AuditLogController extends Controller
{
    public function index(Request $request): Response
    {
        $action = $request->string('action')->toString();
        $targetType = $request->string('target_type')->toString();

        $logs = AdminAuditLog::query()
            ->join('users', 'users.id', '=', 'admin_audit_logs.admin_user_id')
            ->select([
                'admin_audit_logs.id',
                'admin_audit_logs.action',
                'admin_audit_logs.target_type',
                'admin_audit_logs.target_id',
                'admin_audit_logs.reason',
                'admin_audit_logs.metadata',
                'admin_audit_logs.created_at',
                'users.name as admin_name',
                'users.email as admin_email',
            ])
            ->when($action !== '', fn ($query) => $query->where('admin_audit_logs.action', $action))
            ->when($targetType !== '', fn ($query) => $query->where('admin_audit_logs.target_type', $targetType))
            ->orderByDesc('admin_audit_logs.created_at')
            ->paginate(20)
            ->withQueryString();

        return Inertia::render('admin/audit-logs/index', [
            'logs' => $logs,
            'filters' => [
                'action' => $action,
                'target_type' => $targetType,
            ],
        ]);
    }
}
