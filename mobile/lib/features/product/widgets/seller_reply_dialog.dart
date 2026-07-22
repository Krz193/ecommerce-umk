import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    return AlertDialog(
      title: const Text('Balas Ulasan Pembeli'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ulasan oleh: ${widget.review.userName ?? "Pembeli"}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (widget.review.comment?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(
                '"${widget.review.comment}"',
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: replyController,
              enabled: !isSubmitting,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Tuliskan tanggapan Anda sebagai penjual...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
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
              : const Text('Kirim Balasan'),
        ),
      ],
    );
  }
}
