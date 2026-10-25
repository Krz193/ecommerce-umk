import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/voucher/models/store_voucher_model.dart';

void main() {
  group('Store Voucher & Special Pricing Unit Tests', () {
    test('Calculates nominal discount correctly and does not exceed subtotal', () {
      final voucher = StoreVoucherModel(
        id: 'v-1',
        storeId: 'store-1',
        code: 'POTONGAN20RB',
        title: 'Potongan Langsung 20rb',
        discountType: 'nominal',
        discountValue: 20000,
        minPurchase: 50000,
      );

      // Subtotal kurang dari minPurchase -> 0
      expect(voucher.calculateDiscountForItems([], 40000), 0);

      // Subtotal 100.000 -> diskon 20.000
      expect(voucher.calculateDiscountForItems([], 100000), 20000);

      // Subtotal 15.000 (jika minPurchase 0) -> capped di subtotal
      final zeroMinVoucher = StoreVoucherModel(
        id: 'v-2',
        storeId: 'store-1',
        code: 'POTONGAN50RB',
        title: 'Potongan 50rb',
        discountType: 'nominal',
        discountValue: 50000,
        minPurchase: 0,
      );
      expect(zeroMinVoucher.calculateDiscountForItems([], 30000), 30000);
    });

    test('Calculates percentage discount correctly with optional max cap', () {
      final voucherWithCap = StoreVoucherModel(
        id: 'v-3',
        storeId: 'store-1',
        code: 'DISKON20PERSEN',
        title: 'Diskon 20% Maksimal 30rb',
        discountType: 'percentage',
        discountValue: 20,
        maxDiscount: 30000,
      );

      // 20% dari 100.000 = 20.000
      expect(voucherWithCap.calculateDiscountForItems([], 100000), 20000);

      // 20% dari 250.000 = 50.000 -> dipotong maxDiscount 30.000
      expect(voucherWithCap.calculateDiscountForItems([], 250000), 30000);
    });

    test('Calculates fixed_price (Harga Khusus Baru) correctly for acquaintance', () {
      // Kenalan seller membeli barang normal subtotal 250.000,
      // seller ingin memberi harga khusus Rp 180.000 untuk dia saja.
      final specialPriceVoucher = StoreVoucherModel(
        id: 'v-4',
        storeId: 'store-1',
        code: 'HARGA-TEMAN-BUDI',
        title: 'Harga Spesial Kenalan',
        discountType: 'fixed_price',
        discountValue: 180000, // target harga baru
        usageLimit: 1, // sekali pakai
      );

      expect(specialPriceVoucher.isSingleUse, isTrue);

      // Subtotal 250.000 -> diskon 70.000 sehingga pembeli hanya bayar 180.000
      final discount = specialPriceVoucher.calculateDiscountForItems([], 250000);
      expect(discount, 70000);
      expect(250000 - discount, 180000);

      // Jika subtotal sudah di bawah target harga khusus -> diskon 0
      expect(specialPriceVoucher.calculateDiscountForItems([], 150000), 0);
    });

    test('Calculates per-product discount correctly when buyer has multiple different items in cart', () {
      // Skenario: Buyer checkout 2 barang berbeda di keranjang:
      // Item 1: Sepatu Kulit (prod-101), Harga Rp 200.000, Qty 1 (TARGET VOUCHER KENALAN)
      // Item 2: Kaos Kaki (prod-202), Harga Rp 50.000, Qty 1 (BARANG LAIN NORMAL)
      final cartItems = [
        {'product_id': 'prod-101', 'product_name': 'Sepatu Kulit', 'price': 200000, 'quantity': 1},
        {'product_id': 'prod-202', 'product_name': 'Kaos Kaki', 'price': 50000, 'quantity': 1},
      ];
      final totalSubtotal = 250000;

      // Voucher khusus untuk prod-101 (target harga baru Rp 120.000)
      final productSpecificVoucher = StoreVoucherModel(
        id: 'v-spec-1',
        storeId: 'store-1',
        code: 'KHUSUS-SEPATU-BUDI',
        title: 'Harga Spesial Sepatu untuk Teman',
        scope: 'product',
        applicableProductIds: ['prod-101'],
        discountType: 'fixed_price',
        discountValue: 120000, // harga baru sepatu jadi 120rb
        usageLimit: 1,
      );

      expect(productSpecificVoucher.isProductSpecific, isTrue);

      // Potongan HANYA untuk Sepatu (Rp 200.000 - Rp 120.000 = Rp 80.000)
      // Kaos Kaki tetap Rp 50.000
      final discount = productSpecificVoucher.calculateDiscountForItems(cartItems, totalSubtotal);
      expect(discount, 80000);

      // Total bayar: Rp 250.000 - Rp 80.000 = Rp 170.000 (Sepatu Rp 120.000 + Kaos Kaki Rp 50.000)
      final finalSubtotal = totalSubtotal - discount;
      expect(finalSubtotal, 170000);

      // Jika keranjang HANYA berisi Kaos Kaki (tanpa Sepatu Kulit target)
      final cartWithoutTarget = [
        {'product_id': 'prod-202', 'product_name': 'Kaos Kaki', 'price': 50000, 'quantity': 1},
      ];
      expect(productSpecificVoucher.calculateDiscountForItems(cartWithoutTarget, 50000), 0);
    });

    test('Evaluates single-use quota and expiry status', () {
      final expiredVoucher = StoreVoucherModel(
        id: 'v-5',
        storeId: 'store-1',
        code: 'EXPIRED123',
        title: 'Sudah Lewat Tanggal',
        discountType: 'nominal',
        discountValue: 10000,
        endDate: DateTime.now().subtract(const Duration(days: 1)),
      );

      expect(expiredVoucher.isExpired, isTrue);
      expect(expiredVoucher.canBeUsed, isFalse);

      final usedSingleUseVoucher = StoreVoucherModel(
        id: 'v-6',
        storeId: 'store-1',
        code: 'SATUKALI',
        title: 'Voucher 1x Pakai',
        discountType: 'nominal',
        discountValue: 10000,
        usageLimit: 1,
        usedCount: 1,
      );

      expect(usedSingleUseVoucher.isSingleUse, isTrue);
      expect(usedSingleUseVoucher.isQuotaExhausted, isTrue);
      expect(usedSingleUseVoucher.canBeUsed, isFalse);
    });
  });
}
