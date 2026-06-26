import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/colors.dart';
import '../../auth/data/auth_controller.dart';
import '../../../shared/widgets/app_image.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../favorites/data/favorites_repository.dart';
import '../../orders/data/cart_controller.dart';
import '../../orders/presentation/selected_drinks_bar.dart';
import '../data/drinks_repository.dart';
import '../data/models/drink_model.dart';

class DrinkDetailScreen extends ConsumerStatefulWidget {
  const DrinkDetailScreen({
    super.key,
    required this.drinkId,
  });

  final String drinkId;

  @override
  ConsumerState<DrinkDetailScreen> createState() => _DrinkDetailScreenState();
}

class _DrinkDetailScreenState extends ConsumerState<DrinkDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final drinkState = ref.watch(drinkDetailProvider(widget.drinkId));
    final currentUser = ref.watch(authControllerProvider).valueOrNull;
    final isAdmin = currentUser?.isAdmin ?? false;

    return Scaffold(
      bottomNavigationBar: const SelectedDrinksBar(),
      body: drinkState.when(
        data: (drink) => CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 340,
              pinned: true,
              leading: IconButton(
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
              ),
              actions: [
                _FavoriteButton(drinkId: drink.id),
                const SizedBox(width: 8),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: _DrinkHeaderImage(
                  photoUrl: drink.photoUrl,
                  available: drink.isAvailable,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTitleCard(drink),
                    const SizedBox(height: 16),
                    _buildDescriptionCard(drink),
                    if (drink.missingIngredients.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildShortageCard(drink),
                    ],
                    const SizedBox(height: 18),
                    _buildIngredientsSection(drink),
                    if (isAdmin) ...[
                      const SizedBox(height: 18),
                      _buildRecipeSection(drink.recipe),
                    ],
                    const SizedBox(height: 18),
                    _buildReviewsPreview(context, drink),
                  ].animate(interval: 100.ms).fadeIn().slideX(begin: -0.02),
                ),
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '酒品详情加载失败：$error',
              style: const TextStyle(color: BarColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      floatingActionButton: drinkState.maybeWhen(
        data: (drink) => isAdmin
            ? null
            : FloatingActionButton(
                onPressed: () => _addToSelectedList(context, ref, drink),
                backgroundColor: drink.missingIngredients.isNotEmpty
                    ? BarColors.neonGold
                    : BarColors.neonPink,
                child: const Icon(Icons.add_rounded),
              ),
        orElse: () => null,
      ),
    );
  }

  Future<void> _addToSelectedList(
    BuildContext context,
    WidgetRef ref,
    Drink drink,
  ) async {
    String? shortageNote;
    if (drink.missingIngredients.isNotEmpty) {
      shortageNote = '用户自备原料：${drink.missingIngredients.join('、')}';
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: BarColors.surface,
          title: const Text(
            '此酒当前缺料',
            style: TextStyle(color: BarColors.textPrimary),
          ),
          content: Text(
            '当前缺少：${drink.missingIngredients.join('、')}。\n\n如需下单，请自备以上缺货材料后再继续。',
            style: const TextStyle(
              color: BarColors.textSecondary,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('我再想想'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('已知晓，继续下单'),
            ),
          ],
        ),
      );

      if (shouldContinue != true) {
        return;
      }
    }

    ref
        .read(cartControllerProvider.notifier)
        .addDrink(drink, notes: shortageNote);
    if (!context.mounted) return;
    showAppToast(context, '已选：${drink.name}');
  }

  Widget _buildTitleCard(Drink drink) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.13),
            BarColors.surfaceLight.withOpacity(0.88),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
        boxShadow: [
          BoxShadow(
            color: BarColors.neonPink.withOpacity(0.14),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      drink.name,
                      style: const TextStyle(
                        color: BarColors.textPrimary,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (drink.nameEn?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 5),
                      Text(
                        drink.nameEn!,
                        style: const TextStyle(
                          color: BarColors.textSecondary,
                          fontSize: 14,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _buildStatusPill(drink.isAvailable),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (drink.abv != null)
                _buildInfoPill(
                    'ABV', _formatAbv(drink.abv!), BarColors.neonGold),
              if (drink.category?.isNotEmpty ?? false)
                _buildInfoPill('STYLE', drink.category!, BarColors.neonBlue),
              _buildInfoPill('MOOD', 'Private Bar', BarColors.neonPink),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard(Drink drink) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BarColors.surface.withOpacity(0.78),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: BarColors.glassBorder),
      ),
      child: Text(
        drink.description,
        style: const TextStyle(
          color: BarColors.textPrimary,
          fontSize: 15,
          height: 1.65,
        ),
      ),
    );
  }

  Widget _buildShortageCard(Drink drink) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BarColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: BarColors.error.withOpacity(0.38)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: BarColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '此酒当前缺料',
                  style: TextStyle(
                    color: BarColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '缺少材料：${drink.missingIngredients.join('、')}',
                  style: const TextStyle(
                      color: BarColors.textPrimary, height: 1.5),
                ),
                const SizedBox(height: 6),
                const Text(
                  '继续下单会自动写入订单备注，请客人自备缺货材料。',
                  style: TextStyle(
                      color: BarColors.error, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(bool isAvailable) {
    final color = isAvailable ? BarColors.neonGreen : BarColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        isAvailable ? '可点单' : '缺货',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildInfoPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Text(
        '$label  $value',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  String _formatAbv(double abv) {
    final display = abv.truncateToDouble() == abv
        ? abv.toStringAsFixed(0)
        : abv.toStringAsFixed(1);
    return '$display%';
  }

  Widget _buildIngredientsSection(Drink drink) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BarColors.surface.withOpacity(0.78),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: BarColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '出杯材料',
            style: TextStyle(
              color: BarColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          ...drink.ingredients.map(
            (ingredient) => _ingredientRow(
              ingredient.name,
              ingredient.amount ?? '适量',
              ingredient.inStock || ingredient.isOptional,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ingredientRow(String name, String amount, bool inStock) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            inStock ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: inStock ? BarColors.neonGreen : BarColors.error,
          ),
          const SizedBox(width: 8),
          Text(
            name,
            style: const TextStyle(color: BarColors.textPrimary, fontSize: 14),
          ),
          const Spacer(),
          Text(
            amount,
            style:
                const TextStyle(color: BarColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeSection(String? recipe) {
    final hasRecipe = recipe?.trim().isNotEmpty ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BarColors.neonBlue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: BarColors.neonBlue.withOpacity(0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasRecipe ? '管理员配方' : '管理员配方未填写',
            style: const TextStyle(
              color: BarColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            hasRecipe ? recipe!.trim() : '这里不会对普通用户展示。编辑酒品后可写入调制步骤，也可以保持为空。',
            style: TextStyle(
              color:
                  hasRecipe ? BarColors.textPrimary : BarColors.textSecondary,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsPreview(BuildContext context, Drink drink) {
    final preview = drink.reviews.isEmpty ? null : drink.reviews.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '评价',
              style: TextStyle(
                color: BarColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/drinks/${drink.id}/reviews'),
              child: const Text('查看全部',
                  style: TextStyle(color: BarColors.neonBlue)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (preview == null)
          const GlassCard(
            child: Text(
              '暂时还没有评价',
              style: TextStyle(color: BarColors.textSecondary),
            ),
          )
        else
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: preview.userId == null || preview.userId!.isEmpty
                            ? null
                            : () => context.push('/users/${preview.userId}'),
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor:
                                    BarColors.neonBlue.withOpacity(0.2),
                                backgroundImage:
                                    appImageProvider(preview.avatarUrl),
                                child:
                                    appImageProvider(preview.avatarUrl) == null
                                        ? Text(
                                            preview.nickname.isEmpty
                                                ? '?'
                                                : preview.nickname[0],
                                            style: const TextStyle(
                                                color: BarColors.neonBlue),
                                          )
                                        : null,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  preview.nickname,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: BarColors.textPrimary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              if (preview.userId != null &&
                                  preview.userId!.isNotEmpty)
                                const Icon(
                                  Icons.chevron_right,
                                  size: 16,
                                  color: BarColors.textSecondary,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Text(
                      _formatReviewTime(preview.createdAt),
                      style: const TextStyle(
                          color: BarColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
                if (preview.rating != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(
                      5,
                      (index) => Icon(
                        index < preview.rating!
                            ? Icons.star
                            : Icons.star_border,
                        size: 14,
                        color: BarColors.neonGold,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  preview.content,
                  style: const TextStyle(
                      color: BarColors.textPrimary, fontSize: 14),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _formatReviewTime(DateTime? createdAt) {
    if (createdAt == null) {
      return '刚刚';
    }
    return DateFormat('yyyy-MM-dd HH:mm').format(createdAt.toLocal());
  }
}

class _FavoriteButton extends ConsumerWidget {
  const _FavoriteButton({required this.drinkId});

  final String drinkId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(favoriteStatusProvider(drinkId));
    final liked = status.valueOrNull ?? false;
    return IconButton(
      onPressed: status.isLoading
          ? null
          : () async {
              await ref
                  .read(favoritesRepositoryProvider)
                  .setLiked(drinkId, !liked);
              ref.invalidate(favoriteStatusProvider(drinkId));
              ref.invalidate(favoritesListProvider);
            },
      icon: Icon(
        liked ? Icons.favorite : Icons.favorite_border,
        color: liked ? BarColors.neonPink : BarColors.textPrimary,
      ),
      tooltip: liked ? '取消喜欢' : '加入喜欢',
    );
  }
}

class _DrinkHeaderImage extends StatelessWidget {
  const _DrinkHeaderImage({
    required this.photoUrl,
    required this.available,
  });

  final String? photoUrl;
  final bool available;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl =
        photoUrl?.trim().isNotEmpty == true ? photoUrl!.trim() : null;

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                BarColors.neonPink.withOpacity(0.3),
                BarColors.neonBlue.withOpacity(0.2),
                BarColors.background,
              ],
            ),
          ),
          child: resolvedUrl == null
              ? const Center(
                  child: Icon(Icons.local_bar,
                      size: 100, color: BarColors.neonGold),
                )
              : GestureDetector(
                  onTap: () => showImagePreview(context, source: resolvedUrl),
                  child: appImage(
                    resolvedUrl,
                    fit: BoxFit.cover,
                  ),
                ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.04),
                BarColors.background.withOpacity(0.82),
              ],
            ),
          ),
        ),
        Positioned(
          left: 18,
          bottom: 22,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.42),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withOpacity(0.14)),
            ),
            child: Text(
              available ? '可点单' : '需自备缺料',
              style: const TextStyle(
                color: BarColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
