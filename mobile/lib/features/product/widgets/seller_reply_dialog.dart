import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/features/product/models/product_review_model.dart';
import 'package:mobile/features/product/providers/product_review_providers.dart';

class SellerReplyDialog extends ConsumerStatefulWidget {
  final ProductReviewModel review;

  const SellerReplyDialog({super.key, required this.review});

  @override
  ConsumerState<SellerReplyDialog> createState() => _SellerReplyDialogState();
}

class _SellerReplyDialogState extends ConsumerState<SellerReplyDialog> {
  late TextEditingController replyController;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    replyController = TextEditingController(
      text: widget.review.sellerReply ?? '',
    );
  }

  @override
  void dispose() {
    replyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (replyController.text.trim().isEmpty) return;

    setState(() => isSubmitting = true);
    final service = ref.read(productReviewServiceProvider);

    try {
      await service.sellerReplyReview(
        reviewId: widget.review.id,
        sellerReply: replyController.text.trim(),
      );

      ref.invalidate(productReviewsProvider(widget.review.productId));

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
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Respon Ulasan Pembeli',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_outline, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          widget.review.userName ?? "Pembeli",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: List.generate(
                            5,
                            (i) => Icon(
                              i < widget.review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: Colors.amber.shade700,
                              size: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (widget.review.comment?.isNotEmpty == true) ...[
                      const SizedBox(height: 6),
                      Text(
                        '"${widget.review.comment}"',
                        style: const TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: replyController,
                enabled: !isSubmitting,
                maxLines: 3,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Tuliskan ucapan terima kasih atau tanggapan Anda di sini...',
                  hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  fillColor: AppColors.background,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: isSubmitting ? null : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade300),
                      foregroundColor: AppColors.textSecondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Batal'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Kirim Balasan'),
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
