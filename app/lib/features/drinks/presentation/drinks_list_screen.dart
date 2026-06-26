import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/colors.dart';
import '../../auth/data/auth_controller.dart';
import '../../bar/data/bar_status_repository.dart';
import '../../orders/data/cart_controller.dart';
import '../../orders/presentation/selected_drinks_bar.dart';
import '../../../shared/widgets/app_image.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/drinks_repository.dart';
import '../data/models/drink_model.dart';
import 'drink_editor_sheet.dart';

final drinksSearchProvider = StateProvider<String>((ref) => '');
final drinksCategoryProvider = StateProvider<String>((ref) => '全部');

class DrinksListScreen extends ConsumerWidget {
  const DrinksListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drinksState = ref.watch(drinksListProvider);
    final categoriesState = ref.watch(drinkCategoriesProvider);
    final searchQuery = ref.watch(drinksSearchProvider);
    final selectedCategory = ref.watch(drinksCategoryProvider);
    final currentUser = ref.watch(authControllerProvider).valueOrNull;
    final isAdmin = currentUser?.isAdmin ?? false;
    final barStatus = ref.watch(barStatusProvider).valueOrNull;

    return Scaffold(
      bottomNavigationBar: const SelectedDrinksBar(),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showDrinkEditor(context),
              backgroundColor: BarColors.neonPink,
              icon: const Icon(Icons.add),
              label: const Text('新增酒品'),
            )
          : null,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 240,
            flexibleSpace: FlexibleSpaceBar(
              background: _BarHero(
                nickname: currentUser?.nickname ?? 'Drunkard',
                statusLabel: barStatus?.label ?? '载入中',
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _SearchDock(
                categories: categoriesState.valueOrNull ?? const [],
                onChanged: (value) {
                  ref.read(drinksSearchProvider.notifier).state = value;
                },
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
            sliver: drinksState.when(
              data: (drinks) {
                final categories = _buildCategories(
                  drinks,
                  categoriesState.valueOrNull
                          ?.map((category) => category.name)
                          .toList() ??
                      const [],
                );
                final filtered =
                    _filterDrinks(drinks, searchQuery, selectedCategory);
                if (filtered.isEmpty) {
                  return SliverList.list(
                    children: [
                      _CategoryChips(
                        categories: categories,
                        selected: selectedCategory,
                        onSelected: (value) => ref
                            .read(drinksCategoryProvider.notifier)
                            .state = value,
                      ),
                      const SizedBox(height: 12),
                      const _EmptyState(message: '没有找到匹配的酒品'),
                    ],
                  );
                }

                return SliverMainAxisGroup(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          _CategoryChips(
                            categories: categories,
                            selected: selectedCategory,
                            onSelected: (value) => ref
                                .read(drinksCategoryProvider.notifier)
                                .state = value,
                          ),
                          const SizedBox(height: 14),
                        ],
                      ),
                    ),
                    SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.68,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _DrinkCard(
                          drink: filtered[index],
                          index: index,
                          isAdmin: isAdmin,
                        ),
                        childCount: filtered.length,
                      ),
                    ),
                  ],
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (error, stack) => SliverToBoxAdapter(
                child: _EmptyState(message: '酒单加载失败：$error'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDrinkEditor(BuildContext context, {Drink? drink}) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: BarColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DrinkEditorSheet(drink: drink),
    );
  }

  List<Drink> _filterDrinks(List<Drink> drinks, String query, String category) {
    final normalized = query.trim().toLowerCase();
    return drinks.where((drink) {
      final categoryMatched =
          category == '全部' || drink.category?.trim() == category;
      final queryMatched = normalized.isEmpty ||
          drink.name.toLowerCase().contains(normalized) ||
          (drink.nameEn?.toLowerCase().contains(normalized) ?? false) ||
          (drink.category?.toLowerCase().contains(normalized) ?? false);
      return categoryMatched && queryMatched;
    }).toList();
  }

  List<String> _buildCategories(List<Drink> drinks, List<String> managed) {
    final categories = <String>['全部'];
    final seen = <String>{'全部'};

    for (final category in managed) {
      final normalized = category.trim();
      if (normalized.isNotEmpty && seen.add(normalized)) {
        categories.add(normalized);
      }
    }

    for (final drink in drinks) {
      final normalized = drink.category?.trim();
      if (normalized != null && normalized.isNotEmpty && seen.add(normalized)) {
        categories.add(normalized);
      }
    }

    return categories;
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < categories.length; index++) ...[
          Expanded(
            child: _CategoryTile(
              category: categories[index],
              selected: selected == categories[index],
              onTap: () => onSelected(categories[index]),
            ),
          ),
          if (index != categories.length - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final String category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = _categoryAccent(category);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 42,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withOpacity(0.34),
                      accent.withOpacity(0.13),
                    ],
                  )
                : LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.055),
                      Colors.white.withOpacity(0.025),
                    ],
                  ),
            border: Border.all(
              color:
                  selected ? accent.withOpacity(0.72) : BarColors.glassBorder,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: accent.withOpacity(0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Text(
            category,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? accent : BarColors.textSecondary,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
              letterSpacing: selected ? 0.5 : 0.1,
            ),
          ),
        ),
      ),
    );
  }

  Color _categoryAccent(String category) {
    final normalized = category.toLowerCase();
    if (category == '全部') return BarColors.neonGold;
    if (normalized.contains('highball') ||
        category.contains('海波') ||
        category.contains('气泡') ||
        category.contains('苏打')) {
      return const Color(0xFF5EEBFF);
    }
    if (normalized.contains('sour') ||
        category.contains('酸') ||
        category.contains('柠') ||
        category.contains('青柠')) {
      return const Color(0xFFB8FF5E);
    }
    if (normalized.contains('tiki') ||
        normalized.contains('tropical') ||
        category.contains('热带') ||
        category.contains('果')) {
      return const Color(0xFFFF9F43);
    }
    if (normalized.contains('martini') ||
        category.contains('马天尼') ||
        category.contains('经典')) {
      return const Color(0xFF9BB7FF);
    }
    if (normalized.contains('old fashioned') ||
        normalized.contains('whisky') ||
        normalized.contains('whiskey') ||
        category.contains('威士忌') ||
        category.contains('古典')) {
      return const Color(0xFFFFB84D);
    }
    if (normalized.contains('spritz') ||
        category.contains('开胃') ||
        category.contains('微醺')) {
      return const Color(0xFFFF6FAE);
    }
    if (normalized.contains('shot') ||
        category.contains('烈') ||
        category.contains('短饮')) {
      return BarColors.neonPink;
    }
    if (category.contains('无酒精') ||
        normalized.contains('mocktail') ||
        normalized.contains('non')) {
      return BarColors.neonGreen;
    }
    return BarColors.neonBlue;
  }
}

class _BarHero extends StatelessWidget {
  const _BarHero({
    required this.nickname,
    required this.statusLabel,
  });

  final String nickname;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                BarColors.neonPink.withOpacity(0.24),
                BarColors.surfaceLight.withOpacity(0.94),
                BarColors.background,
              ],
            ),
          ),
        ),
        Positioned(
          right: -36,
          top: 42,
          child: Icon(
            Icons.local_bar,
            size: 150,
            color: Colors.white.withOpacity(0.06),
          ),
        ),
        Positioned(
          left: 18,
          right: 18,
          bottom: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_greeting()}，$nickname',
                style: const TextStyle(
                  color: BarColors.textPrimary,
                  fontSize: 31,
                  height: 1.05,
                  fontWeight: FontWeight.w300,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                '喝杯好酒，远离烂人',
                style: TextStyle(
                  color: BarColors.textSecondary,
                  fontSize: 15,
                  height: 1.45,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 14),
              _BarStatusChip(label: statusLabel),
            ],
          ),
        ),
      ],
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return '早上好';
    if (hour < 18) return '中午好';
    return '晚上好';
  }
}

class _BarStatusChip extends StatelessWidget {
  const _BarStatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (label) {
      '忙碌' => BarColors.neonGold,
      '未营业' => BarColors.error,
      _ => BarColors.neonGreen,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Text(
        '吧台状态 · $label',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _SearchDock extends StatelessWidget {
  const _SearchDock({
    required this.categories,
    required this.onChanged,
  });

  final List<DrinkCategory> categories;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: BarColors.neonBlue.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: TextField(
        onChanged: onChanged,
        style: const TextStyle(color: BarColors.textPrimary),
        decoration: InputDecoration(
          hintText: '搜索酒名 / 风格 / 英文名',
          hintStyle: const TextStyle(color: BarColors.textSecondary),
          prefixIcon: const Icon(Icons.search, color: BarColors.neonBlue),
          suffixIcon: IconButton(
            tooltip: '酒类说明',
            icon: const Icon(
              Icons.help_outline,
              color: BarColors.textSecondary,
              size: 20,
            ),
            onPressed: () => _showCategoryHelp(context),
          ),
          filled: true,
          fillColor: BarColors.surface.withOpacity(0.88),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: BarColors.neonBlue.withOpacity(0.55)),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }

  void _showCategoryHelp(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: BarColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _CategoryHelpSheet(categories: categories),
    );
  }
}

class _CategoryHelpSheet extends StatelessWidget {
  const _CategoryHelpSheet({required this.categories});

  final List<DrinkCategory> categories;

  @override
  Widget build(BuildContext context) {
    final visibleCategories = categories
        .where((category) => category.name.trim().isNotEmpty)
        .toList(growable: false);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '酒类说明',
                    style: TextStyle(
                      color: BarColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: BarColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              visibleCategories.isEmpty
                  ? '还没有维护酒类说明。'
                  : '这里展示调酒师在数据库 GUI 中维护的酒类备注。',
              style: const TextStyle(
                color: BarColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.62,
              ),
              child: visibleCategories.isEmpty
                  ? const SizedBox.shrink()
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: visibleCategories.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final category = visibleCategories[index];
                        final description =
                            category.description?.trim().isNotEmpty == true
                                ? category.description!.trim()
                                : '调酒师还没有为这个酒类写备注。';
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: BarColors.surfaceLight.withOpacity(0.72),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: BarColors.glassBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                category.name,
                                style: const TextStyle(
                                  color: BarColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                description,
                                style: const TextStyle(
                                  color: BarColors.textSecondary,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrinkCard extends ConsumerWidget {
  const _DrinkCard({
    required this.drink,
    required this.index,
    required this.isAdmin,
  });

  final Drink drink;
  final int index;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = RepaintBoundary(
      child: GestureDetector(
        onTap: () => context.push('/drinks/${drink.id}'),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.1),
                    BarColors.surface.withOpacity(0.82),
                  ],
                ),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
                boxShadow: [
                  BoxShadow(
                    color: (drink.isAvailable
                            ? BarColors.neonPink
                            : BarColors.error)
                        .withOpacity(0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 7,
                    child: _DrinkImage(photoUrl: drink.photoUrl),
                  ),
                  Expanded(
                    flex: 5,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  drink.name,
                                  style: const TextStyle(
                                    color: BarColors.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              _StatusDot(isAvailable: drink.isAvailable),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            drink.nameEn?.isNotEmpty ?? false
                                ? drink.nameEn!
                                : 'Signature pour',
                            style: const TextStyle(
                              color: BarColors.textSecondary,
                              fontSize: 11,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _MiniTag(
                                label: drink.isAvailable ? '可点' : '需自备',
                                color: drink.isAvailable
                                    ? BarColors.neonGreen
                                    : BarColors.error,
                              ),
                              if (drink.category?.isNotEmpty ?? false)
                                _MiniTag(
                                    label: drink.category!,
                                    color: BarColors.neonGold),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isAdmin)
              Positioned(
                top: 10,
                right: 10,
                child: Material(
                  color: BarColors.surface.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _openEditorWithDetail(context, ref),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.edit,
                        size: 18,
                        color: BarColors.neonBlue,
                      ),
                    ),
                  ),
                ),
              ),
            if (!isAdmin)
              Positioned(
                right: 10,
                bottom: 10,
                child: _AddDrinkButton(drink: drink),
              ),
          ],
        ),
      ),
    );
    if (index >= 6) {
      return card;
    }
    return card.animate().fadeIn(delay: (36 * index).ms).slideY(begin: 0.035);
  }

  Future<void> _openEditorWithDetail(
      BuildContext context, WidgetRef ref) async {
    try {
      final fullDrink = await ref.read(drinkDetailProvider(drink.id).future);
      if (!context.mounted) {
        return;
      }

      await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: BarColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) => DrinkEditorSheet(drink: fullDrink),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      showAppToast(context, '酒品详情加载失败：$error');
    }
  }
}

class _AddDrinkButton extends ConsumerWidget {
  const _AddDrinkButton({required this.drink});

  final Drink drink;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: BarColors.neonPink,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          final notes = drink.missingIngredients.isNotEmpty
              ? '用户自备原料：${drink.missingIngredients.join('、')}'
              : null;
          ref
              .read(cartControllerProvider.notifier)
              .addDrink(drink, notes: notes);
          showAppToast(context, '已选：${drink.name}');
        },
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Icon(
            Icons.add_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.isAvailable});

  final bool isAvailable;

  @override
  Widget build(BuildContext context) {
    final color = isAvailable ? BarColors.neonGreen : BarColors.error;
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.65),
            blurRadius: 10,
          ),
        ],
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.24)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DrinkImage extends StatelessWidget {
  const _DrinkImage({required this.photoUrl});

  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl =
        photoUrl?.trim().isNotEmpty == true ? photoUrl!.trim() : null;
    final decoration = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          BarColors.neonPink.withOpacity(0.28),
          BarColors.neonBlue.withOpacity(0.18),
          BarColors.surfaceLight,
        ],
      ),
    );

    if (resolvedUrl == null) {
      return Container(
        decoration: decoration,
        child: const Icon(Icons.local_bar, size: 48, color: BarColors.neonGold),
      );
    }

    return Container(
      decoration: decoration,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
          return appImage(
            resolvedUrl,
            fit: BoxFit.cover,
            cacheWidth: (constraints.maxWidth * devicePixelRatio).round(),
            cacheHeight: (constraints.maxHeight * devicePixelRatio).round(),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: GlassCard(
        child: Center(
          child: Text(
            message,
            style: const TextStyle(color: BarColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
