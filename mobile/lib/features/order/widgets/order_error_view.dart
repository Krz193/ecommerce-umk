import 'package:flutter/material.dart';
import 'package:mobile/core/utils/error_formatter.dart';

/// User-friendly fallback view shown on order detail pages when an order
/// is missing, no longer accessible, or fails to load.
class OrderErrorView extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const OrderErrorView({
    super.key,
    required this.error,
    required this.onRetry,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final notFound = isNotFoundError(error);
    final friendlyMessage = formatUserFriendlyError(
      error,
      defaultMessage: 'Gagal memuat detail pesanan. Silakan coba lagi.',
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: (notFound ? Colors.orange : Colors.red).shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  notFound
                      ? Icons.receipt_long_outlined
                      : Icons.error_outline_rounded,
                  size: 36,
                  color: (notFound ? Colors.orange : Colors.red).shade700,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                notFound
                    ? 'Pesanan Tidak Ditemukan'
                    : 'Gagal Memuat Pesanan',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                friendlyMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Kembali'),
                  ),
                  ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Coba Lagi'),
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
