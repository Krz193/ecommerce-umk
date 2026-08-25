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

class StoreContentController extends Controller
{
    public function index(Request $request): Response
    {
        $search = $request->string('search')->toString();
        $contentType = $request->string('type')->toString();

        $db = DB::connection('marketplace');

        $contents = $db->table('store_contents')
            ->join('stores', 'stores.id', '=', 'store_contents.store_id')
            ->leftJoin('products', 'products.id', '=', 'store_contents.product_id')
            ->leftJoin('users as creator', 'creator.id', '=', 'store_contents.created_by')
            ->select([
                'store_contents.id',
                'store_contents.store_id',
                'store_contents.product_id',
                'store_contents.title',
                'store_contents.content_type',
                'store_contents.body',
                'store_contents.is_active',
                'store_contents.created_at',
                'stores.name as store_name',
                'products.name as product_name',
                'creator.full_name as creator_name',
            ])
            ->when($search !== '', function ($query) use ($search): void {
                $query->where(function ($query) use ($search): void {
                    $query->where('store_contents.title', 'ilike', "%{$search}%")
                        ->orWhere('stores.name', 'ilike', "%{$search}%")
                        ->orWhere('products.name', 'ilike', "%{$search}%");
                });
            })
            ->when($contentType !== '', fn ($query) => $query->where('store_contents.content_type', $contentType))
            ->orderByDesc('store_contents.created_at')
            ->paginate(20)
            ->withQueryString();

        return Inertia::render('admin/store-contents/index', [
            'contents' => $contents,
            'filters' => [
                'search' => $search,
                'type' => $contentType,
            ],
            'stores' => $db->table('stores')->orderBy('name')->get(['id', 'name']),
            'products' => $db->table('products')->orderBy('name')->get(['id', 'name', 'store_id']),
        ]);
    }

    public function store(Request $request, AdminAuditLogger $auditLogger): RedirectResponse
    {
        $validated = $request->validate([
            'store_id' => ['required', 'string', 'uuid'],
            'product_id' => ['nullable', 'string', 'uuid'],
            'title' => ['required', 'string', 'max:255'],
            'content_type' => ['required', 'string', 'in:banner,promo,storytelling,social,educational'],
            'body' => ['nullable', 'string'],
            'is_active' => ['boolean'],
        ]);

        $db = DB::connection('marketplace');
        $storeRow = $db->table('stores')->where('id', $validated['store_id'])->firstOrFail();

        $id = (string) Str::uuid();

        $db->table('store_contents')->insert([
            'id' => $id,
            'store_id' => $storeRow->id,
            'product_id' => $validated['product_id'] ?? null,
            'created_by' => $storeRow->owner_id, // Default to store owner user ID
            'title' => $validated['title'],
            'content_type' => $validated['content_type'],
            'body' => $validated['body'] ?? null,
            'is_active' => $validated['is_active'] ?? true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $auditLogger->log(
            $request,
            'store_content.create',
            'store_content',
            $id,
            "Konten promosi UMK {$validated['title']} ({$validated['content_type']}) dibuat oleh admin untuk toko {$storeRow->name}.",
            [
                'title' => $validated['title'],
                'content_type' => $validated['content_type'],
                'store_id' => $storeRow->id,
            ],
        );

        return back()->with('success', 'Konten Promosi UMK berhasil dibuat.');
    }

    public function update(Request $request, AdminAuditLogger $auditLogger, string $storeContent): RedirectResponse
    {
        $validated = $request->validate([
            'product_id' => ['nullable', 'string', 'uuid'],
            'title' => ['required', 'string', 'max:255'],
            'content_type' => ['required', 'string', 'in:banner,promo,storytelling,social,educational'],
            'body' => ['nullable', 'string'],
            'is_active' => ['boolean'],
        ]);

        $db = DB::connection('marketplace');
        $existing = $db->table('store_contents')->where('id', $storeContent)->firstOrFail();

        $db->table('store_contents')->where('id', $storeContent)->update([
            'product_id' => $validated['product_id'] ?? null,
            'title' => $validated['title'],
            'content_type' => $validated['content_type'],
            'body' => $validated['body'] ?? null,
            'is_active' => $validated['is_active'] ?? true,
            'updated_at' => now(),
        ]);

        $auditLogger->log(
            $request,
            'store_content.update',
            'store_content',
            $storeContent,
            "Konten promosi {$validated['title']} diperbarui oleh admin.",
            [
                'previous_title' => $existing->title,
                'title' => $validated['title'],
                'content_type' => $validated['content_type'],
            ],
        );

        return back()->with('success', 'Konten Promosi UMK berhasil diperbarui.');
    }

    public function destroy(Request $request, AdminAuditLogger $auditLogger, string $storeContent): RedirectResponse
    {
        $db = DB::connection('marketplace');
        $existing = $db->table('store_contents')->where('id', $storeContent)->firstOrFail();

        $db->table('store_contents')->where('id', $storeContent)->delete();

        $auditLogger->log(
            $request,
            'store_content.delete',
            'store_content',
            $storeContent,
            "Konten promosi {$existing->title} dihapus oleh admin.",
            ['title' => $existing->title],
        );

        return back()->with('success', 'Konten Promosi UMK berhasil dihapus.');
    }
}
