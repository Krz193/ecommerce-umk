import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/store/providers/store_provider.dart';

class SellerRecommendationsPage extends ConsumerStatefulWidget {
  final String? storeId;

  const SellerRecommendationsPage({super.key, this.storeId});

  @override
  ConsumerState<SellerRecommendationsPage> createState() =>
      _SellerRecommendationsPageState();
}

class _SellerRecommendationsPageState
    extends ConsumerState<SellerRecommendationsPage> {
  double _wSold = 0.35;
  double _wRating = 0.25;
  double _wCart = 0.20;
  double _wDiscount = 0.10;
  double _wStock = 0.10;
  int _topNCount = 3;
  bool _isSavingBatch = false;

  /// Weighted Formula Score (0 - 100 scale):
  /// Score = w1*Norm(Sold) + w2*Norm(Rating) + w3*Norm(Cart) + w4*Norm(Discount) + w5*Norm(Stock)
  double computeFormulaScore(
    Map<String, dynamic> item, {
    required int maxSold,
    required int maxCart,
    required int maxStock,
  }) {
    final sold = (item['sold_qty'] as num?)?.toDouble() ?? 0;
    final rating = (item['avg_rating'] as num?)?.toDouble() ?? 0;
    final cart = (item['cart_qty'] as num?)?.toDouble() ?? 0;
    final stock = (item['stock'] as num?)?.toDouble() ?? 0;
    final price = (item['price'] as num?)?.toDouble() ?? 0;
    final originalPrice = (item['original_price'] as num?)?.toDouble() ?? price;
    final discountPct = (item['discount_percent'] as num?)?.toDouble() ?? 0;

    final effectiveDiscountPct = discountPct > 0
        ? discountPct
        : (originalPrice > price && originalPrice > 0
              ? ((originalPrice - price) / originalPrice) * 100
              : 0.0);

    final normSold = maxSold > 0 ? (sold / maxSold).clamp(0.0, 1.0) : 0.0;
    final normRating = (rating / 5.0).clamp(0.0, 1.0);
    final normCart = maxCart > 0 ? (cart / maxCart).clamp(0.0, 1.0) : 0.0;
    final normDiscount = (effectiveDiscountPct / 50.0).clamp(0.0, 1.0);
    final normStock = maxStock > 0 ? (stock / maxStock).clamp(0.0, 1.0) : 0.0;

    final totalWeight = _wSold + _wRating + _wCart + _wDiscount + _wStock;
    if (totalWeight <= 0) return 0;

    final weighted =
        (_wSold * normSold) +
        (_wRating * normRating) +
        (_wCart * normCart) +
        (_wDiscount * normDiscount) +
        (_wStock * normStock);

    return double.parse(((weighted / totalWeight) * 100).toStringAsFixed(1));
  }

  Future<void> _applyFormulaRecommendations(
    String targetStoreId,
    List<Map<String, dynamic>> rawItems,
  ) async {
    setState(() {
      _isSavingBatch = true;
    });

    try {
      final service = ref.read(storeServiceProvider);
      final maxSold = rawItems.fold<int>(
        1,
        (m, e) => ((e['sold_qty'] as num?)?.toInt() ?? 0) > m
            ? (e['sold_qty'] as num).toInt()
            : m,
      );
      final maxCart = rawItems.fold<int>(
        1,
        (m, e) => ((e['cart_qty'] as num?)?.toInt() ?? 0) > m
            ? (e['cart_qty'] as num).toInt()
            : m,
      );
      final maxStock = rawItems.fold<int>(
        1,
        (m, e) => ((e['stock'] as num?)?.toInt() ?? 0) > m
            ? (e['stock'] as num).toInt()
            : m,
      );

      final scored =
          rawItems.map((item) {
            final score = computeFormulaScore(
              item,
              maxSold: maxSold,
              maxCart: maxCart,
              maxStock: maxStock,
            );
            return {...item, '_computed_score': score};
          }).toList()..sort(
            (a, b) => (b['_computed_score'] as double).compareTo(
              a['_computed_score'] as double,
            ),
          );

      for (var i = 0; i < scored.length; i++) {
        final item = scored[i];
        final productId = item['product_id'] as String;
        final score = item['_computed_score'] as double;
        final isTop = i < _topNCount && (item['stock'] as num? ?? 0) > 0;

        if (isTop) {
          await service.saveProductRecommendation(
            productId: productId,
            priority: score.round(),
            badgeText: i == 0
                ? 'Top Rekomendasi (${score.toStringAsFixed(0)} Poin)'
                : 'Rekomendasi UMK (${score.toStringAsFixed(0)} Poin)',
            isActive: true,
            formulaScore: score,
            formulaMode: 'formula',
            formulaBreakdown: {
              'w_sold': _wSold,
              'w_rating': _wRating,
              'w_cart': _wCart,
              'w_discount': _wDiscount,
              'w_stock': _wStock,
              'rank': i + 1,
            },
          );
        } else if (item['recommendation_id'] != null &&
            item['formula_mode'] == 'formula') {
          await service.removeProductRecommendation(productId);
        }
      }

      ref.invalidate(storeRecommendationMetricsProvider(targetStoreId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Top $_topNCount produk berhasil direkomendasikan dengan Model Rumus!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menerapkan rumus rekomendasi: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingBatch = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final managedStoreAsync = ref.watch(managedStoreProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rekomendasi Produk (Model Rumus)'),
      ),
      body: managedStoreAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Gagal memuat toko: $err')),
        data: (managedStore) {
          final targetStoreId = widget.storeId ?? managedStore?.id;
          if (targetStoreId == null || targetStoreId.isEmpty) {
            return const Center(
              child: Text('Toko UMK belum dipilih atau belum terdaftar.'),
            );
          }

          final metricsAsync = ref.watch(
            storeRecommendationMetricsProvider(targetStoreId),
          );

          return metricsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Gagal memuat produk: $err')),
            data: (items) {
              final maxSold = items.fold<int>(
                1,
                (m, e) => ((e['sold_qty'] as num?)?.toInt() ?? 0) > m
                    ? (e['sold_qty'] as num).toInt()
                    : m,
              );
              final maxCart = items.fold<int>(
                1,
                (m, e) => ((e['cart_qty'] as num?)?.toInt() ?? 0) > m
                    ? (e['cart_qty'] as num).toInt()
                    : m,
              );
              final maxStock = items.fold<int>(
                1,
                (m, e) => ((e['stock'] as num?)?.toInt() ?? 0) > m
                    ? (e['stock'] as num).toInt()
                    : m,
              );

              final scoredItems =
                  items.map((item) {
                    final score = computeFormulaScore(
                      item,
                      maxSold: maxSold,
                      maxCart: maxCart,
                      maxStock: maxStock,
                    );
                    return {...item, '_computed_score': score};
                  }).toList()..sort(
                    (a, b) => (b['_computed_score'] as double).compareTo(
                      a['_computed_score'] as double,
                    ),
                  );

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(
                    storeRecommendationMetricsProvider(targetStoreId),
                  );
                },
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildFormulaConfigCard(targetStoreId, items),
                    const SizedBox(height: 16),
                    const Text(
                      'Peringkat Skor Rumus & Status Rekomendasi Produk',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (scoredItems.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Belum ada produk di toko ini.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else
                      ...scoredItems.asMap().entries.map((entry) {
                        final rank = entry.key + 1;
                        final item = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildProductScoreCard(
                            context,
                            targetStoreId,
                            rank,
                            item,
                          ),
                        );
                      }),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFormulaConfigCard(
    String targetStoreId,
    List<Map<String, dynamic>> rawItems,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.indigo.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.functions, color: Colors.indigo.shade800),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Model Rumus Rekomendasi Produk UMK',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Skor (0–100) = w1·Terjual + w2·Rating + w3·Keranjang + w4·Diskon + w5·Stok',
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
              color: Colors.indigo.shade800,
            ),
          ),
          const SizedBox(height: 12),
          _buildWeightSlider(
            label: 'Bobot Penjualan (w1)',
            value: _wSold,
            onChanged: (v) => setState(() => _wSold = v),
          ),
          _buildWeightSlider(
            label: 'Bobot Rating Ulasan (w2)',
            value: _wRating,
            onChanged: (v) => setState(() => _wRating = v),
          ),
          _buildWeightSlider(
            label: 'Bobot Minat Keranjang (w3)',
            value: _wCart,
            onChanged: (v) => setState(() => _wCart = v),
          ),
          _buildWeightSlider(
            label: 'Bobot Besaran Diskon (w4)',
            value: _wDiscount,
            onChanged: (v) => setState(() => _wDiscount = v),
          ),
          _buildWeightSlider(
            label: 'Bobot Ketersediaan Stok (w5)',
            value: _wStock,
            onChanged: (v) => setState(() => _wStock = v),
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Jumlah Top Produk Otomatis:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              DropdownButton<int>(
                value: _topNCount,
                items: const [1, 2, 3, 5, 10]
                    .map(
                      (n) => DropdownMenuItem(
                        value: n,
                        child: Text('Top $n Produk'),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _topNCount = val);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_isSavingBatch || rawItems.isEmpty)
                  ? null
                  : () => _applyFormulaRecommendations(targetStoreId, rawItems),
              icon: _isSavingBatch
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_fix_high),
              label: const Text('Terapkan Rekomendasi Otomatis (Model Rumus)'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightSlider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 170,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: 0,
            max: 1,
            divisions: 20,
            label: '${(value * 100).round()}%',
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            '${(value * 100).round()}%',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildProductScoreCard(
    BuildContext context,
    String targetStoreId,
    int rank,
    Map<String, dynamic> item,
  ) {
    final productId = item['product_id'] as String;
    final name = item['product_name'] as String? ?? 'Produk';
    final price = (item['price'] as num?)?.toInt() ?? 0;
    final soldQty = (item['sold_qty'] as num?)?.toInt() ?? 0;
    final avgRating = (item['avg_rating'] as num?)?.toDouble() ?? 0;
    final cartQty = (item['cart_qty'] as num?)?.toInt() ?? 0;
    final stock = (item['stock'] as num?)?.toInt() ?? 0;
    final discountPct = (item['discount_percent'] as num?)?.toDouble() ?? 0;
    final score = item['_computed_score'] as double? ?? 0;
    final isRecommended = item['is_recommended'] == true;
    final badgeText = item['badge_text'] as String?;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isRecommended ? Colors.amber.shade600 : Colors.grey.shade200,
          width: isRecommended ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: rank <= 3
                      ? Colors.amber.shade700
                      : Colors.grey.shade300,
                  child: Text(
                    '#$rank',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: rank <= 3 ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(price),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(
                        score.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo.shade900,
                        ),
                      ),
                      Text(
                        'Skor Rumus',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.indigo.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildFactorChip('Terjual: $soldQty'),
                _buildFactorChip('Rating: ${avgRating.toStringAsFixed(1)}★'),
                _buildFactorChip('Di Keranjang: $cartQty'),
                _buildFactorChip('Diskon: ${discountPct.toStringAsFixed(0)}%'),
                _buildFactorChip('Stok: $stock'),
              ],
            ),
            const Divider(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    isRecommended
                        ? 'Aktif Direkomendasikan (${badgeText ?? "Pilihan UMK"})'
                        : 'Belum direkomendasikan di etalase utama',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isRecommended
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isRecommended
                          ? Colors.amber.shade900
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
                Switch(
                  value: isRecommended,
                  onChanged: (nextValue) async {
                    final service = ref.read(storeServiceProvider);
                    if (nextValue) {
                      await service.saveProductRecommendation(
                        productId: productId,
                        priority: score.round(),
                        badgeText:
                            'Pilihan UMK (${score.toStringAsFixed(0)} Poin)',
                        isActive: true,
                        formulaScore: score,
                        formulaMode: 'manual',
                      );
                    } else {
                      await service.removeProductRecommendation(productId);
                    }
                    ref.invalidate(
                      storeRecommendationMetricsProvider(targetStoreId),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFactorChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
      ),
    );
  }
}
