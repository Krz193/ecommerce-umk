import 'package:go_router/go_router.dart';
import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/core/router/router_refresh_stream.dart';
import 'package:mobile/features/auth/login_page.dart';
import 'package:mobile/features/home/home_page.dart';

final appRouter = GoRouter(
  initialLocation: '/login',

  refreshListenable: RouterRefreshStream(
    supabase.auth.onAuthStateChange,
  ),

  redirect: (context, state) {
    final session =
        supabase.auth.currentSession;

    final isLoggedIn = session != null;

    final isLoginRoute =
        state.matchedLocation == '/login';

    if (!isLoggedIn && !isLoginRoute) {
      return '/login';
    }

    if (isLoggedIn && isLoginRoute) {
      return '/home';
    }

    return null;
  },

  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) =>
          const LoginPage(),
    ),

    GoRoute(
      path: '/home',
      builder: (context, state) =>
          const HomePage(),
    ),
  ],
);