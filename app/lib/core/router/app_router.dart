import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/data/auth_controller.dart';
import '../../features/auth/presentation/auth_callback_screen.dart';
import '../../features/auth/presentation/bind_phone_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/account_security_screen.dart';
import '../../features/admin/presentation/admin_database_screen.dart';
import '../../features/auth/presentation/help_screen.dart';
import '../../features/drinks/presentation/drinks_list_screen.dart';
import '../../features/drinks/presentation/drink_detail_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/inventory/presentation/inventory_screen.dart';
import '../../features/reviews/presentation/reviews_screen.dart';
import '../../features/auth/presentation/profile_history_orders_screen.dart';
import '../../features/auth/presentation/profile_reviews_screen.dart';
import '../../features/auth/presentation/profile_screen.dart';
import '../../features/auth/presentation/public_profile_screen.dart';
import '../../features/community/presentation/community_screen.dart';
import '../../features/community/presentation/community_post_detail_screen.dart';
import '../../features/community/presentation/community_post_editor_screen.dart';
import '../../features/favorites/presentation/favorites_screen.dart';
import '../../shared/widgets/app_scaffold.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      if (authState.isLoading) {
        return null;
      }

      final isLoggedIn = authState.valueOrNull != null;
      final isLoginRoute = state.matchedLocation == '/login';
      final isAuthCallbackRoute = state.matchedLocation == '/auth-callback';
      final isBindPhoneRoute = state.matchedLocation == '/bind-phone';

      if (!isLoggedIn) {
        return isLoginRoute || isAuthCallbackRoute ? null : '/login';
      }

      if (isLoginRoute) {
        return '/';
      }

      final user = authState.valueOrNull;
      final needsPhoneBinding =
          user != null && !user.isAdmin && (user.phone?.trim().isEmpty ?? true);
      if (needsPhoneBinding && !isBindPhoneRoute && !isAuthCallbackRoute) {
        return '/bind-phone';
      }
      if (!needsPhoneBinding && isBindPhoneRoute) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) =>
            _cupertinoPage(state, const LoginScreen()),
      ),
      GoRoute(
        path: '/auth-callback',
        pageBuilder: (context, state) => _cupertinoPage(
          state,
          AuthCallbackScreen(token: state.uri.queryParameters['token']),
        ),
      ),
      GoRoute(
        path: '/bind-phone',
        pageBuilder: (context, state) =>
            _cupertinoPage(state, const BindPhoneScreen()),
      ),
      ShellRoute(
        builder: (context, state, child) => AppScaffold(child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) =>
                _noTransitionPage(state, const DrinksListScreen()),
          ),
          GoRoute(
            path: '/drinks/:id',
            pageBuilder: (context, state) => _cupertinoPage(
              state,
              DrinkDetailScreen(drinkId: state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/drinks/:id/reviews',
            pageBuilder: (context, state) => _cupertinoPage(
              state,
              ReviewsScreen(drinkId: state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/orders',
            pageBuilder: (context, state) =>
                _noTransitionPage(state, const OrdersScreen()),
          ),
          GoRoute(
            path: '/community',
            pageBuilder: (context, state) =>
                _noTransitionPage(state, const CommunityScreen()),
          ),
          GoRoute(
            path: '/community/new',
            pageBuilder: (context, state) =>
                _cupertinoPage(state, const CommunityPostEditorScreen()),
          ),
          GoRoute(
            path: '/community/:id/edit',
            pageBuilder: (context, state) => _cupertinoPage(
              state,
              CommunityPostEditorScreen(postId: state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/community/:id',
            pageBuilder: (context, state) => _cupertinoPage(
              state,
              CommunityPostDetailScreen(postId: state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/inventory',
            pageBuilder: (context, state) =>
                _noTransitionPage(state, const InventoryScreen()),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) =>
                _noTransitionPage(state, const ProfileScreen()),
          ),
          GoRoute(
            path: '/users/:id',
            pageBuilder: (context, state) => _cupertinoPage(
              state,
              PublicProfileScreen(userId: state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/profile/history-orders',
            pageBuilder: (context, state) =>
                _cupertinoPage(state, const ProfileHistoryOrdersScreen()),
          ),
          GoRoute(
            path: '/profile/reviews',
            pageBuilder: (context, state) =>
                _cupertinoPage(state, const ProfileReviewsScreen()),
          ),
          GoRoute(
            path: '/profile/favorites',
            pageBuilder: (context, state) =>
                _cupertinoPage(state, const FavoritesScreen()),
          ),
          GoRoute(
            path: '/profile/account-security',
            pageBuilder: (context, state) =>
                _cupertinoPage(state, const AccountSecurityScreen()),
          ),
          GoRoute(
            path: '/profile/help',
            pageBuilder: (context, state) =>
                _cupertinoPage(state, const HelpScreen()),
          ),
          GoRoute(
            path: '/admin/database',
            pageBuilder: (context, state) =>
                _cupertinoPage(state, const AdminDatabaseScreen()),
          ),
        ],
      ),
    ],
  );
});

Page<void> _cupertinoPage(GoRouterState state, Widget child) {
  return CupertinoPage<void>(
    key: state.pageKey,
    child: child,
  );
}

Page<void> _noTransitionPage(GoRouterState state, Widget child) {
  return NoTransitionPage<void>(
    key: state.pageKey,
    child: child,
  );
}
