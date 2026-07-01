<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AdminAuditLog;
use App\Models\AdminRefundCase;
use App\Services\AdminAuditLogger;
use Illuminate\Pagination\LengthAwarePaginator;
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
        $page = max(1, $request->integer('page', 1));
        $perPage = 20;

        $localCases = AdminRefundCase::query()
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
            ->limit(100)
            ->get()
            ->map(fn ($case) => [
                'id' => (string) $case->id,
                'case_key' => 'local:'.$case->id,
                'source' => 'local',
                'order_id' => $case->order_id,
                'status' => $case->status,
                'request_type' => 'refund',
                'requester_role' => 'admin',
                'reason' => $case->reason,
                'admin_notes' => $case->admin_notes,
                'created_by_name' => $case->created_by_name,
                'resolved_by_name' => $case->resolved_by_name,
                'resolved_at' => $case->resolved_at,
                'created_at' => $case->created_at,
            ]);

        $marketplaceCases = DB::connection('marketplace')
            ->table('refunds')
            ->join('orders', 'orders.id', '=', 'refunds.order_id')
            ->leftJoin('users as requesters', 'requesters.id', '=', 'refunds.requested_by')
            ->select([
                'refunds.id',
                'refunds.order_id',
                'refunds.status',
                'refunds.reason',
                'refunds.admin_notes',
                'refunds.request_type',
                'refunds.requester_role',
                'refunds.resolved_at',
                'refunds.requested_at',
                'orders.order_number',
                'requesters.full_name as requester_name',
                'requesters.phone as requester_phone',
            ])
            ->when($status !== '', fn ($query) => $query->where('refunds.status', $status))
            ->when($search !== '', function ($query) use ($search) {
                $query->where(function ($query) use ($search) {
                    $query->where('refunds.order_id', 'ilike', "%{$search}%")
                        ->orWhere('orders.order_number', 'ilike', "%{$search}%");
                });
            })
            ->orderByDesc('refunds.requested_at')
            ->limit(100)
            ->get()
            ->map(fn ($case) => [
                'id' => (string) $case->id,
                'case_key' => 'marketplace:'.$case->id,
                'source' => 'marketplace',
                'order_id' => $case->order_id,
                'status' => $case->status,
                'request_type' => $case->request_type ?? 'refund',
                'requester_role' => $case->requester_role ?? 'buyer',
                'reason' => $case->reason,
                'admin_notes' => $case->admin_notes,
                'created_by_name' => $case->requester_name ?: ($case->requester_phone ?: 'Marketplace user'),
                'resolved_by_name' => null,
                'resolved_at' => $case->resolved_at,
                'created_at' => $case->requested_at,
            ]);

        $allCases = $localCases
            ->concat($marketplaceCases)
            ->sortByDesc('created_at')
            ->values();

        $cases = new LengthAwarePaginator(
            $allCases->forPage($page, $perPage)->values(),
            $allCases->count(),
            $perPage,
            $page,
            [
                'path' => $request->url(),
                'query' => $request->query(),
            ],
        );

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

    public function show(string $refundCase): Response
    {
        $case = $this->findRefundCase($refundCase);
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
            ->where('orders.id', $case['order_id'])
            ->firstOrFail();

        return Inertia::render('admin/refund-cases/show', [
            'refundCase' => $case,
            'order' => $order,
            'items' => $db->table('order_items')
                ->select(['product_name', 'product_price', 'quantity', 'subtotal', 'product_thumbnail'])
                ->where('order_id', $case['order_id'])
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
                ->where('target_id', $case['order_id'])
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

    public function update(Request $request, AdminAuditLogger $auditLogger, string $refundCase): RedirectResponse
    {
        $validated = $request->validate([
            'status' => ['required', 'in:requested,open,reviewing,resolved,rejected'],
            'admin_notes' => ['nullable', 'string', 'max:4000'],
            'reason' => ['required', 'string', 'min:3', 'max:2000'],
        ]);

        [$source, $id] = $this->parseCaseKey($refundCase);
        $resolved = in_array($validated['status'], ['resolved', 'rejected'], true);

        if ($source === 'marketplace') {
            $case = DB::connection('marketplace')->table('refunds')->where('id', $id)->firstOrFail();
            $previousStatus = $case->status;

            DB::connection('marketplace')->table('refunds')->where('id', $id)->update([
                'status' => $validated['status'],
                'admin_notes' => $validated['admin_notes'] ?? null,
                'resolved_at' => $resolved ? now() : null,
            ]);
        } else {
            $case = AdminRefundCase::query()->where('id', $id)->firstOrFail();
            $previousStatus = $case->status;

            $case->update([
                'status' => $validated['status'],
                'admin_notes' => $validated['admin_notes'] ?? null,
                'resolved_by' => $resolved ? $request->user()->id : null,
                'resolved_at' => $resolved ? now() : null,
            ]);
        }

        $auditLogger->log($request, 'refund_case.update', 'order', $case->order_id, $validated['reason'], [
            'case_id' => (string) $id,
            'source' => $source,
            'previous_status' => $previousStatus,
            'next_status' => $validated['status'],
        ]);

        return back()->with('success', 'Refund case updated.');
    }

    /**
     * @return array<string, mixed>
     */
    private function findRefundCase(string $caseKey): array
    {
        [$source, $id] = $this->parseCaseKey($caseKey);

        if ($source === 'marketplace') {
            $case = DB::connection('marketplace')
                ->table('refunds')
                ->leftJoin('users as requesters', 'requesters.id', '=', 'refunds.requested_by')
                ->select([
                    'refunds.*',
                    'requesters.full_name as requester_name',
                    'requesters.phone as requester_phone',
                ])
                ->where('refunds.id', $id)
                ->firstOrFail();

            return [
                'id' => (string) $case->id,
                'case_key' => 'marketplace:'.$case->id,
                'source' => 'marketplace',
                'order_id' => $case->order_id,
                'status' => $case->status,
                'request_type' => $case->request_type ?? 'refund',
                'requester_role' => $case->requester_role ?? 'buyer',
                'reason' => $case->reason,
                'admin_notes' => $case->admin_notes,
                'created_by_name' => $case->requester_name ?: ($case->requester_phone ?: 'Marketplace user'),
                'resolved_by_name' => null,
                'resolved_at' => $case->resolved_at,
                'created_at' => $case->requested_at,
            ];
        }

        $case = AdminRefundCase::query()
            ->join('users as creators', 'creators.id', '=', 'admin_refund_cases.created_by')
            ->leftJoin('users as resolvers', 'resolvers.id', '=', 'admin_refund_cases.resolved_by')
            ->select([
                'admin_refund_cases.*',
                'creators.name as created_by_name',
                'resolvers.name as resolved_by_name',
            ])
            ->where('admin_refund_cases.id', $id)
            ->firstOrFail();

        return [
            'id' => (string) $case->id,
            'case_key' => 'local:'.$case->id,
            'source' => 'local',
            'order_id' => $case->order_id,
            'status' => $case->status,
            'request_type' => 'refund',
            'requester_role' => 'admin',
            'reason' => $case->reason,
            'admin_notes' => $case->admin_notes,
            'created_by_name' => $case->created_by_name,
            'resolved_by_name' => $case->resolved_by_name,
            'resolved_at' => $case->resolved_at,
            'created_at' => $case->created_at,
        ];
    }

    /**
     * @return array{0: string, 1: string}
     */
    private function parseCaseKey(string $caseKey): array
    {
        if (str_contains($caseKey, ':')) {
            [$source, $id] = explode(':', $caseKey, 2);

            return [$source, $id];
        }

        return [is_numeric($caseKey) ? 'local' : 'marketplace', $caseKey];
    }
}
