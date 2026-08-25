import 'package:go_router/go_router.dart';
import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/core/router/customer_shell.dart';
import 'package:mobile/core/router/router_refresh_stream.dart';
import 'package:mobile/features/account/account_page.dart';
import 'package:mobile/features/account/edit_profile_page.dart';
import 'package:mobile/features/account/change_password_page.dart';
import 'package:mobile/features/address/address_form_page.dart';
import 'package:mobile/features/address/address_list_page.dart';
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
import 'package:mobile/features/store/models/store_model.dart';
import 'package:mobile/features/store/seller_edit_store_page.dart';
import 'package:mobile/features/store/seller_onboarding_page.dart';
import 'package:mobile/features/store/seller_reviews_page.dart';
import 'package:mobile/features/store/seller_store_dashboard_page.dart';
import 'package:mobile/features/store/store_public_page.dart';
import 'package:mobile/features/assistant/models/store_content_model.dart';
import 'package:mobile/features/assistant/screens/assistance_log_page.dart';
import 'package:mobile/features/assistant/screens/assistant_dashboard_page.dart';
import 'package:mobile/features/assistant/screens/assistant_profile_page.dart';
import 'package:mobile/features/assistant/screens/store_content_form_page.dart';
import 'package:mobile/features/assistant/screens/store_content_list_page.dart';
import 'package:mobile/features/explore/explore_page.dart';
import 'package:mobile/features/feedback/screens/feedback_page.dart';
import 'package:mobile/features/training/screens/training_list_page.dart';

final appRouter = GoRouter(
  initialLocation: '/login',

  refreshListenable: RouterRefreshStream(supabase.auth.onAuthStateChange),

  redirect: (context, state) {
    final session = supabase.auth.currentSession;

    final isLoggedIn = session != null;

    final isAuthRoute =
        state.matchedLocation == '/login' ||
        state.matchedLocation == '/register';

    if (state.matchedLocation == '/') {
      return isLoggedIn ? '/home' : '/login';
    }

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

    ShellRoute(
      builder: (context, state, child) {
        return CustomerShell(child: child);
      },
      routes: [
        GoRoute(path: '/home', builder: (context, state) => const HomePage()),

        GoRoute(
          path: '/explore',
          builder: (context, state) {
            return const ExplorePage();
          },
        ),

        GoRoute(
          path: '/orders',
          builder: (context, state) {
            return const OrdersPage();
          },
        ),

        GoRoute(
          path: '/account',
          builder: (context, state) {
            return const AccountPage();
          },
        ),

        GoRoute(
          path: '/account/edit',
          builder: (context, state) {
            return const EditProfilePage();
          },
        ),

        GoRoute(
          path: '/account/change-password',
          builder: (context, state) {
            return const ChangePasswordPage();
          },
        ),

        GoRoute(
          path: '/feedback',
          builder: (context, state) {
            return const FeedbackPage();
          },
        ),
      ],
    ),

    GoRoute(path: '/cart', builder: (context, state) => const CartPage()),

    GoRoute(
      path: '/products/:id',

      builder: (context, state) {
        final productId = state.pathParameters['id']!;

        return ProductDetailPage(productId: productId);
      },
    ),

    GoRoute(
      path: '/stores/:id',
      builder: (context, state) {
        final storeId = state.pathParameters['id']!;

        return StorePublicPage(storeId: storeId);
      },
    ),

    GoRoute(
      path: '/addresses',
      builder: (context, state) {
        return const AddressListPage();
      },
    ),

    GoRoute(
      path: '/addresses/create',
      builder: (context, state) {
        return const AddressFormPage();
      },
    ),

    GoRoute(
      path: '/addresses/:id/edit',
      builder: (context, state) {
        final addressId = state.pathParameters['id']!;

        return AddressFormPage(addressId: addressId);
      },
    ),

    GoRoute(
      path: '/edit-profile',
      builder: (context, state) => const EditProfilePage(),
    ),

    GoRoute(
      path: '/seller/edit-store',
      builder: (context, state) {
        final store = state.extra as StoreModel;
        return SellerEditStorePage(store: store);
      },
    ),

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
      path: '/seller/reports',
      builder: (context, state) {
        return const SellerStoreReportsPage();
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
      path: '/seller/reviews',
      builder: (context, state) {
        return const SellerReviewsPage();
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
      path: '/store/:id',
      builder: (context, state) {
        final storeId = state.pathParameters['id']!;

        return StorePublicPage(storeId: storeId);
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

    GoRoute(
      path: '/assistant/dashboard',
      builder: (context, state) => const AssistantDashboardPage(),
    ),
    GoRoute(
      path: '/assistant/profile',
      builder: (context, state) => const AssistantProfilePage(),
    ),
    GoRoute(
      path: '/assistant/logs',
      builder: (context, state) {
        final storeId = state.uri.queryParameters['storeId'];
        return AssistanceLogPage(storeId: storeId);
      },
    ),
    GoRoute(
      path: '/assistant/contents',
      builder: (context, state) {
        final storeId = state.uri.queryParameters['storeId'] ?? '';
        final storeName = state.uri.queryParameters['storeName'];
        return StoreContentListPage(storeId: storeId, storeName: storeName);
      },
    ),
    GoRoute(
      path: '/assistant/contents/create',
      builder: (context, state) {
        final storeId = state.uri.queryParameters['storeId'] ?? '';
        return StoreContentFormPage(storeId: storeId);
      },
    ),
    GoRoute(
      path: '/assistant/contents/edit/:id',
      builder: (context, state) {
        final storeId = state.uri.queryParameters['storeId'] ?? '';
        final existingContent = state.extra as StoreContentModel?;
        return StoreContentFormPage(
          storeId: storeId,
          existingContent: existingContent,
        );
      },
    ),
    GoRoute(
      path: '/trainings',
      builder: (context, state) => const TrainingListPage(),
    ),
  ],
);
