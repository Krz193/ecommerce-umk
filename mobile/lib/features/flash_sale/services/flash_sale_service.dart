import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/features/flash_sale/models/sale_event_model.dart';

class FlashSaleService {
  static const _eventSelect = '''
    id,
    store_id,
    title,
    slug,
    description,
    banner_url,
    start_time,
    end_time,
    is_active,
    store:stores (
      id,
      name
    ),
    sale_event_items (
      id,
      sale_event_id,
      product_id,
      store_id,
      discount_type,
      discount_value,
      sale_price,
      sale_quota,
      sold_count,
      max_qty_per_user,
      is_active,
      product:products (
        *,
        store:stores (
          id,
          name,
          address
        ),
        category:categories (
          id,
          name,
          slug
        ),
        product_images (
          id,
          product_id,
          image_url,
          sort_order
        )
      )
    )
  ''';

  Future<List<SaleEventModel>> getPublicSaleEvents() async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final response = await supabase
        .from('sale_events')
        .select(_eventSelect)
        .eq('is_active', true)
        .gte('end_time', nowIso)
        .order('start_time', ascending: true);

    return (response as List)
        .whereType<Map<String, dynamic>>()
        .map(SaleEventModel.fromJson)
        .map((event) {
          final validItems = event.items
              .where(
                (item) =>
                    item.isActive &&
                    item.product != null &&
                    item.product!.status == 'published' &&
                    !item.isQuotaExhausted &&
                    item.salePrice < item.product!.price,
              )
              .toList();
          return SaleEventModel(
            id: event.id,
            storeId: event.storeId,
            storeName: event.storeName,
            title: event.title,
            slug: event.slug,
            description: event.description,
            bannerUrl: event.bannerUrl,
            startTime: event.startTime,
            endTime: event.endTime,
            isActive: event.isActive,
            items: validItems,
          );
        })
        .where((event) => event.items.isNotEmpty)
        .toList();
  }

  Future<Map<String, ProductFlashSaleInfo>> getActiveProductFlashSales(
    List<String> productIds,
  ) async {
    final uniqueIds = productIds.where((id) => id.trim().isNotEmpty).toSet().toList();
    if (uniqueIds.isEmpty) {
      return {};
    }

    final response = await supabase.rpc(
      'get_active_product_flash_sales',
      params: {
        'p_product_ids': uniqueIds,
        'p_user_id': supabase.auth.currentUser?.id,
      },
    );

    if (response is! List) {
      return {};
    }

    final map = <String, ProductFlashSaleInfo>{};
    for (final raw in response) {
      if (raw is Map) {
        final info = ProductFlashSaleInfo.fromJson(
          Map<String, dynamic>.from(raw),
        );
        map[info.productId] = info;
      }
    }
    return map;
  }

  Future<List<SaleEventModel>> getSellerManageableEvents(String storeId) async {
    final response = await supabase
        .from('sale_events')
        .select(_eventSelect)
        .or('store_id.is.null,store_id.eq.$storeId')
        .order('created_at', ascending: false);

    return (response as List)
        .whereType<Map<String, dynamic>>()
        .map(SaleEventModel.fromJson)
        .map((event) {
          final storeItems = event.items
              .where((item) => item.storeId == storeId)
              .toList();
          return SaleEventModel(
            id: event.id,
            storeId: event.storeId,
            storeName: event.storeName,
            title: event.title,
            slug: event.slug,
            description: event.description,
            bannerUrl: event.bannerUrl,
            startTime: event.startTime,
            endTime: event.endTime,
            isActive: event.isActive,
            items: storeItems,
          );
        })
        .toList();
  }

  String _makeSlug(String title) {
    final clean = title
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final suffix = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    return '${clean.isEmpty ? 'flash-sale' : clean}-$suffix';
  }

  Future<void> createStoreSaleEvent({
    required String storeId,
    required String title,
    String? description,
    required DateTime startTime,
    required DateTime endTime,
    bool isActive = true,
  }) async {
    await supabase.from('sale_events').insert({
      'store_id': storeId,
      'created_by': supabase.auth.currentUser?.id,
      'title': title.trim(),
      'slug': _makeSlug(title),
      'description': description?.trim().isEmpty == true ? null : description?.trim(),
      'start_time': startTime.toUtc().toIso8601String(),
      'end_time': endTime.toUtc().toIso8601String(),
      'is_active': isActive,
    });
  }

  Future<void> toggleStoreSaleEvent({
    required String eventId,
    required String storeId,
    required bool isActive,
  }) async {
    await supabase
        .from('sale_events')
        .update({'is_active': isActive})
        .eq('id', eventId)
        .eq('store_id', storeId);
  }

  Future<void> deleteStoreSaleEvent({
    required String eventId,
    required String storeId,
  }) async {
    await supabase
        .from('sale_events')
        .delete()
        .eq('id', eventId)
        .eq('store_id', storeId);
  }

  Future<void> upsertSaleEventItem({
    required String saleEventId,
    required String productId,
    required String storeId,
    required String discountType,
    required double discountValue,
    int? saleQuota,
    int? maxQtyPerUser,
    bool isActive = true,
  }) async {
    await supabase.from('sale_event_items').upsert({
      'sale_event_id': saleEventId,
      'product_id': productId,
      'store_id': storeId,
      'discount_type': discountType,
      'discount_value': discountValue,
      'sale_quota': saleQuota,
      'max_qty_per_user': maxQtyPerUser,
      'is_active': isActive,
    }, onConflict: 'sale_event_id,product_id');
  }

  Future<void> deleteSaleEventItem({
    required String itemId,
    required String storeId,
  }) async {
    await supabase
        .from('sale_event_items')
        .delete()
        .eq('id', itemId)
        .eq('store_id', storeId);
  }
}
