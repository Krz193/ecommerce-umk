import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/assistant/models/assistance_log_model.dart';
import 'package:mobile/features/assistant/models/store_content_model.dart';
import 'package:mobile/features/donation/services/buyer_donation_service.dart';
import 'package:mobile/features/product/models/product_model.dart';

void main() {
  group('Phase 1 & Phase 2 Comprehensive Unit Tests', () {
    // -------------------------------------------------------------------------
    // #3 UMK & Asisten: Formula Model Rekomendasi Produk
    // -------------------------------------------------------------------------
    test('Formula score prioritizes high sales, rating, and carts accurately', () {
      // Rumus weighted formula:
      // Score = (wSold*normSold + wRating*normRating + wCart*normCart + wDiscount*normDiscount + wStock*normStock) / totalW * 100
      double computeScore(
        Map<String, dynamic> item, {
        required int maxSold,
        required int maxCart,
        required int maxStock,
        double wSold = 0.35,
        double wRating = 0.25,
        double wCart = 0.20,
        double wDiscount = 0.10,
        double wStock = 0.10,
      }) {
        final sold = (item['sold_qty'] as num?)?.toDouble() ?? 0;
        final rating = (item['avg_rating'] as num?)?.toDouble() ?? 0;
        final cart = (item['cart_qty'] as num?)?.toDouble() ?? 0;
        final stock = (item['stock'] as num?)?.toDouble() ?? 0;
        final price = (item['price'] as num?)?.toDouble() ?? 0;
        final originalPrice = (item['original_price'] as num?)?.toDouble() ?? price;
        final discountPct = (item['discount_percent'] as num?)?.toDouble() ?? 0;

        final effectiveDiscountPct = discountPct > 0
            ? discountPct
            : (originalPrice > price && originalPrice > 0
                ? ((originalPrice - price) / originalPrice) * 100
                : 0.0);

        final normSold = maxSold > 0 ? (sold / maxSold).clamp(0.0, 1.0) : 0.0;
        final normRating = (rating / 5.0).clamp(0.0, 1.0);
        final normCart = maxCart > 0 ? (cart / maxCart).clamp(0.0, 1.0) : 0.0;
        final normDiscount = (effectiveDiscountPct / 50.0).clamp(0.0, 1.0);
        final normStock = maxStock > 0 ? (stock / maxStock).clamp(0.0, 1.0) : 0.0;

        final totalWeight = wSold + wRating + wCart + wDiscount + wStock;
        if (totalWeight <= 0) return 0;

        final weighted = (wSold * normSold) +
            (wRating * normRating) +
            (wCart * normCart) +
            (wDiscount * normDiscount) +
            (wStock * normStock);

        return double.parse(((weighted / totalWeight) * 100).toStringAsFixed(1));
      }

      final topProduct = {
        'sold_qty': 100,
        'avg_rating': 5.0,
        'cart_qty': 50,
        'stock': 20,
        'price': 40000,
        'original_price': 50000,
        'discount_percent': 20.0,
      };

      final lowPerformer = {
        'sold_qty': 2,
        'avg_rating': 3.0,
        'cart_qty': 1,
        'stock': 100,
        'price': 50000,
        'original_price': 50000,
        'discount_percent': 0.0,
      };

      final scoreTop = computeScore(topProduct, maxSold: 100, maxCart: 50, maxStock: 100);
      final scoreLow = computeScore(lowPerformer, maxSold: 100, maxCart: 50, maxStock: 100);

      expect(scoreTop, greaterThan(85.0));
      expect(scoreLow, lessThan(35.0));
      expect(scoreTop, greaterThan(scoreLow));
    });

    // -------------------------------------------------------------------------
    // #7 Pembeli: Multi-Token Search Diperluas
    // -------------------------------------------------------------------------
    test('ProductModel.matchesSearchQuery handles multi-token and broadened attributes', () {
      final product = ProductModel(
        id: 'prod-1',
        name: 'Kopi Arabika Kintamani Single Origin',
        price: 75000,
        originalPrice: 90000,
        discountPercent: 16.6,
        stock: 15,
        status: 'active',
        description: 'Biji kopi sangrai aroma citrus dari perkebunan organik',
        storeId: 'store-10',
        storeName: 'Kopi Dewata Sejahtera',
        storeCity: 'Kintamani, Bangli, Bali',
        categoryName: 'Minuman Khas',
        productType: 'Biji Kopi',
        color: 'Dark Roast',
        size: '250 gram',
      );

      // 1. Single token name match
      expect(product.matchesSearchQuery('kintamani'), isTrue);

      // 2. City / Address match
      expect(product.matchesSearchQuery('bangli'), isTrue);

      // 3. Store name match
      expect(product.matchesSearchQuery('dewata'), isTrue);

      // 4. Promo / Diskon keyword match
      expect(product.matchesSearchQuery('promo'), isTrue);
      expect(product.matchesSearchQuery('diskon'), isTrue);

      // 5. Multi-token combination (product + city + promo)
      expect(product.matchesSearchQuery('kopi bangli diskon'), isTrue);

      // 6. Non-matching query
      expect(product.matchesSearchQuery('sepatu running'), isFalse);
    });

    // -------------------------------------------------------------------------
    // #16 Asisten UMK: CRUD Engagement Model
    // -------------------------------------------------------------------------
    test('AssistanceLogModel parses engagement metrics and calculates total interactions', () {
      final map = {
        'id': 'log-001',
        'assistant_id': 'asst-10',
        'store_id': 'store-20',
        'action_type': 'engagement',
        'title': 'Kampanye Reels Instagram Gebyar UMKM',
        'description': 'Posting video profil pembuatan kerajinan bambu',
        'channel': 'instagram',
        'reach_count': 12500,
        'likes_count': 840,
        'comments_count': 120,
        'shares_count': 45,
        'inquiries_count': 18,
        'metadata': {'campaign_id': 'cmp-99'},
        'created_at': '2026-10-23T10:00:00Z',
      };

      final log = AssistanceLogModel.fromMap(map);

      expect(log.id, 'log-001');
      expect(log.reachCount, 12500);
      expect(log.likesCount, 840);
      expect(log.commentsCount, 120);
      expect(log.sharesCount, 45);
      expect(log.inquiriesCount, 18);
      // Total Interactions = 840 + 120 + 45 + 18 = 1023
      expect(log.totalInteractions, 1023);
      expect(log.hasEngagementMetrics, isTrue);
      expect(log.channel, 'instagram');
    });

    // -------------------------------------------------------------------------
    // #17 Informasi Konten: Media Format, Social Platform, & External Link
    // -------------------------------------------------------------------------
    test('StoreContentModel correctly parses media format, platform, and links', () {
      final map = {
        'id': 'cnt-100',
        'store_id': 'store-55',
        'created_by': 'asst-1',
        'title': 'Tutorial Menggunakan Tenun Ikat',
        'content_type': 'story',
        'social_platform': 'tiktok',
        'media_format': 'video',
        'external_url': 'https://www.tiktok.com/@tenun_ikat/video/123456',
        'body': 'Kisah pengrajin tenun tradisional',
        'media_urls': ['https://storage.umk.com/videos/tenun.mp4'],
        'is_active': true,
        'created_at': '2026-10-23T12:00:00Z',
        'updated_at': '2026-10-23T12:00:00Z',
      };

      final content = StoreContentModel.fromMap(map);

      expect(content.id, 'cnt-100');
      expect(content.socialPlatform, 'tiktok');
      expect(content.mediaFormat, 'video');
      expect(content.externalUrl, contains('tiktok.com'));
      expect(content.mediaUrls.length, 1);
      expect(content.mediaFormatLabel, 'Video');
      expect(content.socialPlatformLabel, 'TikTok');
    });

    // -------------------------------------------------------------------------
    // #12 Pembeli: CRUD Donasi dari Konten UMK Model
    // -------------------------------------------------------------------------
    test('BuyerDonationRecord parses content relation and validates modification restriction', () {
      final editableDonation = BuyerDonationRecord.fromMap({
        'id': 'don-1',
        'store_id': 'store-1',
        'content_id': 'cnt-100',
        'amount': 25000,
        'donor_name': 'Ahmad Fauzi',
        'status': 'paid',
        'created_at': '2026-10-24T08:00:00Z',
        'stores': {'name': 'Toko Kerajinan Tenun'},
        'store_contents': {'title': 'Tutorial Menggunakan Tenun Ikat'},
      });

      expect(editableDonation.storeName, 'Toko Kerajinan Tenun');
      expect(editableDonation.contentTitle, 'Tutorial Menggunakan Tenun Ikat');
      expect(editableDonation.amount, 25000);
      expect(editableDonation.canModify, isTrue); // belum disalurkan, can edit/delete

      final distributedDonation = BuyerDonationRecord.fromMap({
        'id': 'don-2',
        'store_id': 'store-1',
        'amount': 50000,
        'donor_name': 'Ahmad Fauzi',
        'status': 'distributed', // sudah disalurkan oleh admin
        'created_at': '2026-10-20T08:00:00Z',
      });

      expect(distributedDonation.canModify, isFalse); // immutable
    });
  });
}
