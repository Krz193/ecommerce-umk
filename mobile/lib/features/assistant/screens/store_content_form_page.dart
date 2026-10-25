import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/assistant/models/store_content_model.dart';
import 'package:mobile/features/assistant/providers/assistant_providers.dart';
import 'package:mobile/features/store/providers/store_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StoreContentFormPage extends ConsumerStatefulWidget {
  final String storeId;
  final StoreContentModel? existingContent;

  const StoreContentFormPage({
    super.key,
    required this.storeId,
    this.existingContent,
  });

  @override
  ConsumerState<StoreContentFormPage> createState() =>
      _StoreContentFormPageState();
}

class _StoreContentFormPageState extends ConsumerState<StoreContentFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _bodyController;
  late TextEditingController _externalUrlController;
  late String _contentType;
  late String _mediaFormat;
  String? _socialPlatform;
  late bool _isActive;
  late List<String> _mediaUrls;
  String? _productId;
  bool _isLoading = false;
  bool _isUploadingImage = false;

  final List<Map<String, String>> _contentTypeOptions = const [
    {'value': 'promo', 'label': 'Promosi Diskon/Penawaran'},
    {'value': 'banner', 'label': 'Banner Spanduk/Situs'},
    {'value': 'storytelling', 'label': 'Kisah Produk/UMK'},
    {'value': 'social', 'label': 'Post Media Sosial'},
    {'value': 'educational', 'label': 'Materi Edukasi UMK'},
  ];

  final List<Map<String, String>> _mediaFormatOptions = const [
    {'value': 'image', 'label': 'Gambar / Foto'},
    {'value': 'video', 'label': 'Video'},
    {'value': 'short_video', 'label': 'Reels / TikTok / Shorts'},
    {'value': 'carousel', 'label': 'Carousel Slide'},
    {'value': 'article', 'label': 'Artikel / Teks'},
  ];

  final List<Map<String, String?>> _socialPlatformOptions = const [
    {'value': null, 'label': 'Internal Aplikasi Saja'},
    {'value': 'instagram', 'label': 'Instagram'},
    {'value': 'tiktok', 'label': 'TikTok'},
    {'value': 'youtube', 'label': 'YouTube'},
    {'value': 'facebook', 'label': 'Facebook'},
    {'value': 'whatsapp', 'label': 'WhatsApp'},
    {'value': 'marketplace', 'label': 'Marketplace'},
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existingContent?.title ?? '',
    );
    _bodyController = TextEditingController(
      text: widget.existingContent?.body ?? '',
    );
    _externalUrlController = TextEditingController(
      text: widget.existingContent?.externalUrl ?? '',
    );
    _contentType = widget.existingContent?.contentType ?? 'promo';
    _mediaFormat = widget.existingContent?.mediaFormat ?? 'image';
    _socialPlatform = widget.existingContent?.socialPlatform;
    _isActive = widget.existingContent?.isActive ?? true;
    _mediaUrls = List<String>.from(widget.existingContent?.mediaUrls ?? []);
    _productId = widget.existingContent?.productId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _externalUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    setState(() {
      _isUploadingImage = true;
    });

    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1600,
      );

      if (image == null) {
        setState(() {
          _isUploadingImage = false;
        });
        return;
      }

      final bytes = await image.readAsBytes();
      final ext = image.name.split('.').last.toLowerCase();
      final cleanExt = (ext == 'png' || ext == 'webp') ? ext : 'jpeg';
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${image.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')}';
      final storagePath = 'contents/${widget.storeId}/$fileName';

      await supabase.storage
          .from('store-contents')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$cleanExt'),
          );

      final publicUrl = supabase.storage
          .from('store-contents')
          .getPublicUrl(storagePath);

      setState(() {
        _mediaUrls.add(publicUrl);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto konten berhasil diunggah!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memilih/mengunggah foto: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _mediaUrls.removeAt(index);
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final service = ref.read(assistantServiceProvider);
      final externalUrl = _externalUrlController.text.trim().isEmpty
          ? null
          : _externalUrlController.text.trim();

      if (widget.existingContent == null) {
        await service.createStoreContent(
          storeId: widget.storeId,
          title: _titleController.text.trim(),
          contentType: _contentType,
          socialPlatform: _socialPlatform,
          mediaFormat: _mediaFormat,
          externalUrl: externalUrl,
          body: _bodyController.text.trim(),
          mediaUrls: _mediaUrls,
          productId: _productId,
          isActive: _isActive,
        );
      } else {
        await service.updateStoreContent(
          contentId: widget.existingContent!.id,
          storeId: widget.storeId,
          title: _titleController.text.trim(),
          contentType: _contentType,
          socialPlatform: _socialPlatform,
          mediaFormat: _mediaFormat,
          externalUrl: externalUrl,
          body: _bodyController.text.trim(),
          mediaUrls: _mediaUrls,
          productId: _productId,
          isActive: _isActive,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingContent == null
                  ? 'Konten berhasil dibuat dan dipublikasikan!'
                  : 'Konten berhasil diperbarui!',
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal menyimpan konten: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingContent != null;
    final productsAsync = ref.watch(
      publicStoreProductsProvider(widget.storeId),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Konten UMK' : 'Buat Konten UMK Baru'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Judul Konten *',
                  hintText: 'Contoh: Diskon Kemerdekaan Toko Kerajinan',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Judul konten wajib diisi';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _contentType,
                decoration: const InputDecoration(
                  labelText: 'Jenis Konten *',
                  border: OutlineInputBorder(),
                ),
                items: _contentTypeOptions.map((opt) {
                  return DropdownMenuItem<String>(
                    value: opt['value']!,
                    child: Text(
                      opt['label']!,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _contentType = val;
                    });
                  }
                },
              ),

              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _mediaFormat,
                decoration: const InputDecoration(
                  labelText: 'Bentuk Konten (Format Media) *',
                  border: OutlineInputBorder(),
                ),
                items: _mediaFormatOptions.map((opt) {
                  return DropdownMenuItem<String>(
                    value: opt['value']!,
                    child: Text(
                      opt['label']!,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _mediaFormat = val;
                    });
                  }
                },
              ),

              const SizedBox(height: 16),

              DropdownButtonFormField<String?>(
                isExpanded: true,
                initialValue: _socialPlatform,
                decoration: const InputDecoration(
                  labelText: 'Platform Media Sosial',
                  border: OutlineInputBorder(),
                ),
                items: _socialPlatformOptions.map((opt) {
                  return DropdownMenuItem<String?>(
                    value: opt['value'],
                    child: Text(
                      opt['label']!,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _socialPlatform = val;
                  });
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _externalUrlController,
                decoration: const InputDecoration(
                  labelText: 'URL Konten Eksternal (Instagram/TikTok/YouTube)',
                  hintText:
                      'https://instagram.com/p/... atau https://vt.tiktok.com/...',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              productsAsync.when(
                data: (products) {
                  return DropdownButtonFormField<String?>(
                    isExpanded: true,
                    initialValue: _productId,
                    decoration: const InputDecoration(
                      labelText: 'Produk yang Dipromosikan (Opsional)',
                      hintText:
                          'Pilih produk yang ingin ditautkan langsung ke pembeli',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          'Tanpa Produk Spesifik (Konten Non-Produk / Kisah UMK)',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      ...products.map((p) {
                        return DropdownMenuItem<String?>(
                          value: p.id,
                          child: Text(
                            '${p.name} (${CurrencyFormatter.format(p.price)})',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _productId = val;
                      });
                    },
                  );
                },
                error: (err, stack) => const SizedBox.shrink(),
                loading: () => const LinearProgressIndicator(),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _bodyController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Isi Narasi / Pesan Konten',
                  hintText:
                      'Tuliskan deskripsi promosi, narasi kisah produk, atau petunjuk penggunaan...',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'Foto / Thumbnail Media Promosi',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 6),
              const Text(
                'Unggah gambar spanduk, thumbnail video/reels, atau foto produk promo (format JPG, PNG, atau WEBP).',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),

              if (_mediaUrls.isNotEmpty)
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _mediaUrls.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final url = _mediaUrls[index];
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              url,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    width: 100,
                                    height: 100,
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.broken_image),
                                  ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _removeImage(index),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

              const SizedBox(height: 10),

              OutlinedButton.icon(
                onPressed: _isUploadingImage ? null : _pickAndUploadImage,
                icon: _isUploadingImage
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_a_photo_outlined),
                label: Text(
                  _isUploadingImage
                      ? 'Mengunggah Foto...'
                      : 'Tambah Foto / Thumbnail',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary),
                ),
              ),

              const SizedBox(height: 16),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Status Aktif / Publikasi'),
                subtitle: const Text(
                  'Konten aktif dapat dilihat oleh pembeli dan pengunjung toko.',
                ),
                value: _isActive,
                onChanged: (val) {
                  setState(() {
                    _isActive = val;
                  });
                },
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: (_isLoading || _isUploadingImage)
                      ? null
                      : _submitForm,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isEditing ? 'Simpan Perubahan' : 'Terbitkan Konten',
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
