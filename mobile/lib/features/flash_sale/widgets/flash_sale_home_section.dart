import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/features/flash_sale/models/sale_event_model.dart';
import 'package:mobile/features/flash_sale/providers/flash_sale_provider.dart';

String formatCountdownDuration(Duration d) {
  final totalSeconds = d.inSeconds.clamp(0, 86400 * 99);
  final days = totalSeconds ~/ 86400;
  final hours = (totalSeconds % 86400) ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  final hms =
      '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  return days > 0 ? '${days}h $hms' : hms;
}

class FlashSaleHomeSection extends ConsumerStatefulWidget {
  const FlashSaleHomeSection({super.key});

  @override
  ConsumerState<FlashSaleHomeSection> createState() =>
      _FlashSaleHomeSectionState();
}

class _FlashSaleHomeSectionState extends ConsumerState<FlashSaleHomeSection> {
  Timer? _ticker;
  bool _showUpcoming = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(publicSaleEventsProvider);

    return eventsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (events) {
        final ongoingEvents = events.where((e) => e.isOngoing).toList();
        final upcomingEvents = events.where((e) => e.isUpcoming).toList();

        if (ongoingEvents.isEmpty && upcomingEvents.isEmpty) {
          return const SizedBox.shrink();
        }

        final showUpcomingTab =
            _showUpcoming && upcomingEvents.isNotEmpty || ongoingEvents.isEmpty;
        final visibleEvents = showUpcomingTab ? upcomingEvents : ongoingEvents;
        final primaryEvent = visibleEvents.first;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: showUpcomingTab
                      ? [const Color(0xFFFFF8F5), const Color(0xFFFFEDE0)]
                      : [const Color(0xFFFFF1E6), const Color(0xFFFFE2CC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.orange.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.bolt_rounded,
                        color: showUpcomingTab
                            ? AppColors.primary
                            : AppColors.primaryHover,
                        size: 22,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Flash Sale',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: showUpcomingTab
                              ? Colors.indigo.shade700
                              : const Color(0xFFDC2626),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${showUpcomingTab ? 'Mulai dalam' : 'Berakhir'} ${formatCountdownDuration(primaryEvent.countdownRemaining)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (ongoingEvents.isNotEmpty)
                        _buildTabChip(
                          label: 'Sedang Berlangsung (${ongoingEvents.length})',
                          selected: !showUpcomingTab,
                          onTap: () => setState(() => _showUpcoming = false),
                        ),
                      if (ongoingEvents.isNotEmpty && upcomingEvents.isNotEmpty)
                        const SizedBox(width: 8),
                      if (upcomingEvents.isNotEmpty)
                        _buildTabChip(
                          label: 'Akan Datang (${upcomingEvents.length})',
                          selected: showUpcomingTab,
                          onTap: () => setState(() => _showUpcoming = true),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...visibleEvents.map(
                    (event) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  event.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                showUpcomingTab
                                    ? 'Mulai ${DateFormatter.format(event.startTime)}'
                                    : (event.storeName ?? 'Promo Platform'),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 222,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: event.items.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (context, index) {
                                final item = event.items[index];
                                return _FlashSaleProductCard(
                                  item: item,
                                  isUpcoming: showUpcomingTab,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _buildTabChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.textPrimary : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _FlashSaleProductCard extends StatelessWidget {
  final SaleEventItemModel item;
  final bool isUpcoming;

  const _FlashSaleProductCard({
    required this.item,
    required this.isUpcoming,
  });

  @override
  Widget build(BuildContext context) {
    final product = item.product;
    if (product == null) return const SizedBox.shrink();

    final discountPct = item.effectiveDiscountPercent(product.price);
    final quotaText = item.saleQuota != null
        ? 'Terjual ${item.soldCount}/${item.saleQuota}'
        : 'Promo Terbatas';

    return GestureDetector(
      onTap: () => context.push('/products/${product.id}'),
      child: Container(
        width: 148,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: product.thumbnailUrl != null
                      ? Image.network(
                          product.thumbnailUrl!,
                          height: 102,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            height: 102,
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: const Icon(Icons.image_not_supported_outlined),
                          ),
                        )
                      : Container(
                          height: 102,
                          color: Colors.grey.shade200,
                          alignment: Alignment.center,
                          child: const Icon(Icons.shopping_bag_outlined),
                        ),
                ),
                if (discountPct > 0)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '-$discountPct%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      CurrencyFormatter.format(product.price),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    Text(
                      isUpcoming
                          ? 'Segera: ${CurrencyFormatter.format(item.salePrice)}'
                          : CurrencyFormatter.format(item.salePrice),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isUpcoming
                            ? Colors.indigo.shade700
                            : AppColors.primaryHover,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (item.saleQuota != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: item.soldRatio,
                          minHeight: 5,
                          backgroundColor: Colors.orange.shade100,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      quotaText,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
