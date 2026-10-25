<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Services\AdminAuditLogger;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Inertia\Inertia;
use Inertia\Response;

class ProductModerationController extends Controller
{
    public function index(Request $request): Response
    {
        $status = $request->string('status')->toString();
        $search = $request->string('search')->toString();

        $products = DB::connection('marketplace')
            ->table('products')
            ->join('stores', 'stores.id', '=', 'products.store_id')
            ->leftJoin('categories', 'categories.id', '=', 'products.category_id')
            ->select([
                'products.id',
                'products.name',
                'products.status',
                'products.price',
                'products.original_price',
                'products.discount_percent',
                'products.discount_amount',
                'products.tax_percent',
                'products.stock',
                'products.thumbnail_url',
                'products.archived_at',
                'products.created_at',
                'stores.name as store_name',
                'categories.name as category_name',
            ])
            ->when($status !== '', fn ($query) => $query->where('products.status', $status))
            ->when($search !== '', function ($query) use ($search): void {
                $query->where(function ($query) use ($search): void {
                    $query->where('products.name', 'ilike', "%{$search}%")
                        ->orWhere('stores.name', 'ilike', "%{$search}%")
                        ->orWhere('categories.name', 'ilike', "%{$search}%");
                });
            })
            ->orderByDesc('products.created_at')
            ->paginate(20)
            ->withQueryString();

        return Inertia::render('admin/products/index', [
            'products' => $products,
            'filters' => [
                'status' => $status,
                'search' => $search,
            ],
            'categories' => DB::connection('marketplace')->table('categories')->where('is_active', true)->orderBy('name')->get(['id', 'name']),
            'stores' => DB::connection('marketplace')->table('stores')->orderBy('name')->get(['id', 'name']),
        ]);
    }

    public function show(string $product): Response
    {
        $db = DB::connection('marketplace');

        $productRow = $db->table('products')
            ->join('stores', 'stores.id', '=', 'products.store_id')
            ->leftJoin('categories', 'categories.id', '=', 'products.category_id')
            ->select([
                'products.*',
                'stores.name as store_name',
                'categories.name as category_name',
            ])
            ->where('products.id', $product)
            ->firstOrFail();

        return Inertia::render('admin/products/show', [
            'product' => $productRow,
            'images' => $db->table('product_images')
                ->select(['id', 'image_url', 'sort_order', 'created_at'])
                ->where('product_id', $product)
                ->orderBy('sort_order')
                ->get(),
            'categories' => $db->table('categories')->where('is_active', true)->orderBy('name')->get(['id', 'name']),
            'stores' => $db->table('stores')->orderBy('name')->get(['id', 'name']),
        ]);
    }

    public function archive(Request $request, AdminAuditLogger $auditLogger, string $product): RedirectResponse
    {
        $validated = $request->validate([
            'reason' => ['required', 'string', 'min:3', 'max:1000'],
        ]);

        $db = DB::connection('marketplace');
        $previous = $db->table('products')->where('id', $product)->firstOrFail();

        $db->table('products')->where('id', $product)
            ->update([
                'status' => 'draft',
                'archived_at' => now(),
                'updated_at' => now(),
            ]);

        $auditLogger->log(
            $request,
            'product.archive',
            'product',
            $product,
            $validated['reason'],
            [
                'previous_status' => $previous->status,
                'next_status' => 'draft',
                'product_name' => $previous->name,
            ],
        );

        return back()->with('success', 'Product archived.');
    }

    public function restore(Request $request, AdminAuditLogger $auditLogger, string $product): RedirectResponse
    {
        $validated = $request->validate([
            'reason' => ['required', 'string', 'min:3', 'max:1000'],
        ]);

        $db = DB::connection('marketplace');
        $previous = $db->table('products')->where('id', $product)->firstOrFail();

        $db->table('products')->where('id', $product)
            ->update([
                'status' => 'published',
                'archived_at' => null,
                'updated_at' => now(),
            ]);

        $auditLogger->log(
            $request,
            'product.restore',
            'product',
            $product,
            $validated['reason'],
            [
                'previous_status' => $previous->status,
                'next_status' => 'published',
                'product_name' => $previous->name,
            ],
        );

        return back()->with('success', 'Product restored.');
    }

    public function store(Request $request, AdminAuditLogger $auditLogger): RedirectResponse
    {
        $validated = $request->validate([
            'store_id' => ['required', 'string', 'uuid'],
            'category_id' => ['nullable', 'string', 'uuid'],
            'name' => ['required', 'string', 'max:255'],
            'slug' => ['nullable', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'original_price' => ['required', 'numeric', 'min:0'],
            'discount_percent' => ['nullable', 'numeric', 'min:0', 'max:100'],
            'discount_amount' => ['nullable', 'numeric', 'min:0'],
            'tax_percent' => ['nullable', 'numeric', 'min:0', 'max:100'],
            'stock' => ['required', 'integer', 'min:0'],
            'weight' => ['nullable', 'numeric', 'min:0'],
            'thumbnail_url' => ['nullable', 'string', 'url', 'max:1000'],
            'status' => ['required', 'string', 'in:draft,published'],
        ]);

        $db = DB::connection('marketplace');

        $storeRow = $db->table('stores')->where('id', $validated['store_id'])->firstOrFail();

        $slug = filled($validated['slug'] ?? null)
            ? \Illuminate\Support\Str::slug($validated['slug'])
            : \Illuminate\Support\Str::slug($validated['name']);

        $exists = $db->table('products')->where('slug', $slug)->exists();
        if ($exists) {
            return back()->withErrors(['slug' => 'Slug produk sudah digunakan.']);
        }

        $id = (string) \Illuminate\Support\Str::uuid();
        $pricing = $this->pricing($validated);

        $db->table('products')->insert([
            'id' => $id,
            'store_id' => $storeRow->id,
            'category_id' => $validated['category_id'] ?? null,
            'name' => $validated['name'],
            'slug' => $slug,
            'description' => $validated['description'] ?? null,
            ...$pricing,
            'stock' => $validated['stock'],
            'weight' => $validated['weight'] ?? null,
            'thumbnail_url' => $validated['thumbnail_url'] ?? null,
            'status' => $validated['status'],
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $auditLogger->log(
            $request,
            'product.create',
            'product',
            $id,
            "Produk {$validated['name']} dibuat oleh admin untuk toko {$storeRow->name}.",
            [
                'name' => $validated['name'],
                'store_id' => $storeRow->id,
                'price' => $pricing['price'],
                'stock' => $validated['stock'],
            ],
        );

        return back()->with('success', 'Produk berhasil dibuat oleh Admin.');
    }

    public function update(Request $request, AdminAuditLogger $auditLogger, string $product): RedirectResponse
    {
        $validated = $request->validate([
            'category_id' => ['nullable', 'string', 'uuid'],
            'name' => ['required', 'string', 'max:255'],
            'slug' => ['nullable', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'original_price' => ['required', 'numeric', 'min:0'],
            'discount_percent' => ['nullable', 'numeric', 'min:0', 'max:100'],
            'discount_amount' => ['nullable', 'numeric', 'min:0'],
            'tax_percent' => ['nullable', 'numeric', 'min:0', 'max:100'],
            'stock' => ['required', 'integer', 'min:0'],
            'weight' => ['nullable', 'numeric', 'min:0'],
            'thumbnail_url' => ['nullable', 'string', 'url', 'max:1000'],
            'status' => ['required', 'string', 'in:draft,published'],
        ]);

        $db = DB::connection('marketplace');
        $existing = $db->table('products')->where('id', $product)->firstOrFail();

        $slug = filled($validated['slug'] ?? null)
            ? \Illuminate\Support\Str::slug($validated['slug'])
            : \Illuminate\Support\Str::slug($validated['name']);

        $slugExists = $db->table('products')
            ->where('slug', $slug)
            ->where('id', '!=', $product)
            ->exists();

        if ($slugExists) {
            return back()->withErrors(['slug' => 'Slug produk sudah digunakan oleh produk lain.']);
        }

        $pricing = $this->pricing($validated);

        $db->table('products')->where('id', $product)->update([
            'category_id' => $validated['category_id'] ?? null,
            'name' => $validated['name'],
            'slug' => $slug,
            'description' => $validated['description'] ?? null,
            ...$pricing,
            'stock' => $validated['stock'],
            'weight' => $validated['weight'] ?? null,
            'thumbnail_url' => $validated['thumbnail_url'] ?? null,
            'status' => $validated['status'],
            'updated_at' => now(),
        ]);

        $auditLogger->log(
            $request,
            'product.update',
            'product',
            $product,
            "Informasi produk {$validated['name']} diperbarui oleh admin.",
            [
                'previous_name' => $existing->name,
                'name' => $validated['name'],
                'previous_price' => $existing->price,
                'price' => $pricing['price'],
                'stock' => $validated['stock'],
            ],
        );

        return back()->with('success', 'Informasi Produk berhasil diperbarui.');
    }

    /**
     * Zero client trust: the selling price is always recomputed server-side
     * from the original price, discounts and tax.
     *
     * @return array{original_price: float, discount_percent: float, discount_amount: float, tax_percent: float, price: int}
     */
    private function pricing(array $validated): array
    {
        $originalPrice = (float) $validated['original_price'];
        $discountPercent = (float) ($validated['discount_percent'] ?? 0);
        $discountAmount = (float) ($validated['discount_amount'] ?? 0);
        $taxPercent = (float) ($validated['tax_percent'] ?? 0);

        return [
            'original_price' => $originalPrice,
            'discount_percent' => $discountPercent,
            'discount_amount' => $discountAmount,
            'tax_percent' => $taxPercent,
            'price' => Product::calculateFinalPrice($originalPrice, $discountPercent, $discountAmount, $taxPercent),
        ];
    }

    public function destroy(Request $request, AdminAuditLogger $auditLogger, string $product): RedirectResponse
    {
        $db = DB::connection('marketplace');
        $existing = $db->table('products')->where('id', $product)->firstOrFail();

        $orderItemsCount = $db->table('order_items')->where('product_id', $product)->count();

        if ($orderItemsCount > 0) {
            // Archive if ordered in transactions
            $db->table('products')->where('id', $product)->update([
                'status' => 'draft',
                'archived_at' => now(),
                'updated_at' => now(),
            ]);

            $auditLogger->log(
                $request,
                'product.delete_blocked_archived',
                'product',
                $product,
                "Produk {$existing->name} diarsipkan (bukan dihapus) karena telah dibeli dalam {$orderItemsCount} item pesanan.",
                ['product_name' => $existing->name],
            );

            return back()->with('success', "Produk diarsipkan karena terdapat {$orderItemsCount} riwayat pesanan.");
        }

        $db->table('products')->where('id', $product)->delete();

        $auditLogger->log(
            $request,
            'product.delete',
            'product',
            $product,
            "Produk {$existing->name} dihapus permanen oleh admin.",
            ['product_name' => $existing->name],
        );

        return back()->with('success', 'Produk berhasil dihapus.');
    }
}

