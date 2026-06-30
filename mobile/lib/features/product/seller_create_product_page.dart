import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/features/product/models/category_model.dart';
import 'package:mobile/features/product/providers/category_provider.dart';
import 'package:mobile/features/product/providers/seller_product_provider.dart';
import 'package:mobile/features/store/providers/store_provider.dart';

class SellerCreateProductPage extends ConsumerStatefulWidget {
  const SellerCreateProductPage({super.key});

  @override
  ConsumerState<SellerCreateProductPage> createState() =>
      _SellerCreateProductPageState();
}

class _SellerCreateProductPageState
    extends ConsumerState<SellerCreateProductPage> {
  final formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();

  final priceController = TextEditingController();

  final stockController = TextEditingController();

  final descriptionController = TextEditingController();

  String? selectedCategoryId;

  bool isLoading = false;

  String? errorMessage;

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

  Future<void> submit() async {
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
      isLoading = true;
      errorMessage = null;
    });

    try {
      final store = await ref.read(myStoreProvider.future);

      if (store == null) {
        throw Exception('Create a store before adding products');
      }

      final slug = makeSlug(nameController.text);

      if (slug.isEmpty) {
        throw Exception('Product name must contain letters or numbers');
      }

      final sellerProductService = ref.read(sellerProductServiceProvider);

      final product = await sellerProductService.createProduct(
        storeId: store.id,
        name: nameController.text.trim(),
        slug: slug,
        price: int.parse(priceController.text.trim()),
        stock: int.parse(stockController.text.trim()),
        categoryId: selectedCategoryId!,
        description: descriptionController.text.trim().isEmpty
            ? null
            : descriptionController.text.trim(),
      );

      ref.invalidate(sellerProductsProvider(store.id));

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product draft created. Add images before publishing.'),
        ),
      );

      context.go('/seller/products/${product.id}/edit');
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = error.toString().replaceFirst('Exception: ', '');

      setState(() {
        errorMessage = message;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Create Product')),

      body: SafeArea(
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

                TextFormField(
                  controller: stockController,
                  decoration: const InputDecoration(labelText: 'Stock'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Stock required';
                    }

                    if (int.parse(value.trim()) < 0) {
                      return 'Stock cannot be negative';
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
                  onPressed: isLoading ? null : submit,
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(),
                        )
                      : const Text('Create Product'),
                ),
              ],
            ),
          ),
        ),
      ),
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
