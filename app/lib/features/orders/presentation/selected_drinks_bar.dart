import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/colors.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../auth/data/auth_controller.dart';
import '../../bar/data/bar_status_repository.dart';
import '../data/cart_controller.dart';
import '../data/order_actions_controller.dart';
import '../data/orders_repository.dart';

class SelectedDrinksBar extends ConsumerWidget {
  const SelectedDrinksBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin =
        ref.watch(authControllerProvider).valueOrNull?.isAdmin ?? false;
    if (isAdmin) return const SizedBox.shrink();

    final cart = ref.watch(cartControllerProvider);
    final orderAction = ref.watch(orderActionsControllerProvider);
    final barStatus = ref.watch(barStatusProvider).valueOrNull;
    final isClosed = barStatus?.isClosed ?? false;
    if (cart.isEmpty) return const SizedBox.shrink();
    final totalCount =
        cart.values.fold<int>(0, (sum, item) => sum + item.quantity);

    return SafeArea(
      top: false,
      minimum: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.zero,
        child: Container(
          decoration: BoxDecoration(
            color: BarColors.surface.withOpacity(0.96),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.28),
                blurRadius: 24,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => _showSelectedSheet(context, ref),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: BarColors.neonGold.withOpacity(0.14),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.local_bar_rounded,
                        color: BarColors.neonGold,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '已选 $totalCount',
                      style: const TextStyle(
                        color: BarColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: orderAction.isLoading || isClosed
                    ? null
                    : () => _submit(context, ref),
                child: Text(isClosed
                    ? '未营业'
                    : orderAction.isLoading
                        ? '提交中'
                        : '确认'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSelectedSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: BarColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => Consumer(
        builder: (context, ref, _) {
          final cart = ref.watch(cartControllerProvider);
          final busy = ref.watch(orderActionsControllerProvider).isLoading;
          final isClosed =
              ref.watch(barStatusProvider).valueOrNull?.isClosed ?? false;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '已选',
                          style: TextStyle(
                            color: BarColors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (cart.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Center(
                        child: Text(
                          '还没有选酒',
                          style: TextStyle(color: BarColors.textSecondary),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: cart.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = cart.values.elementAt(index);
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.1)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.drink.name,
                                        style: const TextStyle(
                                          color: BarColors.textPrimary,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      if (item.notes?.trim().isNotEmpty ??
                                          false) ...[
                                        const SizedBox(height: 5),
                                        Text(
                                          item.notes!,
                                          style: const TextStyle(
                                            color: BarColors.neonGold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: busy
                                      ? null
                                      : () => ref
                                          .read(cartControllerProvider.notifier)
                                          .decrease(item.drink.id),
                                  icon: const Icon(Icons.remove_circle_outline),
                                  tooltip: '减少',
                                ),
                                Text(
                                  '${item.quantity}',
                                  style: const TextStyle(
                                    color: BarColors.textPrimary,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                IconButton(
                                  onPressed: busy
                                      ? null
                                      : () => ref
                                          .read(cartControllerProvider.notifier)
                                          .addDrink(item.drink,
                                              notes: item.notes),
                                  icon: const Icon(Icons.add_circle_outline),
                                  tooltip: '增加',
                                ),
                                IconButton(
                                  onPressed: busy
                                      ? null
                                      : () => ref
                                          .read(cartControllerProvider.notifier)
                                          .remove(item.drink.id),
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: '移除',
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      TextButton(
                        onPressed: busy
                            ? null
                            : () {
                                ref
                                    .read(cartControllerProvider.notifier)
                                    .clear();
                                Navigator.of(sheetContext).pop();
                              },
                        child: const Text('清空'),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: cart.isEmpty || busy || isClosed
                            ? null
                            : () async {
                                Navigator.of(sheetContext).pop();
                                await _submit(context, ref);
                              },
                        icon: const Icon(Icons.check_rounded),
                        label: Text(isClosed
                            ? '未营业'
                            : busy
                                ? '提交中...'
                                : '确认下单'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    final cart = ref.read(cartControllerProvider);
    if (cart.isEmpty) return;
    final barStatus = await ref.read(barStatusProvider.future);
    if (barStatus.isClosed) {
      if (context.mounted) {
        showAppToast(context, '吧台未营业，暂时不能点单');
      }
      return;
    }

    final items = cart.values
        .map((item) => OrderCreateItem(
              drinkId: item.drink.id,
              quantity: item.quantity,
              notes: item.notes,
            ))
        .toList();

    await ref.read(orderActionsControllerProvider.notifier).createOrder(
          items: items,
        );

    final state = ref.read(orderActionsControllerProvider);
    if (!context.mounted) return;
    if (state.hasError) {
      showAppToast(context, '下单失败：${state.error}');
      return;
    }

    ref.read(cartControllerProvider.notifier).clear();
    showAppToast(context, '下单成功，已加入订单列表');
    context.go('/orders');
  }
}
