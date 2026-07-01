import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/features/product/providers/product_detail_provider.dart';
import 'package:mobile/features/cart/services/cart_service.dart';
import 'package:mobile/features/cart/providers/cart_provider.dart';
import 'package:mobile/features/cart/widgets/cart_action_button.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/product/models/product_model.dart';
import 'package:mobile/features/store/providers/store_provider.dart';

class ProductDetailPage extends ConsumerStatefulWidget {
  final String productId;
  static final cartService = CartService();

  const ProductDetailPage({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends ConsumerState<ProductDetailPage> {
  String? selectedImageUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Detail'),

        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: CartActionButton(),
          ),
        ],
      ),
      bottomNavigationBar: ref
          .watch(productDetailProvider(widget.productId))
          .maybeWhen(
            data: (product) {
              return SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: const BoxDecoration(color: Colors.white),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: product.stock <= 0
                          ? null
                          : () async {
                              try {
                                await ProductDetailPage.cartService.addToCart(
                                  productId: product.id,
                                  storeId: product.storeId,
                                );

                                ref.invalidate(cartProvider);

                                if (!context.mounted) {
                                  return;
                                }

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Added to cart'),
                                  ),
                                );
                              } catch (error) {
                                if (!context.mounted) {
                                  return;
                                }

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(error.toString())),
                                );
                              }
                            },
                      child: Text(
                        product.stock <= 0 ? 'Out of Stock' : 'Add To Cart',
                      ),
                    ),
                  ),
                ),
              );
            },
            orElse: () => null,
          ),

      body: ref
          .watch(productDetailProvider(widget.productId))
          .when(
            data: (product) {
              final previewImageUrl =
                  selectedImageUrl ??
                  product.thumbnailUrl ??
                  firstImage(product);

              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (previewImageUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        previewImageUrl,
                        height: 280,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 220,
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: const Text('Image unavailable'),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],

                  Text(
                    product.name,

                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    CurrencyFormatter.format(product.price),

                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  if (product.images.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Photos',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 84,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: product.images.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final image = product.images[index];
                          final isSelected =
                              (selectedImageUrl ?? product.thumbnailUrl) ==
                              image.imageUrl;

                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setState(() {
                                selectedImageUrl = image.imageUrl;
                              });
                            },
                            child: Container(
                              width: 84,
                              height: 84,
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  image.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey.shade200,
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.image_not_supported_outlined,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  buildDescriptionSection(product),

                  const SizedBox(height: 96),
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

  Widget buildDescriptionSection(ProductModel product) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Description',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(product.description ?? 'No description'),
          if (hasCharacteristics(product)) ...[
            const SizedBox(height: 16),
            const Text(
              'Characteristics',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (product.productType?.isNotEmpty == true)
                  Chip(label: Text('Type: ${product.productType}')),
                if (product.size?.isNotEmpty == true)
                  Chip(label: Text('Size: ${product.size}')),
                if (product.color?.isNotEmpty == true)
                  Chip(label: Text('Color: ${product.color}')),
              ],
            ),
          ],
          const SizedBox(height: 16),
          buildStockNotice(product),
          if (product.categoryName != null) ...[
            const SizedBox(height: 12),
            Chip(label: Text(product.categoryName!)),
          ],
          const SizedBox(height: 16),
          buildStoreSummary(product.storeId),
        ],
      ),
    );
  }

  bool hasCharacteristics(ProductModel product) {
    return product.productType?.isNotEmpty == true ||
        product.size?.isNotEmpty == true ||
        product.color?.isNotEmpty == true;
  }

  String? firstImage(ProductModel product) {
    if (product.images.isEmpty) {
      return null;
    }

    final images = [...product.images]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return images.first.imageUrl;
  }

  Widget buildStockNotice(ProductModel product) {
    final (label, color, icon) = switch (product.stock) {
      <= 0 => ('Out of stock', Colors.red, Icons.remove_shopping_cart_outlined),
      <= 5 => (
        'Low stock: ${product.stock} left',
        Colors.orange,
        Icons.warning_amber_outlined,
      ),
      _ => (
        'Stock: ${product.stock}',
        Colors.green,
        Icons.check_circle_outline,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget buildStoreSummary(String storeId) {
    final storeAsync = ref.watch(publicStoreProvider(storeId));

    return storeAsync.when(
      data: (store) {
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            context.push('/stores/$storeId');
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.storefront_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (store.description?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          store.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        );
      },
      error: (error, stackTrace) {
        return OutlinedButton.icon(
          onPressed: () {
            context.push('/stores/$storeId');
          },
          icon: const Icon(Icons.storefront_outlined),
          label: const Text('Visit Store'),
        );
      },
      loading: () => const LinearProgressIndicator(),
    );
  }
}
