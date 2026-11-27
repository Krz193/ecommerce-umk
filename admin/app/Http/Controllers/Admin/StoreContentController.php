<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Services\AdminAuditLogger;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Inertia\Inertia;
use Inertia\Response;

class StoreContentController extends Controller
{
    public function index(Request $request): Response
    {
        $search = $request->string('search')->toString();
        $contentType = $request->string('type')->toString();
        $platform = $request->string('platform')->toString();

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
                'store_contents.social_platform',
                'store_contents.media_format',
                'store_contents.external_url',
                'store_contents.body',
                'store_contents.is_active',
                'store_contents.reach_count',
                'store_contents.likes_count',
                'store_contents.comments_count',
                'store_contents.shares_count',
                'store_contents.inquiries_count',
                'store_contents.created_at',
                'stores.name as store_name',
                'products.name as product_name',
                'creator.full_name as creator_name',
            ])
            ->when($search !== '', function ($query) use ($search): void {
                $query->where(function ($query) use ($search): void {
                    $query->where('store_contents.title', 'ilike', "%{$search}%")
                        ->orWhere('stores.name', 'ilike', "%{$search}%")
                        ->orWhere('products.name', 'ilike', "%{$search}%")
                        ->orWhere('creator.full_name', 'ilike', "%{$search}%");
                });
            })
            ->when($contentType !== '', fn ($query) => $query->where('store_contents.content_type', $contentType))
            ->when($platform !== '', fn ($query) => $query->where('store_contents.social_platform', $platform))
            ->orderByDesc('store_contents.created_at')
            ->paginate(20)
            ->withQueryString();

        return Inertia::render('admin/store-contents/index', [
            'contents' => $contents,
            'filters' => [
                'search' => $search,
                'type' => $contentType,
                'platform' => $platform,
            ],
        ]);
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
            "Konten & engagement {$existing->title} dihapus oleh admin.",
            ['title' => $existing->title],
        );

        return back()->with('success', 'Konten UMK berhasil dihapus.');
    }
}
