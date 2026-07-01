<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AdminAuditLog;
use App\Models\AdminRefundCase;
use App\Services\AdminAuditLogger;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Inertia\Inertia;
use Inertia\Response;

class RefundCaseController extends Controller
{
    public function index(Request $request): Response
    {
        $status = $request->string('status')->toString();
        $search = $request->string('search')->toString();

        $cases = AdminRefundCase::query()
            ->join('users as creators', 'creators.id', '=', 'admin_refund_cases.created_by')
            ->leftJoin('users as resolvers', 'resolvers.id', '=', 'admin_refund_cases.resolved_by')
            ->select([
                'admin_refund_cases.*',
                'creators.name as created_by_name',
                'resolvers.name as resolved_by_name',
            ])
            ->when($status !== '', fn ($query) => $query->where('admin_refund_cases.status', $status))
            ->when($search !== '', fn ($query) => $query->where('admin_refund_cases.order_id', 'like', "%{$search}%"))
            ->orderByDesc('admin_refund_cases.created_at')
            ->paginate(20)
            ->withQueryString();

        return Inertia::render('admin/refund-cases/index', [
            'cases' => $cases,
            'filters' => [
                'status' => $status,
                'search' => $search,
            ],
        ]);
    }

    public function create(Request $request): Response
    {
        return Inertia::render('admin/refund-cases/create', [
            'orderId' => $request->string('order_id')->toString(),
        ]);
    }

    public function show(AdminRefundCase $refundCase): Response
    {
        $db = DB::connection('marketplace');

        $order = $db->table('orders')
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
            ->where('orders.id', $refundCase->order_id)
            ->firstOrFail();

        return Inertia::render('admin/refund-cases/show', [
            'refundCase' => AdminRefundCase::query()
                ->join('users as creators', 'creators.id', '=', 'admin_refund_cases.created_by')
                ->leftJoin('users as resolvers', 'resolvers.id', '=', 'admin_refund_cases.resolved_by')
                ->select([
                    'admin_refund_cases.*',
                    'creators.name as created_by_name',
                    'resolvers.name as resolved_by_name',
                ])
                ->where('admin_refund_cases.id', $refundCase->id)
                ->firstOrFail(),
            'order' => $order,
            'items' => $db->table('order_items')
                ->select(['product_name', 'product_price', 'quantity', 'subtotal', 'product_thumbnail'])
                ->where('order_id', $refundCase->order_id)
                ->get(),
            'logs' => AdminAuditLog::query()
                ->join('users', 'users.id', '=', 'admin_audit_logs.admin_user_id')
                ->select([
                    'admin_audit_logs.id',
                    'admin_audit_logs.action',
                    'admin_audit_logs.reason',
                    'admin_audit_logs.created_at',
                    'users.name as admin_name',
                ])
                ->where('target_type', 'order')
                ->where('target_id', $refundCase->order_id)
                ->orderByDesc('admin_audit_logs.created_at')
                ->get(),
        ]);
    }

    public function store(Request $request, AdminAuditLogger $auditLogger): RedirectResponse
    {
        $validated = $request->validate([
            'order_id' => ['required', 'uuid'],
            'reason' => ['required', 'string', 'min:3', 'max:2000'],
            'admin_notes' => ['nullable', 'string', 'max:4000'],
        ]);

        DB::connection('marketplace')->table('orders')->where('id', $validated['order_id'])->firstOrFail();

        $case = AdminRefundCase::query()->create([
            ...$validated,
            'status' => 'open',
            'created_by' => $request->user()->id,
        ]);

        $auditLogger->log($request, 'refund_case.create', 'order', $validated['order_id'], $validated['reason'], [
            'case_id' => $case->id,
        ]);

        return redirect('/refund-cases')->with('success', 'Refund case created.');
    }

    public function update(Request $request, AdminAuditLogger $auditLogger, AdminRefundCase $refundCase): RedirectResponse
    {
        $validated = $request->validate([
            'status' => ['required', 'in:open,reviewing,resolved,rejected'],
            'admin_notes' => ['nullable', 'string', 'max:4000'],
            'reason' => ['required', 'string', 'min:3', 'max:2000'],
        ]);

        $previousStatus = $refundCase->status;
        $resolved = in_array($validated['status'], ['resolved', 'rejected'], true);

        $refundCase->update([
            'status' => $validated['status'],
            'admin_notes' => $validated['admin_notes'] ?? null,
            'resolved_by' => $resolved ? $request->user()->id : null,
            'resolved_at' => $resolved ? now() : null,
        ]);

        $auditLogger->log($request, 'refund_case.update', 'order', $refundCase->order_id, $validated['reason'], [
            'case_id' => $refundCase->id,
            'previous_status' => $previousStatus,
            'next_status' => $validated['status'],
        ]);

        return back()->with('success', 'Refund case updated.');
    }
}
