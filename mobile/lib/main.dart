import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mobile/core/router/app_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/address/providers/address_provider.dart';
import 'package:mobile/features/assistant/providers/assistant_providers.dart';
import 'package:mobile/features/auth/providers/auth_provider.dart';
import 'package:mobile/features/cart/providers/cart_provider.dart';
import 'package:mobile/features/donation/services/buyer_donation_service.dart';
import 'package:mobile/features/feedback/providers/feedback_provider.dart';
import 'package:mobile/features/flash_sale/providers/flash_sale_provider.dart';
import 'package:mobile/features/notification/providers/notification_provider.dart';
import 'package:mobile/features/order/providers/order_detail_provider.dart';
import 'package:mobile/features/order/providers/orders_provider.dart';
import 'package:mobile/features/order/providers/refund_request_provider.dart';
import 'package:mobile/features/order/providers/seller_order_provider.dart';
import 'package:mobile/features/product/providers/seller_product_provider.dart';
import 'package:mobile/features/store/providers/store_provider.dart';

/// Determines whether user-scoped Riverpod providers must be invalidated on an
/// [AuthState] transition. Returns `false` for `tokenRefreshed` (and same-user
/// metadata updates) so active screens are not reset mid-session.
bool shouldInvalidateOnAuthChange({
  required AuthChangeEvent event,
  required String? previousUserId,
  required String? nextUserId,
}) {
  if (event == AuthChangeEvent.tokenRefreshed) {
    return false;
  }
  if (event == AuthChangeEvent.signedOut) {
    return true;
  }
  if (event == AuthChangeEvent.initialSession) {
    return false;
  }
  return previousUserId != nextUserId;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);

  // Custom Global Fatal Error Boundary: Prevents Red/Grey Solid Screen of Death
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: Colors.red.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Terjadi Kendala Tampilan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Halaman mengalami sedikit kendala saat memuat. Silakan kembali ke beranda atau muat ulang aplikasi.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    appRouter.go('/home');
                  },
                  icon: const Icon(Icons.home_outlined, size: 18),
                  label: const Text('Kembali ke Beranda'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };

  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<AuthState>>(authStateProvider, (previous, next) {
      final authState = next.asData?.value;
      if (authState == null) return;

      final prevUserId = previous?.asData?.value.session?.user.id;
      final nextUserId = authState.session?.user.id;

      if (!shouldInvalidateOnAuthChange(
        event: authState.event,
        previousUserId: prevUserId,
        nextUserId: nextUserId,
      )) {
        return;
      }

      clearRouterRoleCache();

      // Core buyer & seller providers
      ref.invalidate(cartProvider);
      ref.invalidate(ordersProvider);
      ref.invalidate(orderDetailProvider);
      ref.invalidate(addressProvider);
      ref.invalidate(currentUserProvider);
      ref.invalidate(appUserProvider);
      ref.invalidate(myStoreProvider);
      ref.invalidate(sellerProductsProvider);
      ref.invalidate(sellerOrdersProvider);
      ref.invalidate(sellerOrderDetailProvider);
      ref.invalidate(notificationsStreamProvider);
      ref.invalidate(cartFlashSalesProvider);
      ref.invalidate(productFlashSaleProvider);
      ref.invalidate(sellerSaleEventsProvider);

      // Assistant, managed store, donation, feedback, and refund providers
      ref.invalidate(assistantProfileProvider);
      ref.invalidate(assignedStoresProvider);
      ref.invalidate(selectedStoreProvider);
      ref.invalidate(handledStoreProvider);
      ref.invalidate(managedStoreProvider);
      ref.invalidate(myDonationsProvider);
      ref.invalidate(userFeedbacksProvider);
      ref.invalidate(refundRequestsProvider);
    });

    return MaterialApp.router(
      title: 'E-commerce UMK',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: AppTheme.lightTheme,
    );
  }
}
