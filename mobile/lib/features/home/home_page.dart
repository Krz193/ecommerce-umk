import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/cart/widgets/cart_action_button.dart';
import 'package:mobile/features/product/models/product_model.dart';
import 'package:mobile/features/product/providers/category_provider.dart';
import 'package:mobile/features/product/providers/product_provider.dart';
import 'package:go_router/go_router.dart';

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

  @override
  void dispose() {
    searchController.dispose();
    minPriceController.dispose();
    maxPriceController.dispose();

    super.dispose();
  }

  List<ProductModel> visibleProducts(List<ProductModel> products) {
    final filtered = products.where((product) {
      final query = searchQuery.trim().toLowerCase();
      final matchesQuery =
          query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          (product.description?.toLowerCase().contains(query) ?? false);

      final matchesStock = !inStockOnly || product.stock > 0;

      final matchesCategory =
          selectedCategoryId == null ||
          product.categoryId == selectedCategoryId;

      final matchesMinPrice = minPrice == null || product.price >= minPrice!;
      final matchesMaxPrice = maxPrice == null || product.price <= maxPrice!;

      return matchesQuery &&
          matchesStock &&
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

  List<ProductModel> recommendedProducts(List<ProductModel> products) {
    final recommended =
        products
            .where((product) => product.stock > 0)
            .where(
              (product) =>
                  selectedCategoryId == null ||
                  product.categoryId == selectedCategoryId,
            )
            .toList()
          ..sort((a, b) {
            final stockCompare = b.stock.compareTo(a.stock);

            if (stockCompare != 0) {
              return stockCompare;
            }

            return a.price.compareTo(b.price);
          });

    return recommended.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [const CartActionButton()],
      ),
      body: ref
          .watch(productsProvider)
          .when(
            data: (products) {
              final visible = visibleProducts(products);
              final recommended = recommendedProducts(products);

              return ListView(
                padding: const EdgeInsets.all(16),

                children: [
                  TextField(
                    controller: searchController,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      labelText: 'Search products',
                      suffixIcon: searchQuery.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                searchController.clear();
                                setState(() {
                                  searchQuery = '';
                                });
                              },
                              icon: const Icon(Icons.close),
                            ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                      });
                    },
                  ),

                  const SizedBox(height: 12),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilterChip(
                        label: const Text('In stock'),
                        selected: inStockOnly,
                        onSelected: (value) {
                          setState(() {
                            inStockOnly = value;
                          });
                        },
                      ),
                      DropdownButton<_ProductSort>(
                        value: sort,
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }

                          setState(() {
                            sort = value;
                          });
                        },
                        items: const [
                          DropdownMenuItem(
                            value: _ProductSort.newest,
                            child: Text('Newest'),
                          ),
                          DropdownMenuItem(
                            value: _ProductSort.priceLow,
                            child: Text('Price low to high'),
                          ),
                          DropdownMenuItem(
                            value: _ProductSort.priceHigh,
                            child: Text('Price high to low'),
                          ),
                          DropdownMenuItem(
                            value: _ProductSort.stockHigh,
                            child: Text('Most stock'),
                          ),
                        ],
                      ),
                      OutlinedButton.icon(
                        onPressed: clearFilters,
                        icon: const Icon(Icons.filter_alt_off_outlined),
                        label: const Text('Clear'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: minPriceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Min price',
                            prefixText: 'Rp ',
                          ),
                          onChanged: (value) {
                            setState(() {
                              minPrice = int.tryParse(value.trim());
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: maxPriceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Max price',
                            prefixText: 'Rp ',
                          ),
                          onChanged: (value) {
                            setState(() {
                              maxPrice = int.tryParse(value.trim());
                            });
                          },
                        ),
                      ),
                    ],
                  ),

                  categoriesAsync.when(
                    data: (categories) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ChoiceChip(
                                label: const Text('All Categories'),
                                selected: selectedCategoryId == null,
                                onSelected: (_) {
                                  setState(() {
                                    selectedCategoryId = null;
                                  });
                                },
                              ),
                              const SizedBox(width: 8),
                              ...categories.map((category) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(category.name),
                                    selected: selectedCategoryId == category.id,
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
                    error: (error, stackTrace) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(error.toString()),
                      );
                    },
                    loading: () {
                      return const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: LinearProgressIndicator(),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  if (recommended.isNotEmpty) ...[
                    const Text(
                      'Recommended Products',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 260,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: recommended.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          return SizedBox(
                            width: 220,
                            child: buildProductCard(
                              context,
                              recommended[index],
                              isCompact: true,
                              isRecommended: true,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (products.isEmpty)
                    const Center(child: Text('No published products yet')),

                  if (products.isNotEmpty && visible.isEmpty)
                    const Center(child: Text('No matching products')),

                  ...visible.map((product) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: buildProductCard(context, product),
                    );
                  }),
                ],
              );
            },

            error: (error, stackTrace) {
              return Center(child: Text(error.toString()));
            },

            loading: () {
              return const Center(child: CircularProgressIndicator());
            },
          ),
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
      sort = _ProductSort.newest;
    });
  }

  Widget buildProductCard(
    BuildContext context,
    ProductModel product, {
    bool isCompact = false,
    bool isRecommended = false,
  }) {
    return GestureDetector(
      onTap: () {
        context.push('/products/${product.id}');
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    product.name,
                    maxLines: isCompact ? 2 : null,
                    overflow: isCompact ? TextOverflow.ellipsis : null,
                    style: TextStyle(
                      fontSize: isCompact ? 16 : 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isRecommended) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.recommend_outlined, size: 18),
                ],
              ],
            ),
            if (product.thumbnailUrl != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  product.thumbnailUrl!,
                  height: isCompact ? 88 : 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: isCompact ? 88 : 160,
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: const Text('Image unavailable'),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              CurrencyFormatter.format(product.price),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              product.stock > 0 ? 'Stock: ${product.stock}' : 'Out of stock',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: product.stock > 0 ? Colors.grey.shade700 : Colors.red,
              ),
            ),
            if (product.categoryName != null) ...[
              const SizedBox(height: 4),
              Text(
                product.categoryName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (!isCompact && hasCharacteristics(product)) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (product.productType?.isNotEmpty == true)
                    Chip(label: Text(product.productType!)),
                  if (product.size?.isNotEmpty == true)
                    Chip(label: Text(product.size!)),
                  if (product.color?.isNotEmpty == true)
                    Chip(label: Text(product.color!)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool hasCharacteristics(ProductModel product) {
    return product.productType?.isNotEmpty == true ||
        product.size?.isNotEmpty == true ||
        product.color?.isNotEmpty == true;
  }
}

enum _ProductSort { newest, priceLow, priceHigh, stockHigh }
