import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/realtime/realtime_controller.dart';
import 'features/auth/data/auth_controller.dart';
import 'features/bar/data/bar_status_repository.dart';

class DrunkardApp extends ConsumerStatefulWidget {
  const DrunkardApp({super.key});

  @override
  ConsumerState<DrunkardApp> createState() => _DrunkardAppState();
}

class _DrunkardAppState extends ConsumerState<DrunkardApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          ref.read(realtimeControllerProvider);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final currentUser = ref.watch(authControllerProvider).valueOrNull;
    if (currentUser != null) {
      ref.watch(barStatusProvider);
    }

    return MaterialApp.router(
      title: '酒鬼聚集地',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      scrollBehavior: const _DrunkardScrollBehavior(),
      routerConfig: router,
    );
  }
}

class _DrunkardScrollBehavior extends MaterialScrollBehavior {
  const _DrunkardScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
