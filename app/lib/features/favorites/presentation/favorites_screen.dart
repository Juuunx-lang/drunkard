import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/theme/colors.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/favorites_repository.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesState = ref.watch(favoritesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的喜欢'),
        leading: IconButton(
          onPressed: () => context.go('/profile'),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
      ),
      body: favoritesState.when(
        data: (drinks) {
          if (drinks.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: GlassCard(
                  borderRadius: 18,
                  child: Text(
                    '还没有点亮爱心。去酒品详情页收藏今晚喜欢的那一杯吧。',
                    style: TextStyle(color: BarColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(favoritesListProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
              itemCount: drinks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final drink = drinks[index];
                final photoUrl = ApiConstants.resolveUrl(drink.photoUrl);
                return InkWell(
                  onTap: () => context.push('/drinks/${drink.id}'),
                  borderRadius: BorderRadius.circular(18),
                  child: GlassCard(
                    borderRadius: 18,
                    child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 68,
                          height: 68,
                          color: BarColors.neonPink.withOpacity(0.12),
                          child: photoUrl == null
                              ? const Icon(Icons.local_bar,
                                  color: BarColors.neonGold)
                              : Image.network(photoUrl, fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              drink.name,
                              style: const TextStyle(
                                color: BarColors.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              drink.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: BarColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.favorite, color: BarColors.neonPink),
                    ],
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text(
            '喜欢列表加载失败：$error',
            style: const TextStyle(color: BarColors.textSecondary),
          ),
        ),
      ),
    );
  }
}
