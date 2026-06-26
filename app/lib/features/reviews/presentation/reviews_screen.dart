import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/colors.dart';
import '../data/reviews_repository.dart';
import 'review_card.dart';

class ReviewsScreen extends ConsumerWidget {
  const ReviewsScreen({
    super.key,
    required this.drinkId,
  });

  final String drinkId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsState = ref.watch(drinkReviewsProvider(drinkId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('全部评价'),
        leading: IconButton(
          onPressed: () => context.go('/drinks/$drinkId'),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
      ),
      body: reviewsState.when(
        data: (reviews) {
          if (reviews.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  '还没有评价，完成订单后可以在订单页补评论。',
                  style: TextStyle(color: BarColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reviews.length,
            itemBuilder: (context, index) => ReviewCard(
              review: reviews[index],
              index: index,
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '评价加载失败：$error',
              style: const TextStyle(color: BarColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
