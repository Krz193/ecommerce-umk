import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:mobile/features/product/models/category_model.dart';
import 'package:mobile/features/product/models/product_model.dart';
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

  final descriptionController = TextEditingController();

  String? selectedCategoryId;

  bool initialized = false;

  bool isSaving = false;

  bool isUpdatingStatus = false;

  bool isUploadingImage = false;

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
        stock: int.parse(stockController.text.trim()),
        categoryId: selectedCategoryId!,
        status: product.status,
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

              TextFormField(
                controller: stockController,
                decoration: const InputDecoration(labelText: 'Stock'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Stock required';
                  }

                  return null;
                },
              ),

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
