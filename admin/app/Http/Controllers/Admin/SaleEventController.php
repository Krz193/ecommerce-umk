<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Services\AdminAuditLogger;
use Carbon\Carbon;
use Illuminate\Database\ConnectionInterface;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Inertia\Inertia;
use Inertia\Response;

class SaleEventController extends Controller
{
    public function index(Request $request): Response
    {
        $search = $request->string('search')->toString();
        $state = $request->string('state')->toString();
        $db = DB::connection('marketplace');
        $now = now();

        $itemStatsSub = $db->table('sale_event_items')
            ->selectRaw('sale_event_id, COUNT(*)::int as total_items, COALESCE(SUM(sold_count), 0)::int as total_sold')
            ->groupBy('sale_event_id');

        $events = $db->table('sale_events')
            ->leftJoin('stores', 'stores.id', '=', 'sale_events.store_id')
            ->leftJoinSub($itemStatsSub, 'stats', 'stats.sale_event_id', '=', 'sale_events.id')
            ->select([
                'sale_events.id',
                'sale_events.store_id',
                'sale_events.title',
                'sale_events.slug',
                'sale_events.description',
                'sale_events.banner_url',
                'sale_events.start_time',
                'sale_events.end_time',
                'sale_events.is_active',
                'sale_events.created_at',
                'stores.name as store_name',
                DB::raw('COALESCE(stats.total_items, 0) as total_items'),
                DB::raw('COALESCE(stats.total_sold, 0) as total_sold'),
            ])
            ->when($search !== '', function ($query) use ($search): void {
                $query->where(function ($sub) use ($search): void {
                    $sub->where('sale_events.title', 'ilike', "%{$search}%")
                        ->orWhere('sale_events.description', 'ilike', "%{$search}%")
                        ->orWhere('stores.name', 'ilike', "%{$search}%");
                });
            })
            ->when($state !== '', function ($query) use ($state, $now): void {
                match ($state) {
                    'ongoing' => $query->where('sale_events.is_active', true)
                        ->where('sale_events.start_time', '<=', $now)
                        ->where('sale_events.end_time', '>=', $now),
                    'upcoming' => $query->where('sale_events.is_active', true)
                        ->where('sale_events.start_time', '>', $now),
                    'ended' => $query->where('sale_events.end_time', '<', $now),
                    'inactive' => $query->where('sale_events.is_active', false),
                    default => null,
                };
            })
            ->orderByDesc('sale_events.created_at')
            ->paginate(20)
            ->withQueryString();

        $stats = [
            'total' => $db->table('sale_events')->count(),
            'ongoing' => $db->table('sale_events')
                ->where('is_active', true)
                ->where('start_time', '<=', $now)
                ->where('end_time', '>=', $now)
                ->count(),
            'upcoming' => $db->table('sale_events')
                ->where('is_active', true)
                ->where('start_time', '>', $now)
                ->count(),
            'ended' => $db->table('sale_events')
                ->where('end_time', '<', $now)
                ->count(),
        ];

        return Inertia::render('admin/sale-events/index', [
            'events' => $events,
            'stats' => $stats,
            'filters' => [
                'search' => $search,
                'state' => $state,
            ],
            'stores' => $db->table('stores')->orderBy('name')->get(['id', 'name']),
        ]);
    }

    public function show(string $saleEvent): Response
    {
        $db = DB::connection('marketplace');

        $eventRow = $db->table('sale_events')
            ->leftJoin('stores', 'stores.id', '=', 'sale_events.store_id')
            ->select([
                'sale_events.*',
                'stores.name as store_name',
            ])
            ->where('sale_events.id', $saleEvent)
            ->firstOrFail();

        $items = $db->table('sale_event_items')
            ->join('products', 'products.id', '=', 'sale_event_items.product_id')
            ->join('stores', 'stores.id', '=', 'sale_event_items.store_id')
            ->select([
                'sale_event_items.*',
                'products.name as product_name',
                'products.price as regular_price',
                'products.stock as product_stock',
                'products.thumbnail_url as product_thumbnail',
                'products.status as product_status',
                'stores.name as store_name',
            ])
            ->where('sale_event_items.sale_event_id', $saleEvent)
            ->orderByDesc('sale_event_items.created_at')
            ->get();

        $products = $db->table('products')
            ->join('stores', 'stores.id', '=', 'products.store_id')
            ->select([
                'products.id',
                'products.name',
                'products.price',
                'products.stock',
                'products.store_id',
                'products.status',
                'stores.name as store_name',
            ])
            ->whereNull('products.archived_at')
            ->when($eventRow->store_id !== null, fn ($q) => $q->where('products.store_id', $eventRow->store_id))
            ->orderBy('products.name')
            ->get();

        return Inertia::render('admin/sale-events/show', [
            'event' => $eventRow,
            'items' => $items,
            'products' => $products,
        ]);
    }

    public function store(Request $request, AdminAuditLogger $auditLogger): RedirectResponse
    {
        $validated = $this->validateEvent($request);
        $db = DB::connection('marketplace');

        if (! empty($validated['store_id'])) {
            $db->table('stores')->where('id', $validated['store_id'])->firstOrFail();
        }

        $id = (string) Str::uuid();
        $slug = $this->makeUniqueSlug($db, $validated['title']);

        $db->table('sale_events')->insert([
            'id' => $id,
            'store_id' => $validated['store_id'] ?: null,
            'created_by' => null,
            'title' => $validated['title'],
            'slug' => $slug,
            'description' => $validated['description'] ?: null,
            'banner_url' => $validated['banner_url'] ?: null,
            'start_time' => Carbon::parse($validated['start_time'])->toIso8601String(),
            'end_time' => Carbon::parse($validated['end_time'])->toIso8601String(),
            'is_active' => (bool) ($validated['is_active'] ?? true),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $auditLogger->log(
            $request,
            'sale_event.create',
            'sale_event',
            $id,
            "Sale event '{$validated['title']}' dibuat oleh admin.",
            [
                'title' => $validated['title'],
                'store_id' => $validated['store_id'] ?: null,
                'start_time' => $validated['start_time'],
                'end_time' => $validated['end_time'],
            ],
        );

        return redirect()->route('admin.sale-events.show', $id)
            ->with('success', 'Flash Sale Event berhasil dibuat. Silakan tambahkan produk ke dalam event.');
    }

    public function update(Request $request, AdminAuditLogger $auditLogger, string $saleEvent): RedirectResponse
    {
        $validated = $this->validateEvent($request);
        $db = DB::connection('marketplace');

        $existing = $db->table('sale_events')->where('id', $saleEvent)->firstOrFail();

        if (! empty($validated['store_id'])) {
            $db->table('stores')->where('id', $validated['store_id'])->firstOrFail();
        }

        $slug = $this->makeUniqueSlug($db, $validated['title'], $saleEvent);

        $db->table('sale_events')->where('id', $saleEvent)->update([
            'store_id' => $validated['store_id'] ?: null,
            'title' => $validated['title'],
            'slug' => $slug,
            'description' => $validated['description'] ?: null,
            'banner_url' => $validated['banner_url'] ?: null,
            'start_time' => Carbon::parse($validated['start_time'])->toIso8601String(),
            'end_time' => Carbon::parse($validated['end_time'])->toIso8601String(),
            'is_active' => (bool) ($validated['is_active'] ?? true),
            'updated_at' => now(),
        ]);

        $auditLogger->log(
            $request,
            'sale_event.update',
            'sale_event',
            $saleEvent,
            "Sale event '{$validated['title']}' diperbarui oleh admin.",
            [
                'previous_title' => $existing->title,
                'title' => $validated['title'],
                'is_active' => (bool) ($validated['is_active'] ?? true),
            ],
        );

        return back()->with('success', 'Flash Sale Event berhasil diperbarui.');
    }

    public function destroy(Request $request, AdminAuditLogger $auditLogger, string $saleEvent): RedirectResponse
    {
        $db = DB::connection('marketplace');
        $existing = $db->table('sale_events')->where('id', $saleEvent)->firstOrFail();

        $db->table('sale_events')->where('id', $saleEvent)->delete();

        $auditLogger->log(
            $request,
            'sale_event.delete',
            'sale_event',
            $saleEvent,
            "Sale event '{$existing->title}' dihapus oleh admin.",
            ['title' => $existing->title],
        );

        return redirect()->route('admin.sale-events.index')
            ->with('success', 'Flash Sale Event berhasil dihapus.');
    }

    public function addItem(Request $request, AdminAuditLogger $auditLogger, string $saleEvent): RedirectResponse
    {
        $validated = $this->validateItem($request, true);
        $db = DB::connection('marketplace');

        $eventRow = $db->table('sale_events')->where('id', $saleEvent)->firstOrFail();
        $productRow = $db->table('products')->where('id', $validated['product_id'])->firstOrFail();

        if ($eventRow->store_id !== null && $eventRow->store_id !== $productRow->store_id) {
            return back()->withErrors([
                'product_id' => 'Produk yang dipilih tidak berasal dari toko pemilik event ini.',
            ]);
        }

        if ($validated['discount_type'] === 'percentage' && (float) $validated['discount_value'] > 99) {
            return back()->withErrors([
                'discount_value' => 'Diskon persentase maksimal 99%.',
            ]);
        }

        $salePrice = $this->calculateSalePrice(
            (float) $productRow->price,
            $validated['discount_type'],
            (float) $validated['discount_value'],
        );

        $existingItem = $db->table('sale_event_items')
            ->where('sale_event_id', $saleEvent)
            ->where('product_id', $productRow->id)
            ->first();

        if ($existingItem) {
            $db->table('sale_event_items')->where('id', $existingItem->id)->update([
                'discount_type' => $validated['discount_type'],
                'discount_value' => $validated['discount_value'],
                'sale_price' => $salePrice,
                'sale_quota' => $validated['sale_quota'] ?? null,
                'max_qty_per_user' => $validated['max_qty_per_user'] ?? null,
                'is_active' => (bool) ($validated['is_active'] ?? true),
                'updated_at' => now(),
            ]);

            $auditLogger->log(
                $request,
                'sale_event_item.update',
                'sale_event_item',
                $existingItem->id,
                "Item Flash Sale '{$productRow->name}' pada event '{$eventRow->title}' diperbarui.",
                ['sale_event_id' => $saleEvent, 'product_id' => $productRow->id, 'sale_price' => $salePrice],
            );

            return back()->with('success', 'Item Flash Sale berhasil diperbarui.');
        }

        $itemId = (string) Str::uuid();
        $db->table('sale_event_items')->insert([
            'id' => $itemId,
            'sale_event_id' => $saleEvent,
            'product_id' => $productRow->id,
            'store_id' => $productRow->store_id,
            'discount_type' => $validated['discount_type'],
            'discount_value' => $validated['discount_value'],
            'sale_price' => $salePrice,
            'sale_quota' => $validated['sale_quota'] ?? null,
            'sold_count' => 0,
            'max_qty_per_user' => $validated['max_qty_per_user'] ?? null,
            'is_active' => (bool) ($validated['is_active'] ?? true),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $auditLogger->log(
            $request,
            'sale_event_item.add',
            'sale_event_item',
            $itemId,
            "Produk '{$productRow->name}' ditambahkan ke Flash Sale '{$eventRow->title}'.",
            ['sale_event_id' => $saleEvent, 'product_id' => $productRow->id, 'sale_price' => $salePrice],
        );

        return back()->with('success', 'Produk berhasil ditambahkan ke Flash Sale.');
    }

    public function updateItem(Request $request, AdminAuditLogger $auditLogger, string $saleEvent, string $item): RedirectResponse
    {
        $validated = $this->validateItem($request, false);
        $db = DB::connection('marketplace');

        $itemRow = $db->table('sale_event_items')
            ->where('id', $item)
            ->where('sale_event_id', $saleEvent)
            ->firstOrFail();

        $productRow = $db->table('products')->where('id', $itemRow->product_id)->firstOrFail();

        if ($validated['discount_type'] === 'percentage' && (float) $validated['discount_value'] > 99) {
            return back()->withErrors([
                'discount_value' => 'Diskon persentase maksimal 99%.',
            ]);
        }

        $salePrice = $this->calculateSalePrice(
            (float) $productRow->price,
            $validated['discount_type'],
            (float) $validated['discount_value'],
        );

        $db->table('sale_event_items')->where('id', $item)->update([
            'discount_type' => $validated['discount_type'],
            'discount_value' => $validated['discount_value'],
            'sale_price' => $salePrice,
            'sale_quota' => $validated['sale_quota'] ?? null,
            'max_qty_per_user' => $validated['max_qty_per_user'] ?? null,
            'is_active' => (bool) ($validated['is_active'] ?? true),
            'updated_at' => now(),
        ]);

        $auditLogger->log(
            $request,
            'sale_event_item.update',
            'sale_event_item',
            $item,
            "Item Flash Sale '{$productRow->name}' diperbarui oleh admin.",
            ['sale_event_id' => $saleEvent, 'sale_price' => $salePrice],
        );

        return back()->with('success', 'Pengaturan item Flash Sale berhasil diperbarui.');
    }

    public function removeItem(Request $request, AdminAuditLogger $auditLogger, string $saleEvent, string $item): RedirectResponse
    {
        $db = DB::connection('marketplace');

        $itemRow = $db->table('sale_event_items')
            ->where('id', $item)
            ->where('sale_event_id', $saleEvent)
            ->firstOrFail();

        $db->table('sale_event_items')->where('id', $item)->delete();

        $auditLogger->log(
            $request,
            'sale_event_item.remove',
            'sale_event_item',
            $item,
            'Produk dihapus dari Flash Sale event.',
            ['sale_event_id' => $saleEvent, 'product_id' => $itemRow->product_id],
        );

        return back()->with('success', 'Produk dihapus dari event Flash Sale.');
    }

    /**
     * @return array<string, mixed>
     */
    private function validateEvent(Request $request): array
    {
        return $request->validate([
            'store_id' => ['nullable', 'string', 'uuid'],
            'title' => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string', 'max:3000'],
            'banner_url' => ['nullable', 'url', 'max:1000'],
            'start_time' => ['required', 'date'],
            'end_time' => ['required', 'date', 'after:start_time'],
            'is_active' => ['boolean'],
        ]);
    }

    /**
     * @return array<string, mixed>
     */
    private function validateItem(Request $request, bool $requireProduct): array
    {
        $rules = [
            'discount_type' => ['required', 'string', 'in:percentage,nominal,fixed_price'],
            'discount_value' => ['required', 'numeric', 'min:1'],
            'sale_quota' => ['nullable', 'integer', 'min:1'],
            'max_qty_per_user' => ['nullable', 'integer', 'min:1'],
            'is_active' => ['boolean'],
        ];

        if ($requireProduct) {
            $rules['product_id'] = ['required', 'string', 'uuid'];
        }

        return $request->validate($rules);
    }

    /**
     * Zero client trust: compute sale_price server-side matching Postgres calculate_sale_price().
     */
    private function calculateSalePrice(float $basePrice, string $discountType, float $discountValue): int
    {
        return match ($discountType) {
            'percentage' => (int) max(0, round($basePrice * (1 - min(100, max(0, $discountValue)) / 100))),
            'nominal' => (int) max(0, round($basePrice - max(0, $discountValue))),
            'fixed_price' => (int) max(0, min($basePrice, round($discountValue))),
            default => (int) max(0, round($basePrice)),
        };
    }

    private function makeUniqueSlug(ConnectionInterface $db, string $title, ?string $ignoreId = null): string
    {
        $base = Str::slug($title) ?: 'flash-sale';
        $slug = $base;
        $counter = 2;

        while (
            $db->table('sale_events')
                ->where('slug', $slug)
                ->when($ignoreId !== null, fn ($q) => $q->where('id', '!=', $ignoreId))
                ->exists()
        ) {
            $slug = "{$base}-{$counter}";
            $counter++;
        }

        return $slug;
    }
}
