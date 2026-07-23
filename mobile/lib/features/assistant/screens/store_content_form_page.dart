import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/assistant/models/store_content_model.dart';
import 'package:mobile/features/assistant/providers/assistant_providers.dart';

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
  late String _contentType;
  late bool _isActive;
  bool _isLoading = false;

  final List<Map<String, String>> _contentTypeOptions = [
    {'value': 'promo', 'label': 'Promosi Diskon/Penawaran'},
    {'value': 'banner', 'label': 'Banner Spanduk/Situs'},
    {'value': 'storytelling', 'label': 'Kisah Produk/UMK'},
    {'value': 'social', 'label': 'Post Media Sosial'},
    {'value': 'educational', 'label': 'Materi Edukasi UMK'},
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
    _contentType = widget.existingContent?.contentType ?? 'promo';
    _isActive = widget.existingContent?.isActive ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final service = ref.read(assistantServiceProvider);
      if (widget.existingContent == null) {
        await service.createStoreContent(
          storeId: widget.storeId,
          title: _titleController.text.trim(),
          contentType: _contentType,
          body: _bodyController.text.trim(),
          isActive: _isActive,
        );
      } else {
        await service.updateStoreContent(
          contentId: widget.existingContent!.id,
          storeId: widget.storeId,
          title: _titleController.text.trim(),
          contentType: _contentType,
          body: _bodyController.text.trim(),
          isActive: _isActive,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingContent == null
                  ? 'Konten berhasil dibuat & dicatat ke log!'
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
              // Title field
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

              // Content Type dropdown
              DropdownButtonFormField<String>(
                initialValue: _contentType,
                decoration: const InputDecoration(
                  labelText: 'Jenis Konten *',
                  border: OutlineInputBorder(),
                ),
                items: _contentTypeOptions.map((opt) {
                  return DropdownMenuItem<String>(
                    value: opt['value']!,
                    child: Text(opt['label']!),
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

              // Body content text area
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

              // Active status switch
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

              // Submit button
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
