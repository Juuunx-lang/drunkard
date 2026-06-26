import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/colors.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../auth/data/auth_controller.dart';
import '../../reviews/presentation/review_card.dart';
import '../../reviews/presentation/review_composer_sheet.dart';
import '../data/order_actions_controller.dart';
import '../data/order_model.dart';
import '../data/orders_repository.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  final Set<String> _knownCompletedOrderIds = {};
  DateTime? _readyBannerExpiresAt;
  Timer? _readyBannerTimer;
  int _readyBannerCount = 0;
  bool _completedBaselineReady = false;

  @override
  void dispose() {
    _readyBannerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(orderActionsControllerProvider, (previous, next) {
      if (!context.mounted) {
        return;
      }

      if (next.hasError) {
        showAppToast(context, '订单操作失败：${next.error}');
      }
    });

    final ordersState = ref.watch(ordersListProvider);
    final actionState = ref.watch(orderActionsControllerProvider);
    final currentUser = ref.watch(authControllerProvider).valueOrNull;
    final isAdmin = currentUser?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(isAdmin ? '订单管理' : '我的订单'),
        actions: [
          if (!isAdmin)
            TextButton(
              onPressed: () => context.go('/'),
              child: const Text('再点一杯'),
            ),
        ],
      ),
      body: ordersState.when(
        data: (orders) {
          final activeOrders =
              orders.where((order) => !order.isFinished).toList();
          final historyOrders =
              orders.where((order) => order.isFinished).toList();
          final readyBannerCount = _syncCompletedBanner(orders);

          if (activeOrders.isEmpty && historyOrders.isEmpty) {
            return const Center(
              child: Text(
                '还没有订单，去点一杯吧',
                style: TextStyle(color: BarColors.textSecondary),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(ordersListProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (isAdmin) ...[
                  _SummaryBanner(
                    pendingCount: activeOrders
                        .where((order) => order.status == 'PENDING')
                        .length,
                    preparingCount: activeOrders
                        .where((order) => order.status == 'PREPARING')
                        .length,
                    historyCount: historyOrders.length,
                  ),
                  const SizedBox(height: 16),
                ],
                if (!isAdmin && readyBannerCount > 0) ...[
                  _ReadyBanner(count: readyBannerCount),
                  const SizedBox(height: 16),
                ],
                _SectionTitle(
                  title: isAdmin ? '当前订单' : '进行中的订单',
                  subtitle: isAdmin
                      ? '只保留 接单 → 制作中 → 完成 三个关键阶段'
                      : '已接单后会直接进入制作中，完成后会自动进入历史订单',
                ),
                const SizedBox(height: 12),
                if (activeOrders.isEmpty)
                  const _EmptyOrderBlock(message: '当前没有进行中的订单')
                else
                  ...List.generate(
                    activeOrders.length,
                    (index) => _OrderCard(
                      order: activeOrders[index],
                      index: index,
                      actionBusy: actionState.isLoading,
                      isAdmin: isAdmin,
                      onCancel: !isAdmin && activeOrders[index].canCancel
                          ? () =>
                              _confirmCancel(context, ref, activeOrders[index])
                          : null,
                      onAdvance:
                          isAdmin && activeOrders[index].nextStatus != null
                              ? () => ref
                                  .read(orderActionsControllerProvider.notifier)
                                  .updateOrderStatus(
                                    orderId: activeOrders[index].id,
                                    status: activeOrders[index].nextStatus!,
                                  )
                              : null,
                      onReject: isAdmin && activeOrders[index].canCancel
                          ? () => ref
                              .read(orderActionsControllerProvider.notifier)
                              .updateOrderStatus(
                                orderId: activeOrders[index].id,
                                status: 'CANCELLED',
                              )
                          : null,
                    ),
                  ),
                if (historyOrders.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _SectionTitle(
                    title: isAdmin ? '历史订单' : '历史订单',
                    subtitle:
                        isAdmin ? '已完成和已取消订单统一归档' : '已完成订单保留在这里，可继续补评论和回看记录',
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(
                    historyOrders.length,
                    (index) => _OrderCard(
                      order: historyOrders[index],
                      index: activeOrders.length + index,
                      actionBusy: actionState.isLoading,
                      isAdmin: isAdmin,
                      onReview: !isAdmin && historyOrders[index].isCompleted
                          ? (item) => _showReviewComposer(context, item)
                          : null,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '订单加载失败：$error',
              style: const TextStyle(color: BarColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  int _syncCompletedBanner(List<Order> orders) {
    final completedIds = orders
        .where((order) => order.isCompleted)
        .map((order) => order.id)
        .toSet();

    if (!_completedBaselineReady) {
      _knownCompletedOrderIds
        ..clear()
        ..addAll(completedIds);
      _completedBaselineReady = true;
      return 0;
    }

    final newlyCompleted = completedIds.difference(_knownCompletedOrderIds);
    _knownCompletedOrderIds
      ..clear()
      ..addAll(completedIds);

    if (newlyCompleted.isNotEmpty) {
      _readyBannerCount = newlyCompleted.length;
      _readyBannerExpiresAt = DateTime.now().add(const Duration(minutes: 5));
      _scheduleReadyBannerDismiss();
    }

    final expiresAt = _readyBannerExpiresAt;
    if (expiresAt == null || DateTime.now().isAfter(expiresAt)) {
      _readyBannerCount = 0;
      _readyBannerExpiresAt = null;
    }

    return _readyBannerCount;
  }

  void _scheduleReadyBannerDismiss() {
    _readyBannerTimer?.cancel();
    final expiresAt = _readyBannerExpiresAt;
    if (expiresAt == null) return;

    final delay = expiresAt.difference(DateTime.now());
    _readyBannerTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
      if (!mounted) return;
      setState(() {
        _readyBannerCount = 0;
        _readyBannerExpiresAt = null;
      });
    });
  }

  Future<void> _showReviewComposer(BuildContext context, OrderItem item) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: BarColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => ReviewComposerSheet(
        drinkId: item.drinkId,
        orderItemId: item.id,
        drinkName: item.drink.name,
      ),
    );
  }

  Future<void> _confirmCancel(
      BuildContext context, WidgetRef ref, Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BarColors.surface,
        title: const Text('取消这单吗？'),
        content: Text('确定取消 ${order.callNumber} 号订单？取消后需要重新下单。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('再想想'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认取消'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(orderActionsControllerProvider.notifier)
        .cancelOrder(order.id);
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.index,
    required this.actionBusy,
    required this.isAdmin,
    this.onCancel,
    this.onAdvance,
    this.onReject,
    this.onReview,
  });

  final Order order;
  final int index;
  final bool actionBusy;
  final bool isAdmin;
  final VoidCallback? onCancel;
  final VoidCallback? onAdvance;
  final VoidCallback? onReject;
  final void Function(OrderItem item)? onReview;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(order.status);
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${order.callNumber} 号订单',
                            style: const TextStyle(
                              color: BarColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isAdmin)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '下单用户：${order.user.nickname}',
                                style: const TextStyle(
                                  color: BarColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: statusColor.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        order.statusText,
                        style: TextStyle(color: statusColor, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...order.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => context.push('/drinks/${item.drinkId}'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.local_bar,
                                  size: 16,
                                  color: BarColors.neonPink,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${item.drink.name} x${item.quantity}',
                                    style: const TextStyle(
                                      color: BarColors.textPrimary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                if (!isAdmin && order.isCompleted)
                                  item.review == null
                                      ? OutlinedButton(
                                          onPressed:
                                              actionBusy || onReview == null
                                                  ? null
                                                  : () => onReview!(item),
                                          child: const Text('去评价'),
                                        )
                                      : Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: BarColors.neonGreen
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: const Text(
                                            '已评价',
                                            style: TextStyle(
                                              color: BarColors.neonGreen,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                              ],
                            ),
                          ),
                        ),
                        if (item.notes?.isNotEmpty ?? false) ...[
                          const SizedBox(height: 6),
                          Text(
                            '单品备注：${item.notes}',
                            style: const TextStyle(
                              color: BarColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        if (!isAdmin && item.review != null) ...[
                          const SizedBox(height: 10),
                          ReviewCard(review: item.review!, compact: true),
                        ],
                      ],
                    ),
                  ),
                ),
                if (order.notes?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 2),
                  Text(
                    '订单备注：${order.notes}',
                    style: const TextStyle(
                        color: BarColors.textSecondary, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      DateFormat('yyyy-MM-dd HH:mm')
                          .format(order.createdAt.toLocal()),
                      style: const TextStyle(
                          color: BarColors.textSecondary, fontSize: 12),
                    ),
                    const Spacer(),
                    if (onReject != null)
                      TextButton(
                        onPressed: actionBusy ? null : onReject,
                        child: const Text(
                          '不接单',
                          style: TextStyle(color: BarColors.error),
                        ),
                      ),
                    if (onAdvance != null)
                      TextButton(
                        onPressed: actionBusy ? null : onAdvance,
                        child: Text(order.nextStatusLabel ?? '推进状态'),
                      ),
                    if (onCancel != null)
                      TextButton(
                        onPressed: actionBusy ? null : onCancel,
                        child: const Text('取消订单'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (index >= 4) {
      return card;
    }

    return card.animate().fadeIn(delay: (48 * index).ms).slideX(begin: 0.03);
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'PENDING':
        return BarColors.neonGold;
      case 'PREPARING':
        return BarColors.neonBlue;
      case 'DELIVERED':
        return BarColors.neonGreen;
      case 'CANCELLED':
        return BarColors.error;
      default:
        return BarColors.textSecondary;
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: BarColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: BarColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner({
    required this.pendingCount,
    required this.preparingCount,
    required this.historyCount,
  });

  final int pendingCount;
  final int preparingCount;
  final int historyCount;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          _SummaryMetric(
              label: '待接单', value: '$pendingCount', color: BarColors.neonGold),
          const SizedBox(width: 12),
          _SummaryMetric(
              label: '制作中',
              value: '$preparingCount',
              color: BarColors.neonBlue),
          const SizedBox(width: 12),
          _SummaryMetric(
              label: '历史订单',
              value: '$historyCount',
              color: BarColors.textSecondary),
        ],
      ),
    );
  }
}

class _ReadyBanner extends StatelessWidget {
  const _ReadyBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 18,
      child: Row(
        children: [
          const Icon(Icons.notifications_active_outlined,
              color: BarColors.neonGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              count == 1 ? '你的酒好了，记得去取杯。' : '有 $count 单酒好了，记得去取杯。',
              style: const TextStyle(
                color: BarColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
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
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
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

class _EmptyOrderBlock extends StatelessWidget {
  const _EmptyOrderBlock({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          message,
          style: const TextStyle(color: BarColors.textSecondary),
        ),
      ),
    );
  }
}
