<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Donation;
use App\Models\Store;
use App\Services\AdminAuditLogger;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Inertia\Inertia;
use Inertia\Response;

class DonationController extends Controller
{
    public function index(Request $request): Response
    {
        $status = $request->query('status');
        $storeId = $request->query('store_id');

        $query = Donation::query()
            ->with(['store:id,name', 'user:id,full_name,phone'])
            ->orderByDesc('created_at');

        if ($status) {
            $query->where('status', $status);
        }

        if ($storeId) {
            $query->where('store_id', $storeId);
        }

        $donations = $query->paginate(20)->withQueryString();

        $stores = Store::query()
            ->select('id', 'name')
            ->orderBy('name')
            ->get();

        $distributed = Donation::where('status', 'distributed');

        $metrics = [
            'total_collected' => (float)Donation::whereIn('status', ['paid', 'distributed'])->sum('amount'),
            'total_distributed' => (float)(clone $distributed)->sum(DB::raw('coalesce(distributed_amount, amount)')),
            'total_pending' => (float)Donation::where('status', 'paid')->sum('amount'),
            'distributed_count' => (clone $distributed)->count(),
            'total_donors' => Donation::count(),
            'total_stores_supported' => Donation::distinct('store_id')->count('store_id'),
        ];

        return Inertia::render('admin/donations/index', [
            'donations' => $donations,
            'stores' => $stores,
            'metrics' => $metrics,
            'filters' => [
                'status' => $status,
                'store_id' => $storeId,
            ],
        ]);
    }

    public function update(Request $request, Donation $donation, AdminAuditLogger $auditLogger): RedirectResponse
    {
        $validated = $request->validate([
            'status' => 'required|in:paid,distributed,cancelled',
            'note' => 'nullable|string|max:500',
            'distributed_at' => 'nullable|date',
            'distributed_amount' => ['nullable', 'numeric', 'gt:0', 'max:'.$donation->amount],
        ]);

        $isDistributed = $validated['status'] === 'distributed';

        // Distribution date/amount only apply to distributed donations; default to now / full amount.
        $validated['distributed_at'] = $isDistributed ? ($validated['distributed_at'] ?? now()) : null;
        $validated['distributed_amount'] = $isDistributed ? ($validated['distributed_amount'] ?? $donation->amount) : null;

        $oldStatus = $donation->status;
        $donation->update($validated);

        $auditLogger->log(
            $request,
            'donations.update_status',
            'donation',
            $donation->id,
            "Mengubah status donasi dari {$oldStatus} ke {$donation->status}",
            [
                'old_status' => $oldStatus,
                'new_status' => $donation->status,
                'amount' => $donation->amount,
                'distributed_amount' => $donation->distributed_amount,
            ]
        );

        return back()->with('success', 'Status donasi berhasil diperbarui.');
    }

    public function destroy(Request $request, Donation $donation, AdminAuditLogger $auditLogger): RedirectResponse
    {
        $id = $donation->id;
        $amount = $donation->amount;
        $donation->delete();

        $auditLogger->log(
            $request,
            'donations.delete',
            'donation',
            $id,
            "Menghapus catatan donasi sebesar {$amount}",
            ['amount' => $amount]
        );

        return back()->with('success', 'Catatan donasi berhasil dihapus.');
    }
}
