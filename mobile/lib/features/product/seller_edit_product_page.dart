import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/features/product/models/category_model.dart';
import 'package:mobile/features/product/models/product_model.dart';
import 'package:mobile/features/product/models/stock_movement_model.dart';
import 'package:mobile/features/product/providers/category_provider.dart';
import 'package:mobile/features/product/providers/product_provider.dart';
import 'package:mobile/features/product/providers/seller_product_provider.dart';
import 'package:mobile/features/store/providers/store_provider.dart';

class SellerEditProductPage extends ConsumerStatefulWidget {
  final String productId;

  const SellerEditProductPage({super.key, required this.productId});

  @override
  ConsumerState<SellerEditProductPage> createState() =>
      _SellerEditProductPageState();
}

class _SellerEditProductPageState extends ConsumerState<SellerEditProductPage> {
  final formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();

  final priceController = TextEditingController();

  final stockController = TextEditingController();

  final productTypeController = TextEditingController();

  final sizeController = TextEditingController();

  final colorController = TextEditingController();

  final descriptionController = TextEditingController();

  String? selectedCategoryId;

  bool initialized = false;

  bool isSaving = false;

  bool isUpdatingStatus = false;

  bool isUploadingImage = false;

  bool isRecordingStockIn = false;

  bool isAdjustingStock = false;

  bool isRecordingStockOpname = false;

  String? errorMessage;

  final imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();

    nameController.addListener(clearError);
  }

  @override
  void dispose() {
    nameController.dispose();
    priceController.dispose();
    stockController.dispose();
    productTypeController.dispose();
    sizeController.dispose();
    colorController.dispose();
    descriptionController.dispose();

    super.dispose();
  }

  void initializeForm(ProductModel product) {
    if (initialized) {
      return;
    }

    initialized = true;
    nameController.text = product.name;
    priceController.text = product.price.toString();
    stockController.text = product.stock.toString();
    productTypeController.text = product.productType ?? '';
    sizeController.text = product.size ?? '';
    colorController.text = product.color ?? '';
    descriptionController.text = product.description ?? '';
    selectedCategoryId = product.categoryId;
  }

  String makeSlug(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  void clearError() {
    if (errorMessage == null) {
      return;
    }

    setState(() {
      errorMessage = null;
    });
  }

  String readableError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  ProductModel? findProduct(List<ProductModel> products) {
    for (final product in products) {
      if (product.id == widget.productId) {
        return product;
      }
    }

    return null;
  }

  Future<void> saveProduct(ProductModel product) async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    if (selectedCategoryId == null) {
      setState(() {
        errorMessage = 'Category required';
      });

      return;
    }

    setState(() {
      isSaving = true;
      errorMessage = null;
    });

    try {
      final slug = makeSlug(nameController.text);

      if (slug.isEmpty) {
        throw Exception('Product name must contain letters or numbers');
      }

      final sellerProductService = ref.read(sellerProductServiceProvider);

      await sellerProductService.updateProduct(
        productId: product.id,
        storeId: product.storeId,
        name: nameController.text.trim(),
        slug: slug,
        price: int.parse(priceController.text.trim()),
        categoryId: selectedCategoryId!,
        status: product.status,
        productType: productTypeController.text.trim().isEmpty
            ? null
            : productTypeController.text.trim(),
        size: sizeController.text.trim().isEmpty
            ? null
            : sizeController.text.trim(),
        color: colorController.text.trim().isEmpty
            ? null
            : colorController.text.trim(),
        description: descriptionController.text.trim().isEmpty
            ? null
            : descriptionController.text.trim(),
      );

      ref.invalidate(sellerProductsProvider(product.storeId));
      ref.invalidate(productsProvider);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Product updated')));

      context.pop();
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = readableError(error);

      setState(() {
        errorMessage = message;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Future<void> toggleStatus(ProductModel product) async {
    final nextStatus = product.status == 'published' ? 'draft' : 'published';

    setState(() {
      isUpdatingStatus = true;
      errorMessage = null;
    });

    try {
      final sellerProductService = ref.read(sellerProductServiceProvider);

      await sellerProductService.updateProductStatus(
        productId: product.id,
        storeId: product.storeId,
        status: nextStatus,
      );

      ref.invalidate(sellerProductsProvider(product.storeId));
      ref.invalidate(productsProvider);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextStatus == 'published' ? 'Product published' : 'Product drafted',
          ),
        ),
      );

      context.pop();
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = readableError(error);

      setState(() {
        errorMessage = message;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          isUpdatingStatus = false;
        });
      }
    }
  }

  Future<void> uploadImage(ProductModel product) async {
    final image = await imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1600,
    );

    if (image == null) {
      return;
    }

    setState(() {
      isUploadingImage = true;
      errorMessage = null;
    });

    try {
      final sellerProductService = ref.read(sellerProductServiceProvider);
      final bytes = await image.readAsBytes();
      final extension = image.name.split('.').last;

      final productImage = await sellerProductService.addProductImage(
        productId: product.id,
        storeId: product.storeId,
        bytes: bytes,
        extension: extension,
        sortOrder: product.images.length,
      );

      if (product.thumbnailUrl == null) {
        await sellerProductService.setProductThumbnail(
          productId: product.id,
          imageId: productImage.id,
        );
      }

      ref.invalidate(sellerProductsProvider(product.storeId));
      ref.invalidate(productsProvider);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Product image uploaded')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = readableError(error);

      setState(() {
        errorMessage = message;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          isUploadingImage = false;
        });
      }
    }
  }

  Future<void> setThumbnail(ProductModel product, String imageId) async {
    setState(() {
      isUpdatingStatus = true;
      errorMessage = null;
    });

    try {
      final sellerProductService = ref.read(sellerProductServiceProvider);

      await sellerProductService.setProductThumbnail(
        productId: product.id,
        imageId: imageId,
      );

      ref.invalidate(sellerProductsProvider(product.storeId));
      ref.invalidate(productsProvider);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Thumbnail selected')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = readableError(error);

      setState(() {
        errorMessage = message;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          isUpdatingStatus = false;
        });
      }
    }
  }

  Future<void> deleteImage(ProductModel product, String imageId) async {
    setState(() {
      isUploadingImage = true;
      errorMessage = null;
    });

    try {
      final sellerProductService = ref.read(sellerProductServiceProvider);

      await sellerProductService.deleteProductImage(
        productId: product.id,
        imageId: imageId,
      );

      ref.invalidate(sellerProductsProvider(product.storeId));
      ref.invalidate(productsProvider);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Product image deleted')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = readableError(error);

      setState(() {
        errorMessage = message;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          isUploadingImage = false;
        });
      }
    }
  }

  Future<void> showStockInDialog(ProductModel product) async {
    final result = await showDialog<_StockInDialogResult>(
      context: context,
      builder: (dialogContext) {
        return const _StockInDialog();
      },
    );

    if (result == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    await recordStockIn(
      product: product,
      quantity: result.quantity,
      note: result.note,
    );
  }

  Future<void> recordStockIn({
    required ProductModel product,
    required int quantity,
    required String note,
  }) async {
    setState(() {
      isRecordingStockIn = true;
      errorMessage = null;
    });

    try {
      final sellerProductService = ref.read(sellerProductServiceProvider);

      final updatedProduct = await sellerProductService.recordStockIn(
        productId: product.id,
        quantity: quantity,
        note: note.isEmpty ? null : note,
      );

      stockController.text = updatedProduct.stock.toString();

      ref.invalidate(sellerProductsProvider(product.storeId));
      ref.invalidate(productStockMovementsProvider(product.id));
      ref.invalidate(productsProvider);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Stock in recorded. Stock is now ${updatedProduct.stock}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = readableError(error);

      setState(() {
        errorMessage = message;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          isRecordingStockIn = false;
        });
      }
    }
  }

  Future<void> showStockAdjustmentDialog(ProductModel product) async {
    final result = await showDialog<_StockAdjustmentDialogResult>(
      context: context,
      builder: (dialogContext) {
        return _StockAdjustmentDialog(currentStock: product.stock);
      },
    );

    if (result == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    await recordStockAdjustment(
      product: product,
      newStock: result.newStock,
      reason: result.reason,
    );
  }

  Future<void> recordStockAdjustment({
    required ProductModel product,
    required int newStock,
    required String reason,
  }) async {
    setState(() {
      isAdjustingStock = true;
      errorMessage = null;
    });

    try {
      final sellerProductService = ref.read(sellerProductServiceProvider);

      final updatedProduct = await sellerProductService.recordStockAdjustment(
        productId: product.id,
        newStock: newStock,
        reason: reason,
      );

      stockController.text = updatedProduct.stock.toString();

      ref.invalidate(sellerProductsProvider(product.storeId));
      ref.invalidate(productStockMovementsProvider(product.id));
      ref.invalidate(productsProvider);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stock adjusted. Stock is now ${updatedProduct.stock}'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = readableError(error);

      setState(() {
        errorMessage = message;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          isAdjustingStock = false;
        });
      }
    }
  }

  Future<void> showStockOpnameDialog(ProductModel product) async {
    final result = await showDialog<_StockOpnameDialogResult>(
      context: context,
      builder: (dialogContext) {
        return _StockOpnameDialog(currentStock: product.stock);
      },
    );

    if (result == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    await recordStockOpname(
      product: product,
      countedStock: result.countedStock,
      note: result.note,
    );
  }

  Future<void> recordStockOpname({
    required ProductModel product,
    required int countedStock,
    required String note,
  }) async {
    setState(() {
      isRecordingStockOpname = true;
      errorMessage = null;
    });

    try {
      final sellerProductService = ref.read(sellerProductServiceProvider);
      final opnameNote = note.trim().isEmpty
          ? 'Stock opname'
          : 'Stock opname: ${note.trim()}';

      final updatedProduct = await sellerProductService.recordStockAdjustment(
        productId: product.id,
        newStock: countedStock,
        reason: opnameNote,
      );

      stockController.text = updatedProduct.stock.toString();

      ref.invalidate(sellerProductsProvider(product.storeId));
      ref.invalidate(productStockMovementsProvider(product.id));
      ref.invalidate(productsProvider);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Stock opname saved. Stock is now ${updatedProduct.stock}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = readableError(error);

      setState(() {
        errorMessage = message;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          isRecordingStockOpname = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final storeAsync = ref.watch(myStoreProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Product')),

      body: storeAsync.when(
        data: (store) {
          if (store == null) {
            return const Center(child: Text('Create a store first'));
          }

          final productsAsync = ref.watch(sellerProductsProvider(store.id));

          return productsAsync.when(
            data: (products) {
              final product = findProduct(products);

              if (product == null) {
                return const Center(child: Text('Product not found'));
              }

              initializeForm(product);

              return buildForm(product);
            },
            error: (error, stackTrace) {
              return Center(child: Text(error.toString()));
            },
            loading: () {
              return const Center(child: CircularProgressIndicator());
            },
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

  Widget buildForm(ProductModel product) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),

        child: Form(
          key: formKey,

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,

            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Product Name'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Product name required';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: priceController,
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Price required';
                  }

                  if (int.parse(value.trim()) <= 0) {
                    return 'Price must be greater than 0';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              categoriesAsync.when(
                data: (categories) {
                  return buildCategoryDropdown(categories);
                },
                error: (error, stackTrace) {
                  return Text(error.toString());
                },
                loading: () {
                  return const LinearProgressIndicator();
                },
              ),

              const SizedBox(height: 16),

              const Text(
                'Characteristics',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              TextFormField(
                controller: productTypeController,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  hintText: 'Example: food, shirt, craft',
                ),
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: sizeController,
                decoration: const InputDecoration(
                  labelText: 'Size',
                  hintText: 'Example: S, M, 250g, 1 pack',
                ),
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: colorController,
                decoration: const InputDecoration(
                  labelText: 'Color',
                  hintText: 'Example: red, black, natural',
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'Inventory',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              const Text(
                'Current stock is read-only here. Use Stock In for new goods, Adjust Stock for correction, or Stock Opname for physical count results.',
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: stockController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Current Stock',
                  helperText:
                      'This value changes through inventory actions below.',
                ),
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 12),

              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: isRecordingStockIn
                        ? null
                        : () => showStockInDialog(product),
                    icon: isRecordingStockIn
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_box_outlined),
                    label: const Text('Record Stock In'),
                  ),
                  OutlinedButton.icon(
                    onPressed: isAdjustingStock
                        ? null
                        : () => showStockAdjustmentDialog(product),
                    icon: isAdjustingStock
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.tune_outlined),
                    label: const Text('Adjust Stock'),
                  ),
                  OutlinedButton.icon(
                    onPressed: isRecordingStockOpname
                        ? null
                        : () => showStockOpnameDialog(product),
                    icon: isRecordingStockOpname
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.fact_check_outlined),
                    label: const Text('Stock Opname'),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              buildStockMovementHistory(product),

              const SizedBox(height: 16),

              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                minLines: 3,
                maxLines: 5,
              ),

              const SizedBox(height: 16),

              buildImageManager(product),

              const SizedBox(height: 16),

              Text('Current status: ${product.status}'),

              const SizedBox(height: 24),

              if (errorMessage != null) ...[
                Text(
                  errorMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              ElevatedButton(
                onPressed: isSaving ? null : () => saveProduct(product),
                child: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(),
                      )
                    : const Text('Save Changes'),
              ),

              const SizedBox(height: 12),

              OutlinedButton(
                onPressed: isUpdatingStatus
                    ? null
                    : () => toggleStatus(product),
                child: isUpdatingStatus
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(),
                      )
                    : Text(
                        product.status == 'published'
                            ? 'Move to Draft'
                            : 'Publish Product',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildStockMovementHistory(ProductModel product) {
    final movementsAsync = ref.watch(productStockMovementsProvider(product.id));

    return movementsAsync.when(
      data: (movements) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Stock Movement History',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (movements.isEmpty)
                const Text('No stock movement record yet')
              else
                ...movements.map(buildStockMovementTile),
            ],
          ),
        );
      },
      error: (error, stackTrace) {
        return Text(error.toString());
      },
      loading: () {
        return const LinearProgressIndicator();
      },
    );
  }

  Widget buildStockMovementTile(StockMovementModel movement) {
    final isStockIn = movement.movementType == 'stock_in';
    final isStockOpname =
        movement.note != null && movement.note!.startsWith('Stock opname');
    final title = isStockIn
        ? '+${movement.quantity} stock in'
        : isStockOpname
        ? 'Stock opname'
        : 'Stock adjusted';
    final icon = isStockIn
        ? Icons.add_box_outlined
        : isStockOpname
        ? Icons.fact_check_outlined
        : Icons.tune_outlined;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(
        '${movement.previousStock} -> ${movement.newStock}'
        ' • ${DateFormatter.formatDateTime(movement.createdAt.toString())}'
        '${movement.note == null ? '' : '\n${movement.note}'}',
      ),
    );
  }

  Widget buildImageManager(ProductModel product) {
    final images = [...product.images]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Product Images',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            OutlinedButton.icon(
              onPressed: isUploadingImage ? null : () => uploadImage(product),
              icon: isUploadingImage
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload),
              label: const Text('Upload'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Upload product photos, then choose one uploaded image as thumbnail.',
        ),
        const SizedBox(height: 12),
        if (images.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text('No product images yet'),
          ),
        ...images.map((image) {
          final isThumbnail = product.thumbnailUrl == image.imageUrl;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isThumbnail ? Colors.green : Colors.transparent,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    image.imageUrl,
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 180,
                        color: Colors.grey.shade200,
                        alignment: Alignment.center,
                        child: const Text('Image failed to load'),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (isThumbnail)
                      const Expanded(
                        child: Text(
                          'Thumbnail',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isUpdatingStatus
                              ? null
                              : () => setThumbnail(product, image.id),
                          child: const Text('Set Thumbnail'),
                        ),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Delete image',
                      onPressed: isUploadingImage
                          ? null
                          : () => deleteImage(product, image.id),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget buildCategoryDropdown(List<CategoryModel> categories) {
    final value =
        categories.any((category) => category.id == selectedCategoryId)
        ? selectedCategoryId
        : null;

    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: const InputDecoration(labelText: 'Category'),
      items: categories.map((category) {
        return DropdownMenuItem(value: category.id, child: Text(category.name));
      }).toList(),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Category required';
        }

        return null;
      },
      onChanged: (value) {
        setState(() {
          selectedCategoryId = value;
        });
      },
    );
  }
}

class _StockInDialogResult {
  final int quantity;
  final String note;

  const _StockInDialogResult({required this.quantity, required this.note});
}

class _StockInDialog extends StatefulWidget {
  const _StockInDialog();

  @override
  State<_StockInDialog> createState() => _StockInDialogState();
}

class _StockInDialogState extends State<_StockInDialog> {
  final formKey = GlobalKey<FormState>();
  final quantityController = TextEditingController();
  final noteController = TextEditingController();

  @override
  void dispose() {
    quantityController.dispose();
    noteController.dispose();

    super.dispose();
  }

  void submit() {
    if (!formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      _StockInDialogResult(
        quantity: int.parse(quantityController.text.trim()),
        note: noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record Stock In'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: quantityController,
              decoration: const InputDecoration(labelText: 'Incoming Quantity'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Quantity required';
                }

                if (int.parse(value.trim()) <= 0) {
                  return 'Quantity must be greater than 0';
                }

                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Note',
                hintText: 'Supplier, invoice, or restock note',
              ),
              minLines: 2,
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: submit, child: const Text('Save')),
      ],
    );
  }
}

class _StockAdjustmentDialogResult {
  final int newStock;
  final String reason;

  const _StockAdjustmentDialogResult({
    required this.newStock,
    required this.reason,
  });
}

class _StockAdjustmentDialog extends StatefulWidget {
  final int currentStock;

  const _StockAdjustmentDialog({required this.currentStock});

  @override
  State<_StockAdjustmentDialog> createState() => _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends State<_StockAdjustmentDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController stockController;
  final reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();

    stockController = TextEditingController(
      text: widget.currentStock.toString(),
    );
  }

  @override
  void dispose() {
    stockController.dispose();
    reasonController.dispose();

    super.dispose();
  }

  void submit() {
    if (!formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      _StockAdjustmentDialogResult(
        newStock: int.parse(stockController.text.trim()),
        reason: reasonController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adjust Stock'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: stockController,
              decoration: const InputDecoration(
                labelText: 'New Stock Quantity',
                helperText: 'Use this only for correction or stock opname.',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'New stock quantity required';
                }

                if (int.parse(value.trim()) == widget.currentStock) {
                  return 'New stock must be different';
                }

                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Adjustment Reason',
                hintText: 'Stock opname, damaged item, or input correction',
              ),
              minLines: 2,
              maxLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Reason required';
                }

                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: submit, child: const Text('Save')),
      ],
    );
  }
}

class _StockOpnameDialogResult {
  final int countedStock;
  final String note;

  const _StockOpnameDialogResult({
    required this.countedStock,
    required this.note,
  });
}

class _StockOpnameDialog extends StatefulWidget {
  final int currentStock;

  const _StockOpnameDialog({required this.currentStock});

  @override
  State<_StockOpnameDialog> createState() => _StockOpnameDialogState();
}

class _StockOpnameDialogState extends State<_StockOpnameDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController countedStockController;
  final noteController = TextEditingController();

  @override
  void initState() {
    super.initState();

    countedStockController = TextEditingController(
      text: widget.currentStock.toString(),
    );
  }

  @override
  void dispose() {
    countedStockController.dispose();
    noteController.dispose();

    super.dispose();
  }

  void submit() {
    if (!formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      _StockOpnameDialogResult(
        countedStock: int.parse(countedStockController.text.trim()),
        note: noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Stock Opname'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              readOnly: true,
              initialValue: widget.currentStock.toString(),
              decoration: const InputDecoration(labelText: 'System Stock'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: countedStockController,
              decoration: const InputDecoration(
                labelText: 'Physical Stock Count',
                helperText: 'Enter the counted quantity from stock opname.',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Physical stock count required';
                }

                if (int.parse(value.trim()) == widget.currentStock) {
                  return 'Counted stock must be different to create opname';
                }

                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Stock Opname Note',
                hintText: 'Shelf count, missing item, damaged item, etc.',
              ),
              minLines: 2,
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: submit, child: const Text('Save')),
      ],
    );
  }
}
