import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/features/product/models/product_review_model.dart';
import 'package:mobile/features/product/providers/product_review_providers.dart';

class ProductReviewDialog extends ConsumerStatefulWidget {
  final String productId;
  final String orderId;
  final ProductReviewModel? existingReview;

  const ProductReviewDialog({
    super.key,
    required this.productId,
    required this.orderId,
    this.existingReview,
  });

  @override
  ConsumerState<ProductReviewDialog> createState() =>
      _ProductReviewDialogState();
}

class _ProductReviewDialogState extends ConsumerState<ProductReviewDialog> {
  late int rating;
  late TextEditingController commentController;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    rating = widget.existingReview?.rating ?? 5;
    commentController = TextEditingController(
      text: widget.existingReview?.comment ?? '',
    );
  }

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  String getRatingLabel(int star) {
    switch (star) {
      case 1:
        return 'Sangat Buruk 😞';
      case 2:
        return 'Buruk 😕';
      case 3:
        return 'Cukup OK 😐';
      case 4:
        return 'Bagus 😊';
      case 5:
        return 'Sangat Bagus! 😍';
      default:
        return '';
    }
  }

  Future<void> _submit() async {
    setState(() => isSubmitting = true);
    final service = ref.read(productReviewServiceProvider);

    try {
      if (widget.existingReview != null) {
        await service.updateReview(
          reviewId: widget.existingReview!.id,
          rating: rating,
          comment: commentController.text,
        );
      } else {
        await service.createReview(
          productId: widget.productId,
          orderId: widget.orderId,
          rating: rating,
          comment: commentController.text,
        );
      }

      ref.invalidate(productReviewsProvider(widget.productId));
      ref.invalidate(
        orderProductReviewProvider((
          productId: widget.productId,
          orderId: widget.orderId,
        )),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  Future<void> _delete() async {
    if (widget.existingReview == null) return;
    setState(() => isSubmitting = true);
    final service = ref.read(productReviewServiceProvider);

    try {
      await service.deleteReview(widget.existingReview!.id);
      ref.invalidate(productReviewsProvider(widget.productId));
      ref.invalidate(
        orderProductReviewProvider((
          productId: widget.productId,
          orderId: widget.orderId,
        )),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingReview != null;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.star_rounded,
                  color: AppColors.primary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isEditing ? 'Edit Ulasan Produk' : 'Beri Penilaian Produk',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Pilih bintang dan bagikan pendapat Anda mengenai produk yang telah dibeli.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starValue = index + 1;
                  final isSelected = starValue <= rating;
                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: isSubmitting
                        ? null
                        : () => setState(() => rating = starValue),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      child: Icon(
                        isSelected
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: isSelected
                            ? Colors.amber.shade700
                            : Colors.grey.shade400,
                        size: 38,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  getRatingLabel(rating),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryHover,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: commentController,
                enabled: !isSubmitting,
                maxLines: 3,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Tuliskan ulasan produk Anda di sini (opsional)...',
                  hintStyle: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                  fillColor: AppColors.background,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  if (isEditing) ...[
                    IconButton(
                      onPressed: isSubmitting ? null : _delete,
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.error,
                      ),
                      tooltip: 'Hapus Ulasan',
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        foregroundColor: AppColors.textSecondary,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(isEditing ? 'Simpan' : 'Kirim Ulasan'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
