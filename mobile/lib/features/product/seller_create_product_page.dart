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

  final productTypeController = TextEditingController();

  final sizeController = TextEditingController();

  final colorController = TextEditingController();

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
    productTypeController.dispose();
    sizeController.dispose();
    colorController.dispose();
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
        errorMessage = 'Kategori produk wajib dipilih';
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
        throw Exception('Buka toko terlebih dahulu sebelum menambahkan produk');
      }

      final slug = makeSlug(nameController.text);

      if (slug.isEmpty) {
        throw Exception('Nama produk harus berisi huruf atau angka yang valid');
      }

      final sellerProductService = ref.read(sellerProductServiceProvider);

      final product = await sellerProductService.createProduct(
        storeId: store.id,
        name: nameController.text.trim(),
        slug: slug,
        price: int.parse(priceController.text.trim()),
        stock: int.parse(stockController.text.trim()),
        categoryId: selectedCategoryId!,
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

      ref.invalidate(sellerProductsProvider(store.id));

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draf produk berhasil dibuat. Silakan tambahkan foto sebelum menayangkan produk.'),
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
      appBar: AppBar(title: const Text('Tambah Produk Baru')),

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
                  decoration: const InputDecoration(
                    labelText: 'Nama Produk',
                    hintText: 'Contoh: Kripik Singkong Balado 250gr',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nama produk wajib diisi';
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
                  decoration: const InputDecoration(
                    labelText: 'Harga Jual (Rp)',
                    hintText: 'Contoh: 25000',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Harga wajib diisi';
                    }

                    if (int.parse(value.trim()) <= 0) {
                      return 'Harga harus lebih dari Rp 0';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: stockController,
                  decoration: const InputDecoration(
                    labelText: 'Jumlah Stok Awal',
                    hintText: 'Contoh: 50',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Stok awal wajib diisi';
                    }

                    if (int.parse(value.trim()) < 0) {
                      return 'Stok tidak boleh minus';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 20),

                const Text(
                  'Varian & Karakteristik Produk',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 4),

                Text(
                  'Isi varian untuk memudahkan pembeli memilih (opsional)',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),

                const SizedBox(height: 12),

                TextFormField(
                  controller: productTypeController,
                  decoration: const InputDecoration(
                    labelText: 'Jenis / Tipe',
                    hintText: 'Contoh: Makanan, Pakaian, Kerajinan',
                  ),
                ),

                const SizedBox(height: 12),

                TextFormField(
                  controller: sizeController,
                  decoration: const InputDecoration(
                    labelText: 'Ukuran / Takaran',
                    hintText: 'Contoh: S, M, L, 250gr, 1 Liter',
                  ),
                ),

                const SizedBox(height: 12),

                TextFormField(
                  controller: colorController,
                  decoration: const InputDecoration(
                    labelText: 'Warna / Rasa',
                    hintText: 'Contoh: Merah, Cokelat, Original',
                  ),
                ),

                const SizedBox(height: 20),

                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Deskripsi Produk',
                    hintText: 'Jelaskan keunggulan produk, bahan baku, dan cara pakai...',
                  ),
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
                      : const Text('Simpan Draf & Lanjut ke Foto'),
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
      decoration: const InputDecoration(labelText: 'Pilih Kategori Produk'),
      items: categories.map((category) {
        return DropdownMenuItem(value: category.id, child: Text(category.name));
      }).toList(),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Kategori produk wajib dipilih';
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
