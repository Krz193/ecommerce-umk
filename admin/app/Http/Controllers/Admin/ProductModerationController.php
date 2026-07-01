<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
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
}
