import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/router/app_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/auth/providers/auth_provider.dart';
import 'package:mobile/features/cart/providers/cart_provider.dart';
import 'package:mobile/features/order/providers/orders_provider.dart';
import 'package:mobile/features/address/providers/address_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
      ref.invalidate(addressProvider);
      ref.invalidate(currentUserProvider);
    });

    return MaterialApp.router(
      title: 'Marketplace UMK',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: AppTheme.lightTheme,
    );
  }
}
