import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/router/app_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/auth/providers/auth_provider.dart';
import 'package:mobile/features/cart/providers/cart_provider.dart';
import 'package:mobile/features/order/providers/orders_provider.dart';
import 'package:mobile/features/order/providers/order_detail_provider.dart';
import 'package:mobile/features/order/providers/seller_order_provider.dart';
import 'package:mobile/features/address/providers/address_provider.dart';
import 'package:mobile/features/product/providers/seller_product_provider.dart';
import 'package:mobile/features/store/providers/store_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    ref.listen(authStateProvider, (context, index) {
      // Invalidate user-scoped providers on auth change to avoid stale
      // or cross-account data shown after sign-out/sign-in.
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
    });

    return MaterialApp.router(
      title: 'E-commerce UMK',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: AppTheme.lightTheme,
    );
  }
}
