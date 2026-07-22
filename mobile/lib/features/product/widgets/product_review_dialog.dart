import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        return 'Sangat Buruk';
      case 2:
        return 'Buruk';
      case 3:
        return 'Cukup';
      case 4:
        return 'Bagus';
      case 5:
        return 'Sangat Bagus';
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

    return AlertDialog(
      title: Text(isEditing ? 'Edit Ulasan' : 'Tulis Ulasan Produk'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Berapa nilai untuk produk ini?',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (index) {
                final starValue = index + 1;
                return IconButton(
                  onPressed: isSubmitting
                      ? null
                      : () {
                          setState(() {
                            rating = starValue;
                          });
                        },
                  icon: Icon(
                    starValue <= rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 32,
                  ),
                );
              }),
            ),
            Text(
              getRatingLabel(rating),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: commentController,
              enabled: !isSubmitting,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText:
                    'Bagikan pengalaman Anda tentang produk ini (opsional)...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (isEditing)
          TextButton(
            onPressed: isSubmitting ? null : _delete,
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        TextButton(
          onPressed: isSubmitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: isSubmitting ? null : _submit,
          child: isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEditing ? 'Simpan' : 'Kirim'),
        ),
      ],
    );
  }
}
