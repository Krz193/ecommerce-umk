<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Category;
use App\Services\AdminAuditLogger;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Inertia\Inertia;
use Inertia\Response;

class CategoryController extends Controller
{
    public function index(Request $request): Response
    {
        $search = $request->string('search')->toString();
        $status = $request->string('status')->toString();

        $categories = DB::connection('marketplace')
            ->table('categories')
            ->select([
                'categories.id',
                'categories.name',
                'categories.slug',
                'categories.icon_url',
                'categories.is_active',
                'categories.created_at',
                DB::raw('(select count(*) from products where products.category_id = categories.id) as products_count'),
            ])
            ->when($search !== '', function ($query) use ($search): void {
                $query->where('categories.name', 'ilike', "%{$search}%")
                    ->orWhere('categories.slug', 'ilike', "%{$search}%");
            })
            ->when($status !== '', function ($query) use ($status): void {
                if ($status === 'active') {
                    $query->where('categories.is_active', true);
                } elseif ($status === 'inactive') {
                    $query->where('categories.is_active', false);
                }
            })
            ->orderBy('categories.name')
            ->paginate(20)
            ->withQueryString();

        return Inertia::render('admin/categories/index', [
            'categories' => $categories,
            'filters' => [
                'search' => $search,
                'status' => $status,
            ],
        ]);
    }

    public function store(Request $request, AdminAuditLogger $auditLogger): RedirectResponse
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'slug' => ['nullable', 'string', 'max:255'],
            'icon_url' => ['nullable', 'string', 'url', 'max:1000'],
            'is_active' => ['boolean'],
        ]);

        $slug = filled($validated['slug'] ?? null)
            ? Str::slug($validated['slug'])
            : Str::slug($validated['name']);

        $db = DB::connection('marketplace');

        $exists = $db->table('categories')->where('slug', $slug)->exists();
        if ($exists) {
            return back()->withErrors(['slug' => 'Slug category sudah digunakan.']);
        }

        $id = (string) Str::uuid();

        $db->table('categories')->insert([
            'id' => $id,
            'name' => $validated['name'],
            'slug' => $slug,
            'icon_url' => $validated['icon_url'] ?? null,
            'is_active' => $validated['is_active'] ?? true,
            'created_at' => now(),
        ]);

        $auditLogger->log(
            $request,
            'category.create',
            'category',
            $id,
            "Kategori {$validated['name']} berhasil dibuat.",
            [
                'name' => $validated['name'],
                'slug' => $slug,
            ],
        );

        return back()->with('success', 'Kategori produk berhasil dibuat.');
    }

    public function update(Request $request, AdminAuditLogger $auditLogger, string $category): RedirectResponse
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'slug' => ['nullable', 'string', 'max:255'],
            'icon_url' => ['nullable', 'string', 'url', 'max:1000'],
            'is_active' => ['boolean'],
        ]);

        $db = DB::connection('marketplace');
        $existing = $db->table('categories')->where('id', $category)->firstOrFail();

        $slug = filled($validated['slug'] ?? null)
            ? Str::slug($validated['slug'])
            : Str::slug($validated['name']);

        $slugExists = $db->table('categories')
            ->where('slug', $slug)
            ->where('id', '!=', $category)
            ->exists();

        if ($slugExists) {
            return back()->withErrors(['slug' => 'Slug category sudah digunakan.']);
        }

        $db->table('categories')->where('id', $category)->update([
            'name' => $validated['name'],
            'slug' => $slug,
            'icon_url' => $validated['icon_url'] ?? null,
            'is_active' => $validated['is_active'] ?? true,
        ]);

        $auditLogger->log(
            $request,
            'category.update',
            'category',
            $category,
            "Kategori {$validated['name']} diperbarui.",
            [
                'previous_name' => $existing->name,
                'name' => $validated['name'],
                'slug' => $slug,
            ],
        );

        return back()->with('success', 'Kategori produk berhasil diperbarui.');
    }

    public function destroy(Request $request, AdminAuditLogger $auditLogger, string $category): RedirectResponse
    {
        $db = DB::connection('marketplace');
        $existing = $db->table('categories')->where('id', $category)->firstOrFail();

        $productsCount = $db->table('products')->where('category_id', $category)->count();

        if ($productsCount > 0) {
            // Soft deactivate if products exist
            $db->table('categories')->where('id', $category)->update(['is_active' => false]);

            $auditLogger->log(
                $request,
                'category.deactivate',
                'category',
                $category,
                "Kategori {$existing->name} dinonaktifkan karena digunakan oleh {$productsCount} produk.",
                ['name' => $existing->name],
            );

            return back()->with('success', "Kategori dinonaktifkan karena terdapat {$productsCount} produk terhubung.");
        }

        $db->table('categories')->where('id', $category)->delete();

        $auditLogger->log(
            $request,
            'category.delete',
            'category',
            $category,
            "Kategori {$existing->name} dihapus.",
            ['name' => $existing->name],
        );

        return back()->with('success', 'Kategori produk berhasil dihapus.');
    }
}
