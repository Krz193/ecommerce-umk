import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/core/utils/error_formatter.dart';
import 'package:mobile/features/assistant/models/store_content_model.dart';
import 'package:mobile/features/assistant/providers/assistant_providers.dart';
import 'package:mobile/features/donation/services/buyer_donation_service.dart';
import 'package:mobile/features/store/providers/store_provider.dart';

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
  late TextEditingController _reachController;
  late TextEditingController _likesController;
  late TextEditingController _commentsController;
  late TextEditingController _sharesController;
  late TextEditingController _inquiriesController;
  late String _contentType;
  late String _mediaFormat;
  late String _socialPlatform;
  String? _productId;
  bool _isLoading = false;

  static const List<Map<String, String>> _contentTypeOptions = [
    {'value': 'promo', 'label': 'Promosi Diskon/Penawaran'},
    {'value': 'banner', 'label': 'Banner Spanduk/Situs'},
    {'value': 'storytelling', 'label': 'Kisah Produk/UMK'},
    {'value': 'social', 'label': 'Post Media Sosial'},
    {'value': 'educational', 'label': 'Materi Edukasi UMK'},
  ];

  static const List<Map<String, String>> _mediaFormatOptions = [
    {'value': 'image', 'label': 'Gambar / Foto'},
    {'value': 'video', 'label': 'Video'},
    {'value': 'short_video', 'label': 'Reels / TikTok / Shorts'},
    {'value': 'carousel', 'label': 'Carousel Slide'},
    {'value': 'article', 'label': 'Artikel / Teks'},
  ];

  static const List<Map<String, String>> _socialPlatformOptions = [
    {'value': 'instagram', 'label': 'Instagram'},
    {'value': 'tiktok', 'label': 'TikTok'},
    {'value': 'youtube', 'label': 'YouTube'},
    {'value': 'facebook', 'label': 'Facebook'},
    {'value': 'whatsapp', 'label': 'WhatsApp'},
    {'value': 'marketplace', 'label': 'Marketplace'},
  ];

  String _resolveOption(
    String? candidate,
    List<Map<String, String>> options,
    String fallback,
  ) {
    if (candidate != null && options.any((o) => o['value'] == candidate)) {
      return candidate;
    }
    return fallback;
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existingContent;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _bodyController = TextEditingController(text: existing?.body ?? '');
    _externalUrlController = TextEditingController(
      text: existing?.externalUrl ?? '',
    );
    _reachController = TextEditingController(
      text: (existing?.reachCount ?? 0).toString(),
    );
    _likesController = TextEditingController(
      text: (existing?.likesCount ?? 0).toString(),
    );
    _commentsController = TextEditingController(
      text: (existing?.commentsCount ?? 0).toString(),
    );
    _sharesController = TextEditingController(
      text: (existing?.sharesCount ?? 0).toString(),
    );
    _inquiriesController = TextEditingController(
      text: (existing?.inquiriesCount ?? 0).toString(),
    );

    _contentType = _resolveOption(
      existing?.contentType,
      _contentTypeOptions,
      'promo',
    );
    _mediaFormat = _resolveOption(
      existing?.mediaFormat,
      _mediaFormatOptions,
      'image',
    );
    _socialPlatform = _resolveOption(
      existing?.socialPlatform,
      _socialPlatformOptions,
      'instagram',
    );
    _productId = existing?.productId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _externalUrlController.dispose();
    _reachController.dispose();
    _likesController.dispose();
    _commentsController.dispose();
    _sharesController.dispose();
    _inquiriesController.dispose();
    super.dispose();
  }

  int _parseMetric(TextEditingController controller) {
    final parsed = int.tryParse(controller.text.trim()) ?? 0;
    return parsed < 0 ? 0 : parsed;
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final service = ref.read(assistantServiceProvider);
      final externalUrl = _externalUrlController.text.trim();
      final bodyText = _bodyController.text.trim();
      final reachCount = _parseMetric(_reachController);
      final likesCount = _parseMetric(_likesController);
      final commentsCount = _parseMetric(_commentsController);
      final sharesCount = _parseMetric(_sharesController);
      final inquiriesCount = _parseMetric(_inquiriesController);

      if (widget.existingContent == null) {
        await service.createStoreContent(
          storeId: widget.storeId,
          title: _titleController.text.trim(),
          contentType: _contentType,
          socialPlatform: _socialPlatform,
          mediaFormat: _mediaFormat,
          externalUrl: externalUrl,
          body: bodyText.isEmpty ? null : bodyText,
          productId: _productId,
          reachCount: reachCount,
          likesCount: likesCount,
          commentsCount: commentsCount,
          sharesCount: sharesCount,
          inquiriesCount: inquiriesCount,
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
          body: bodyText.isEmpty ? null : bodyText,
          productId: _productId,
          reachCount: reachCount,
          likesCount: likesCount,
          commentsCount: commentsCount,
          sharesCount: sharesCount,
          inquiriesCount: inquiriesCount,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingContent == null
                  ? 'Konten & engagement berhasil dicatat!'
                  : 'Konten & engagement berhasil diperbarui!',
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan konten: ${formatUserFriendlyError(e)}'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildMetricField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (val) {
        final text = val?.trim() ?? '';
        if (text.isEmpty) return null;
        final number = int.tryParse(text);
        if (number == null || number < 0) {
          return 'Angka tidak valid';
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingContent != null;
    final productsAsync = ref.watch(
      publicStoreProductsProvider(widget.storeId),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Konten & Engagement' : 'Catat Konten & Engagement',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.link_rounded,
                      color: Colors.blue.shade800,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Catat platform eksternal tempat konten UMK diupload, link bukti tayang, dan angka engagement untuk dipantau Pemilik UMK.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Judul Konten *',
                  hintText: 'Contoh: Reels Promo Kemerdekaan Toko Kerajinan',
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
                initialValue: _socialPlatform,
                decoration: const InputDecoration(
                  labelText: 'Platform Eksternal *',
                  border: OutlineInputBorder(),
                ),
                items: _socialPlatformOptions.map((opt) {
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
                      _socialPlatform = val;
                    });
                  }
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _externalUrlController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Link Bukti Konten Eksternal *',
                  hintText:
                      'https://www.instagram.com/reel/... atau https://vt.tiktok.com/...',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  final trimmed = val?.trim() ?? '';
                  if (trimmed.isEmpty) {
                    return 'Link bukti konten wajib diisi';
                  }
                  final uri = Uri.tryParse(trimmed);
                  if (uri == null ||
                      (uri.scheme != 'http' && uri.scheme != 'https') ||
                      uri.host.isEmpty) {
                    return 'Masukkan URL valid (diawali http:// atau https://)';
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

              productsAsync.when(
                data: (products) {
                  final validProductId =
                      products.any((p) => p.id == _productId)
                          ? _productId
                          : null;
                  return DropdownButtonFormField<String?>(
                    isExpanded: true,
                    initialValue: validProductId,
                    decoration: const InputDecoration(
                      labelText: 'Produk yang Dipromosikan (Opsional)',
                      hintText: 'Pilih produk yang ditautkan pada konten ini',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          'Tanpa Produk Spesifik (Konten Non-Produk / Branding UMK)',
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
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Caption / Catatan Konten (Opsional)',
                  hintText:
                      'Tuliskan ringkasan caption, target audiens, atau catatan evaluasi konten...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      final donationLink = buildDonationPageLink(
                        storeId: widget.storeId,
                        contentId: widget.existingContent?.id,
                      );
                      final currentText = _bodyController.text.trimRight();
                      _bodyController.text = currentText.isEmpty
                          ? 'Dukung UMK via link donasi: $donationLink'
                          : '$currentText\n\nDukung UMK via link donasi: $donationLink';
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Link halaman donasi disisipkan ke caption konten.',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_link, size: 16),
                    label: Text(
                      widget.existingContent != null
                          ? 'Sisipkan Link Donasi Konten'
                          : 'Sisipkan Link Donasi Toko',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final donationLink = buildDonationPageLink(
                        storeId: widget.storeId,
                        contentId: widget.existingContent?.id,
                      );
                      await Clipboard.setData(ClipboardData(text: donationLink));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Link halaman donasi disalin!'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_outlined, size: 15),
                    label: const Text(
                      'Salin Link Donasi',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              const Text(
                'Metrik Engagement Konten',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 4),
              const Text(
                'Isi angka performa konten dari insight platform eksternal.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildMetricField(_reachController, 'Views / Reach'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: _buildMetricField(_likesController, 'Likes')),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricField(_commentsController, 'Komentar'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricField(_sharesController, 'Shares'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildMetricField(
                _inquiriesController,
                'Leads / Chat Masuk / Konversi',
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
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
                          isEditing
                              ? 'Simpan Perubahan'
                              : 'Simpan Konten & Engagement',
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
