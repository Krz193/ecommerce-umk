import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/core/utils/error_formatter.dart';

import 'package:mobile/features/order/models/order_detail_model.dart';

final orderDetailProvider = FutureProvider.autoDispose
    .family<OrderDetailModel, String>((ref, orderId) async {
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('User not logged in');
      }

      final response = await supabase
          .from('orders')
          .select('''
          *,
          store:stores (
            id,
            name,
            slug,
            phone,
            address,
            province,
            city,
            district,
            postal_code,
            notes,
            latitude,
            longitude,
            biteship_area_id
          ),
          payment:payments (
            id,
            status,
            expired_at,
            provider_transaction_id,
            raw_response
          ),
          order_items (
            id,
            product_id,
            product_name,
            product_price,
            quantity,
            subtotal,
            product_thumbnail
          )
          ''')
          .eq('id', orderId)
          .maybeSingle();

      if (response == null) {
        throw const ResourceNotFoundException(
          'Pesanan tidak ditemukan atau sudah tidak tersedia.',
        );
      }

      return OrderDetailModel.fromJson(response);
    });
