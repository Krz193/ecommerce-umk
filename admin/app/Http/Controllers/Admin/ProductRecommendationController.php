<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\ProductRecommendation;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Illuminate\Support\Str;

class ProductRecommendationController extends Controller
{
    public function index(Request $request)
    {
        $query = ProductRecommendation::with('product.store');

        if ($request->has('search') && $request->search != '') {
            $search = $request->search;
            $query->whereHas('product', function ($q) use ($search) {
                $q->where('name', 'ilike', '%' . $search . '%')
                  ->orWhereHas('store', function ($sq) use ($search) {
                      $sq->where('name', 'ilike', '%' . $search . '%');
                  });
            });
        }

        $recommendations = $query->orderBy('priority', 'desc')
                                 ->orderBy('created_at', 'desc')
                                 ->paginate(15)
                                 ->withQueryString();

        $availableProducts = Product::with('store')->select('id', 'name', 'store_id')->limit(100)->get();

        return Inertia::render('admin/recommendations/index', [
            'recommendations' => $recommendations,
            'filters' => $request->only(['search']),
            'availableProducts' => $availableProducts
        ]);
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'product_id' => 'required|exists:marketplace.products,id|unique:marketplace.product_recommendations,product_id',
            'priority' => 'required|integer|min:0',
            'badge_text' => 'nullable|string|max:255',
            'is_active' => 'required|boolean',
        ]);

        $validated['id'] = Str::uuid()->toString();

        ProductRecommendation::create($validated);

        return redirect()->back()->with('success', 'Rekomendasi produk berhasil ditambahkan.');
    }

    public function update(Request $request, ProductRecommendation $recommendation)
    {
        $validated = $request->validate([
            'priority' => 'required|integer|min:0',
            'badge_text' => 'nullable|string|max:255',
            'is_active' => 'required|boolean',
        ]);

        $recommendation->update($validated);

        return redirect()->back()->with('success', 'Rekomendasi produk berhasil diperbarui.');
    }

    public function destroy(ProductRecommendation $recommendation)
    {
        $recommendation->delete();
        return redirect()->back()->with('success', 'Rekomendasi produk berhasil dihapus.');
    }
}
