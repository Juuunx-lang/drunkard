import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/colors.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/auth_controller.dart';
import '../../orders/data/order_model.dart';
import '../../orders/data/orders_repository.dart';
import '../../reviews/data/reviews_repository.dart';
import '../../reviews/presentation/review_card.dart';

class ProfileReviewsScreen extends ConsumerStatefulWidget {
  const ProfileReviewsScreen({super.key});

  @override
  ConsumerState<ProfileReviewsScreen> createState() =>
      _ProfileReviewsScreenState();
}

class _ProfileReviewsScreenState extends ConsumerState<ProfileReviewsScreen> {
  String _selectedUserId = 'ALL';

  @override
  Widget build(BuildContext context) {
    final ordersState = ref.watch(ordersListProvider);
    final isAdmin = ref.watch(authControllerProvider).valueOrNull?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(isAdmin ? '全部评论' : '我的评论'),
        leading: IconButton(
          onPressed: () => context.go('/profile'),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
      ),
      body: ordersState.when(
        data: (orders) {
          final allReviewedItems = orders
              .expand((order) => order.items)
              .where((item) => item.review != null)
              .toList();
          final users = {
            for (final item in allReviewedItems)
              if (item.review?.userId != null)
                item.review!.userId!: item.review!.nickname
          };
          final reviewedItems = allReviewedItems.where((item) {
            return _selectedUserId == 'ALL' ||
                item.review?.userId == _selectedUserId;
          }).toList();

          if (reviewedItems.isEmpty) {
            return const _EmptyReviews();
          }

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(ordersListProvider.future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
              children: [
                _ReviewSummary(count: reviewedItems.length),
                if (isAdmin && users.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedUserId,
                    decoration: const InputDecoration(labelText: '筛选用户'),
                    items: [
                      const DropdownMenuItem(value: 'ALL', child: Text('全部用户')),
                      ...users.entries.map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _selectedUserId = value ?? 'ALL'),
                  ),
                ],
                const SizedBox(height: 16),
                ...List.generate(
                  reviewedItems.length,
                  (index) => _MyReviewCard(
                    item: reviewedItems[index],
                    index: index,
                    isAdmin: isAdmin,
                    onDelete: () async {
                      await ref
                          .read(reviewsRepositoryProvider)
                          .deleteReview(reviewedItems[index].review!.id);
                      ref.invalidate(ordersListProvider);
                    },
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '我的评论加载失败：$error',
              style: const TextStyle(color: BarColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewSummary extends StatelessWidget {
  const _ReviewSummary({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 18,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: BarColors.neonBlue.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.rate_review_outlined,
                color: BarColors.neonBlue),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count 条评论',
                  style: const TextStyle(
                    color: BarColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '你写过的体验，会在这里形成自己的口味档案。',
                  style: TextStyle(
                    color: BarColors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MyReviewCard extends StatelessWidget {
  const _MyReviewCard({
    required this.item,
    required this.index,
    required this.isAdmin,
    required this.onDelete,
  });

  final OrderItem item;
  final int index;
  final bool isAdmin;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push('/drinks/${item.drinkId}/reviews'),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.local_bar,
                    size: 16, color: BarColors.neonPink),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.drink.name,
                    style: const TextStyle(
                      color: BarColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ReviewCard(review: item.review!, index: index),
          if (isAdmin)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, color: BarColors.error),
                label: const Text('删除评论',
                    style: TextStyle(color: BarColors.error)),
              ),
            ),
        ],
        ),
      ),
    );
  }
}

class _EmptyReviews extends StatelessWidget {
  const _EmptyReviews();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GlassCard(
          borderRadius: 18,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.chat_bubble_outline,
                  size: 42, color: BarColors.neonBlue),
              SizedBox(height: 12),
              Text(
                '还没有评论',
                style: TextStyle(
                  color: BarColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 6),
              Text(
                '订单完成后，可以在订单流程里发表体验评价；写过的内容会归档到这里。',
                style: TextStyle(
                  color: BarColors.textSecondary,
                  fontSize: 13,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
