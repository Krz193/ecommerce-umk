import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/providers/product_recommendation_provider.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/cart/widgets/cart_action_button.dart';
import 'package:mobile/features/explore/explore_providers.dart';
import 'package:mobile/features/product/models/product_model.dart';
import 'package:mobile/features/product/providers/category_provider.dart';
import 'package:mobile/features/product/providers/product_provider.dart';
import 'package:mobile/features/product/providers/product_review_providers.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final searchController = TextEditingController();
  final minPriceController = TextEditingController();
  final maxPriceController = TextEditingController();

  String searchQuery = '';
  String? selectedCategoryId;
  int? minPrice;
  int? maxPrice;
  _ProductSort sort = _ProductSort.newest;
  bool inStockOnly = false;
  bool promoOnly = false;

  @override
  void dispose() {
    searchController.dispose();
    minPriceController.dispose();
    maxPriceController.dispose();
    super.dispose();
  }

  List<ProductModel> visibleProducts(List<ProductModel> products) {
    final filtered = products.where((product) {
      final matchesQuery = product.matchesSearchQuery(searchQuery);
      final matchesStock = !inStockOnly || product.stock > 0;
      final matchesPromo = !promoOnly || product.hasDiscount;
      final matchesCategory =
          selectedCategoryId == null ||
          product.categoryId == selectedCategoryId;
      final matchesMinPrice = minPrice == null || product.price >= minPrice!;
      final matchesMaxPrice = maxPrice == null || product.price <= maxPrice!;

      return matchesQuery &&
          matchesStock &&
          matchesPromo &&
          matchesCategory &&
          matchesMinPrice &&
          matchesMaxPrice;
    }).toList();

    switch (sort) {
      case _ProductSort.newest:
        return filtered;
      case _ProductSort.priceLow:
        filtered.sort((a, b) => a.price.compareTo(b.price));
        return filtered;
      case _ProductSort.priceHigh:
        filtered.sort((a, b) => b.price.compareTo(a.price));
        return filtered;
      case _ProductSort.stockHigh:
        filtered.sort((a, b) => b.stock.compareTo(a.stock));
        return filtered;
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'E-commerce UMK',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: const [CartActionButton()],
      ),
      body: ref
          .watch(productsProvider)
          .when(
            data: (products) {
              final visible = visibleProducts(products);
              final recommendedAsync = ref.watch(
                productRecommendationsProvider,
              );

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Broadened Search Bar (#7)
                  TextField(
                    controller: searchController,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.primary,
                      ),
                      hintText:
                          'Cari produk, kategori, toko UMK, warna, ukuran, atau promo...',
                      suffixIcon: searchQuery.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Bersihkan pencarian',
                              onPressed: () {
                                searchController.clear();
                                setState(() {
                                  searchQuery = '';
                                });
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                      });
                    },
                  ),

                  const SizedBox(height: 12),

                  // Standardized Promo & Info UMK Banner Slider (#8)
                  _buildPromoBannerCarousel(context, ref),

                  const SizedBox(height: 12),

                  // Filters & Sort Bar
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilterChip(
                        label: const Text('Stok Tersedia'),
                        selected: inStockOnly,
                        selectedColor: AppColors.primaryLight,
                        checkmarkColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: inStockOnly
                              ? AppColors.primaryHover
                              : AppColors.textPrimary,
                          fontWeight: inStockOnly
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 13,
                        ),
                        onSelected: (value) {
                          setState(() {
                            inStockOnly = value;
                          });
                        },
                      ),
                      FilterChip(
                        label: const Text('Sedang Promo 🏷️'),
                        selected: promoOnly,
                        selectedColor: Colors.amber.shade100,
                        checkmarkColor: Colors.amber.shade900,
                        labelStyle: TextStyle(
                          color: promoOnly
                              ? Colors.amber.shade900
                              : AppColors.textPrimary,
                          fontWeight: promoOnly
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 13,
                        ),
                        onSelected: (value) {
                          setState(() {
                            promoOnly = value;
                          });
                        },
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<_ProductSort>(
                            value: sort,
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppColors.primary,
                            ),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontFamily: 'Poppins',
                            ),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                sort = value;
                              });
                            },
                            items: const [
                              DropdownMenuItem(
                                value: _ProductSort.newest,
                                child: Text('Terbaru'),
                              ),
                              DropdownMenuItem(
                                value: _ProductSort.priceLow,
                                child: Text('Harga Rendah → Tinggi'),
                              ),
                              DropdownMenuItem(
                                value: _ProductSort.priceHigh,
                                child: Text('Harga Tinggi → Rendah'),
                              ),
                              DropdownMenuItem(
                                value: _ProductSort.stockHigh,
                                child: Text('Stok Terbanyak'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (searchQuery.isNotEmpty ||
                          selectedCategoryId != null ||
                          inStockOnly ||
                          promoOnly ||
                          minPrice != null ||
                          maxPrice != null)
                        TextButton.icon(
                          onPressed: clearFilters,
                          icon: const Icon(
                            Icons.filter_alt_off_outlined,
                            size: 16,
                          ),
                          label: const Text('Reset'),
                        ),
                    ],
                  ),

                  // Categories Horizontal Bar
                  categoriesAsync.when(
                    data: (categories) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ChoiceChip(
                                label: const Text('Semua Kategori'),
                                selected: selectedCategoryId == null,
                                selectedColor: AppColors.primaryLight,
                                labelStyle: TextStyle(
                                  color: selectedCategoryId == null
                                      ? AppColors.primaryHover
                                      : AppColors.textPrimary,
                                  fontWeight: selectedCategoryId == null
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 13,
                                ),
                                onSelected: (_) {
                                  setState(() {
                                    selectedCategoryId = null;
                                  });
                                },
                              ),
                              const SizedBox(width: 8),
                              ...categories.map((category) {
                                final isSelected =
                                    selectedCategoryId == category.id;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(category.name),
                                    selected: isSelected,
                                    selectedColor: AppColors.primaryLight,
                                    labelStyle: TextStyle(
                                      color: isSelected
                                          ? AppColors.primaryHover
                                          : AppColors.textPrimary,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                    onSelected: (_) {
                                      setState(() {
                                        selectedCategoryId = category.id;
                                      });
                                    },
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      );
                    },
                    error: (error, stackTrace) => const SizedBox.shrink(),
                    loading: () => const LinearProgressIndicator(),
                  ),

                  const SizedBox(height: 20),

                  // Recommended Products Horizontal Scroll
                  recommendedAsync.when(
                    data: (recommendedItems) {
                      if (recommendedItems.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.recommend_rounded,
                                color: AppColors.primary,
                                size: 22,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Rekomendasi Produk',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 256,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: recommendedItems.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (context, index) {
                                final recommendation = recommendedItems[index];
                                if (recommendation.product == null) {
                                  return const SizedBox.shrink();
                                }

                                return SizedBox(
                                  width: 165,
                                  child: Stack(
                                    children: [
                                      _ShopeeProductCard(
                                        product: recommendation.product!,
                                        isRecommended: true,
                                      ),
                                      if (recommendation.badgeText != null &&
                                          recommendation.badgeText!.isNotEmpty)
                                        Positioned(
                                          top: 0,
                                          left: 0,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: const BoxDecoration(
                                              color: Colors.amber,
                                              borderRadius: BorderRadius.only(
                                                topLeft: Radius.circular(8),
                                                bottomRight: Radius.circular(8),
                                              ),
                                            ),
                                            child: Text(
                                              recommendation.badgeText!,
                                              style: const TextStyle(
                                                color: Colors.black87,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      );
                    },
                    error: (error, stack) => const SizedBox.shrink(),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                  ),

                  // Main Product Title
                  Row(
                    children: [
                      const Icon(
                        Icons.grid_view_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Semua Produk',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${visible.length} produk',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (products.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'Belum ada produk yang dipublikasi.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ),

                  if (products.isNotEmpty && visible.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'Tidak ada produk yang cocok dengan pencarian.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ),

                  // Shopee-Style 2 Column Grid View Layout
                  if (visible.isNotEmpty)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: visible.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.62,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                          ),
                      itemBuilder: (context, index) {
                        return _ShopeeProductCard(product: visible[index]);
                      },
                    ),

                  const SizedBox(height: 24),
                ],
              );
            },
            error: (error, stackTrace) => Center(child: Text(error.toString())),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
    );
  }

  Widget _buildPromoBannerCarousel(BuildContext context, WidgetRef ref) {
    final bannersAsync = ref.watch(publicHomeBannersProvider);

    return bannersAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => const SizedBox.shrink(),
      data: (banners) {
        if (banners.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.campaign_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Sorotan Promosi Produk & Informasi UMK',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/explore'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(50, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Lihat Semua',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 148,
              margin: const EdgeInsets.only(bottom: 4),
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.trackpad,
                  },
                ),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: banners.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final banner = banners[index];
                    final coverUrl = banner.displayCoverUrl;
                    final hasPhoto = coverUrl != null;
                    final hasProduct =
                        banner.productId != null &&
                        banner.productId!.isNotEmpty;

                    return Container(
                      width: 286,
                      decoration: BoxDecoration(
                        color: hasPhoto
                            ? const Color(0xFF0F172A)
                            : (hasProduct
                                  ? Colors.amber.shade50
                                  : AppColors.primaryLight),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: hasPhoto
                              ? Colors.transparent
                              : (hasProduct
                                    ? Colors.amber.shade300
                                    : AppColors.primary.withAlpha(60)),
                        ),
                      ),
                      child: Stack(
                        children: [
                          if (hasPhoto)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(
                                coverUrl,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const SizedBox.shrink(),
                              ),
                            )
                          else
                            Positioned(
                              right: -10,
                              bottom: -10,
                              child: Icon(
                                hasProduct
                                    ? Icons.local_offer_rounded
                                    : banner.contentType == 'storytelling'
                                    ? Icons.auto_stories_rounded
                                    : Icons.campaign_rounded,
                                size: 110,
                                color: AppColors.primary.withAlpha(35),
                              ),
                            ),
                          if (hasPhoto)
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.black.withAlpha(205),
                                    Colors.black.withAlpha(65),
                                  ],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: hasProduct
                                            ? Colors.amber.shade800
                                            : Colors.teal.shade700,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        hasProduct
                                            ? 'PROMO PRODUK 🏷️'
                                            : 'INFO & KISAH UMK 📖',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withAlpha(90),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        banner.mediaFormatLabel,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                Text(
                                  banner.title,
                                  style: TextStyle(
                                    color: hasPhoto
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        hasProduct &&
                                                banner.productName != null
                                            ? '${banner.productName} • ${banner.storeName ?? "Toko UMK"}'
                                            : (banner.storeName ?? 'Toko UMK'),
                                        style: TextStyle(
                                          color: hasPhoto
                                              ? Colors.white70
                                              : AppColors.textSecondary,
                                          fontSize: 11,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (hasProduct &&
                                        banner.productPrice != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withAlpha(230),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          CurrencyFormatter.format(
                                            banner.productPrice!,
                                          ),
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Positioned.fill(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  if (hasProduct) {
                                    context.push(
                                      '/products/${banner.productId}',
                                    );
                                  } else {
                                    context.push('/store/${banner.storeId}');
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void clearFilters() {
    searchController.clear();
    minPriceController.clear();
    maxPriceController.clear();

    setState(() {
      searchQuery = '';
      selectedCategoryId = null;
      minPrice = null;
      maxPrice = null;
      inStockOnly = false;
      promoOnly = false;
      sort = _ProductSort.newest;
    });
  }
}

class _ShopeeProductCard extends ConsumerWidget {
  final ProductModel product;
  final bool isRecommended;

  const _ShopeeProductCard({required this.product, this.isRecommended = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(productReviewStatsProvider(product.id));

    return GestureDetector(
      onTap: () {
        context.push('/products/${product.id}');
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Product Image with Badges
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: product.thumbnailUrl != null
                        ? Image.network(
                            product.thumbnailUrl!,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildImagePlaceholder();
                            },
                          )
                        : _buildImagePlaceholder(),
                  ),
                  if (isRecommended)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Rekomendasi',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (product.hasDiscount && product.stock > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          product.effectiveDiscountPercent > 0
                              ? '-${product.effectiveDiscountPercent.toStringAsFixed(0)}%'
                              : 'PROMO',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (product.stock <= 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Habis',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Bottom Product Details
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (product.categoryName != null)
                        Expanded(
                          child: Text(
                            product.categoryName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.primaryHover,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (product.storeName != null &&
                          product.storeName!.isNotEmpty)
                        Flexible(
                          child: Text(
                            product.storeName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      height: 1.25,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          CurrencyFormatter.format(product.price),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      if (product.hasDiscount) ...[
                        const SizedBox(width: 4),
                        Text(
                          CurrencyFormatter.format(
                            product.effectiveOriginalPrice,
                          ),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textMuted,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(
                        Icons.star_rounded,
                        color: stats.totalReviews > 0
                            ? Colors.amber.shade700
                            : Colors.grey.shade400,
                        size: 14,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        stats.totalReviews > 0
                            ? '${stats.averageRating}'
                            : 'New',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        product.stock > 0 ? 'Stok: ${product.stock}' : 'Habis',
                        style: TextStyle(
                          fontSize: 11,
                          color: product.stock > 0
                              ? AppColors.textSecondary
                              : AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.grey.shade100,
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_outlined,
        color: AppColors.textMuted,
        size: 32,
      ),
    );
  }
}

enum _ProductSort { newest, priceLow, priceHigh, stockHigh }
