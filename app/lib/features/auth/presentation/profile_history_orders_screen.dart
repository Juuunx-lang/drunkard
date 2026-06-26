import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/colors.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/auth_controller.dart';
import '../../orders/data/order_model.dart';
import '../../orders/data/orders_repository.dart';

class ProfileHistoryOrdersScreen extends ConsumerStatefulWidget {
  const ProfileHistoryOrdersScreen({super.key});

  @override
  ConsumerState<ProfileHistoryOrdersScreen> createState() =>
      _ProfileHistoryOrdersScreenState();
}

class _ProfileHistoryOrdersScreenState
    extends ConsumerState<ProfileHistoryOrdersScreen> {
  String _selectedUserId = 'ALL';

  @override
  Widget build(BuildContext context) {
    final ordersState = ref.watch(ordersListProvider);
    final isAdmin =
        ref.watch(authControllerProvider).valueOrNull?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(isAdmin ? '全部历史订单' : '历史订单'),
        leading: IconButton(
          onPressed: () => context.go('/profile'),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
      ),
      body: ordersState.when(
        data: (orders) {
          final historyOrders = orders.where((order) {
            final userMatched =
                _selectedUserId == 'ALL' || order.user.id == _selectedUserId;
            return order.isFinished && userMatched;
          }).toList();
          final users = {
            for (final order in orders)
              if (order.user.id != null) order.user.id!: order.user.nickname
          };

          if (historyOrders.isEmpty) {
            return const _EmptyState(
              icon: Icons.receipt_long_outlined,
              title: '还没有历史订单',
              subtitle: '完成或取消后的订单会归档到这里。',
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(ordersListProvider.future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
              children: [
                _HeroSummary(
                  total: historyOrders.length,
                  completed:
                      historyOrders.where((order) => order.isCompleted).length,
                  cancelled:
                      historyOrders.where((order) => order.isCancelled).length,
                ),
                if (isAdmin && users.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedUserId,
                    decoration: const InputDecoration(labelText: '筛选顾客'),
                    items: [
                      const DropdownMenuItem(value: 'ALL', child: Text('全部顾客')),
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
                  historyOrders.length,
                  (index) => _HistoryOrderCard(
                    order: historyOrders[index],
                    index: index,
                    isAdmin: isAdmin,
                    onDelete: () async {
                      await ref
                          .read(ordersRepositoryProvider)
                          .deleteOrder(historyOrders[index].id);
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
              '历史订单加载失败：$error',
              style: const TextStyle(color: BarColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroSummary extends StatelessWidget {
  const _HeroSummary({
    required this.total,
    required this.completed,
    required this.cancelled,
  });

  final int total;
  final int completed;
  final int cancelled;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 18,
      child: Row(
        children: [
          _Metric(label: '归档', value: '$total', color: BarColors.neonPink),
          const SizedBox(width: 10),
          _Metric(label: '完成', value: '$completed', color: BarColors.neonGreen),
          const SizedBox(width: 10),
          _Metric(label: '取消', value: '$cancelled', color: BarColors.error),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: BarColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryOrderCard extends StatelessWidget {
  const _HistoryOrderCard({
    required this.order,
    required this.index,
    required this.isAdmin,
    required this.onDelete,
  });

  final Order order;
  final int index;
  final bool isAdmin;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final statusColor =
        order.isCompleted ? BarColors.neonGreen : BarColors.error;
    final primaryDrinkId =
        order.items.isEmpty ? null : order.items.first.drinkId;

    final card = Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: RepaintBoundary(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: primaryDrinkId == null
              ? null
              : () => context.push('/drinks/$primaryDrinkId'),
          child: GlassCard(
            borderRadius: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isAdmin
                            ? '${order.user.nickname} · ${order.callNumber} 号订单'
                            : '${order.callNumber} 号订单',
                        style: const TextStyle(
                          color: BarColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        order.statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...order.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => context.push('/drinks/${item.drinkId}'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            const Icon(Icons.local_bar,
                                size: 16, color: BarColors.neonPink),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${item.drink.name} x${item.quantity}',
                                style: const TextStyle(
                                  color: BarColors.textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Text(
                              item.review == null ? '未评价' : '已评价',
                              style: TextStyle(
                                color: item.review == null
                                    ? BarColors.textSecondary
                                    : BarColors.neonGreen,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (order.notes?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 4),
                  Text(
                    '备注：${order.notes}',
                    style: const TextStyle(
                      color: BarColors.textSecondary,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  DateFormat('yyyy-MM-dd HH:mm')
                      .format(order.createdAt.toLocal()),
                  style: const TextStyle(
                      color: BarColors.textSecondary, fontSize: 12),
                ),
                if (isAdmin) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline,
                          color: BarColors.error),
                      label: const Text('删除订单',
                          style: TextStyle(color: BarColors.error)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    if (index >= 4) {
      return card;
    }

    return card.animate().fadeIn(delay: (48 * index).ms).slideY(begin: 0.025);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GlassCard(
          borderRadius: 18,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 42, color: BarColors.neonGold),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: BarColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
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
