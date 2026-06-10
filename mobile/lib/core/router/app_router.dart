import 'package:go_router/go_router.dart';
import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/core/router/router_refresh_stream.dart';
import 'package:mobile/features/auth/login_page.dart';
import 'package:mobile/features/home/home_page.dart';
import 'package:mobile/features/product/product_detail_page.dart';
import 'package:mobile/features/product/seller_create_product_page.dart';
import 'package:mobile/features/product/seller_edit_product_page.dart';
import 'package:mobile/features/product/seller_products_page.dart';
import 'package:mobile/features/cart/cart_page.dart';
import 'package:mobile/features/order/seller_order_detail_page.dart';
import 'package:mobile/features/order/seller_orders_page.dart';
import 'package:mobile/features/order/orders_page.dart';
import 'package:mobile/features/order/order_detail_page.dart';
import 'package:mobile/features/payment/payment_page.dart';
import 'package:mobile/features/auth/register_page.dart';
import 'package:mobile/features/store/seller_onboarding_page.dart';
import 'package:mobile/features/store/seller_store_dashboard_page.dart';

final appRouter = GoRouter(
  initialLocation: '/login',

  refreshListenable: RouterRefreshStream(supabase.auth.onAuthStateChange),

  redirect: (context, state) {
    final session = supabase.auth.currentSession;

    final isLoggedIn = session != null;

    final isAuthRoute =
        state.matchedLocation == '/login' ||
        state.matchedLocation == '/register';

    if (!isLoggedIn && !isAuthRoute) {
      return '/login';
    }

    if (isLoggedIn && isAuthRoute) {
      return '/home';
    }

    return null;
  },

  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),

    GoRoute(
      path: '/register',

      builder: (context, state) {
        return const RegisterPage();
      },
    ),

    GoRoute(path: '/home', builder: (context, state) => const HomePage()),

    GoRoute(
      path: '/products/:id',

      builder: (context, state) {
        final productId = state.pathParameters['id']!;

        return ProductDetailPage(productId: productId);
      },
    ),

    GoRoute(path: '/cart', builder: (context, state) => const CartPage()),

    GoRoute(
      path: '/seller/onboarding',
      builder: (context, state) {
        return const SellerOnboardingPage();
      },
    ),

    GoRoute(
      path: '/seller/store',
      builder: (context, state) {
        return const SellerStoreDashboardPage();
      },
    ),

    GoRoute(
      path: '/seller/products',
      builder: (context, state) {
        return const SellerProductsPage();
      },
    ),

    GoRoute(
      path: '/seller/products/create',
      builder: (context, state) {
        return const SellerCreateProductPage();
      },
    ),

    GoRoute(
      path: '/seller/products/:id/edit',
      builder: (context, state) {
        final productId = state.pathParameters['id']!;

        return SellerEditProductPage(productId: productId);
      },
    ),

    GoRoute(
      path: '/seller/orders',
      builder: (context, state) {
        return const SellerOrdersPage();
      },
    ),

    GoRoute(
      path: '/seller/orders/:id',
      builder: (context, state) {
        final orderId = state.pathParameters['id']!;

        return SellerOrderDetailPage(orderId: orderId);
      },
    ),

    GoRoute(
      path: '/orders',
      builder: (context, state) {
        return const OrdersPage();
      },
    ),

    GoRoute(
      path: '/orders/:id',

      builder: (context, state) {
        final orderId = state.pathParameters['id']!;

        return OrderDetailPage(orderId: orderId);
      },
    ),

    GoRoute(
      path: '/payment',

      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;

        return PaymentPage(
          order: extra['order'],
          payment: extra['payment'],
          midtrans: extra['midtrans'],
        );
      },
    ),
  ],
);
