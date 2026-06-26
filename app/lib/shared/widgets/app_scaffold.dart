import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../features/auth/data/auth_controller.dart';

class AppScaffold extends ConsumerStatefulWidget {
  final Widget child;

  const AppScaffold({super.key, required this.child});

  @override
  ConsumerState<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends ConsumerState<AppScaffold> {
  int? _activeTabIndex;
  int _transitionSerial = 0;
  int _slideDirection = 0;
  int? _pendingDirection;
  bool _animateNextTabChange = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authControllerProvider).valueOrNull;
    final tabs = [
      const _TabItem(icon: Icons.local_bar, label: '酒单', path: '/'),
      const _TabItem(icon: Icons.forum, label: '社区', path: '/community'),
      const _TabItem(icon: Icons.receipt_long, label: '订单', path: '/orders'),
      if (currentUser?.isAdmin ?? false)
        const _TabItem(
            icon: Icons.inventory_2, label: '备货', path: '/inventory'),
      const _TabItem(icon: Icons.person, label: '我的', path: '/profile'),
    ];
    final currentLocation = GoRouterState.of(context).matchedLocation;
    final safeCurrentIndex = _tabIndexForLocation(currentLocation, tabs) ?? 0;
    if (_activeTabIndex == null) {
      _activeTabIndex = safeCurrentIndex;
    } else if (_activeTabIndex != safeCurrentIndex) {
      _slideDirection = _animateNextTabChange
          ? _pendingDirection ?? (safeCurrentIndex > _activeTabIndex! ? 1 : -1)
          : 0;
      _pendingDirection = null;
      _animateNextTabChange = false;
      _activeTabIndex = safeCurrentIndex;
      _transitionSerial++;
    }

    return Scaffold(
      body: Stack(
        children: [
          const _Atmosphere(),
          TweenAnimationBuilder<double>(
            key: ValueKey('tab-$safeCurrentIndex-$_transitionSerial'),
            tween: Tween<double>(
              begin: _slideDirection.toDouble(),
              end: 0,
            ),
            duration: _slideDirection == 0
                ? Duration.zero
                : const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              final width = MediaQuery.sizeOf(context).width;
              return Transform.translate(
                offset: Offset(width * value, 0),
                child: child,
              );
            },
            child: widget.child,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    BarColors.surface.withValues(alpha: 0.92),
                    BarColors.surfaceLight.withValues(alpha: 0.78),
                  ],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                boxShadow: [
                  BoxShadow(
                    color: BarColors.neonPink.withValues(alpha: 0.12),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: BottomNavigationBar(
                currentIndex: safeCurrentIndex,
                onTap: (index) {
                  if (index == safeCurrentIndex) return;
                  _pendingDirection = index > safeCurrentIndex ? 1 : -1;
                  _animateNextTabChange = true;
                  Router.neglect(
                    context,
                    () => context.go(tabs[index].path),
                  );
                },
                items: tabs
                    .map((tab) => BottomNavigationBarItem(
                          icon: Icon(tab.icon),
                          label: tab.label,
                        ))
                    .toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static int? _tabIndexForLocation(String location, List<_TabItem> tabs) {
    for (var index = 0; index < tabs.length; index++) {
      final path = tabs[index].path;
      if (location == path) return index;
      if (path != '/' && location.startsWith('$path/')) return index;
      if (path == '/' && location.startsWith('/drinks')) return index;
    }
    return null;
  }
}

class _Atmosphere extends StatelessWidget {
  const _Atmosphere();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.9, -0.8),
            radius: 1.25,
            colors: [
              BarColors.neonPink.withValues(alpha: 0.18),
              Colors.transparent,
            ],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.95, -0.15),
              radius: 1.05,
              colors: [
                BarColors.neonBlue.withValues(alpha: 0.13),
                Colors.transparent,
              ],
            ),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final String label;
  final String path;

  const _TabItem({required this.icon, required this.label, required this.path});
}
