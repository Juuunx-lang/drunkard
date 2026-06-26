import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/colors.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../drinks/data/drinks_repository.dart';
import '../data/ingredient_model.dart';
import '../data/inventory_repository.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryState = ref.watch(inventoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('备货清单')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateIngredientSheet(context, ref),
        backgroundColor: BarColors.neonPink,
        child: const Icon(Icons.add),
      ),
      body: inventoryState.when(
        data: (groups) => RefreshIndicator(
          onRefresh: () async => ref.refresh(inventoryProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildCategory(
                context,
                ref,
                title: '基酒',
                icon: Icons.liquor,
                items: groups.baseSpirit,
              ),
              const SizedBox(height: 16),
              _buildCategory(
                context,
                ref,
                title: '糖浆',
                icon: Icons.water_drop,
                items: groups.syrup,
              ),
              const SizedBox(height: 16),
              _buildCategory(
                context,
                ref,
                title: '辅料',
                icon: Icons.eco,
                items: groups.mixer,
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '库存加载失败：$error',
              style: const TextStyle(color: BarColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategory(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required IconData icon,
    required List<Ingredient> items,
  }) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: BarColors.neonBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: BarColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Text(
              '暂无原料',
              style: TextStyle(color: BarColors.textSecondary),
            )
          else
            ...items.map(
              (item) => _buildIngredientRow(context, ref, item),
            ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.05);
  }

  Widget _buildIngredientRow(
    BuildContext context,
    WidgetRef ref,
    Ingredient item,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: item.inStock ? BarColors.neonGreen : BarColors.error,
              boxShadow: [
                BoxShadow(
                  color: (item.inStock ? BarColors.neonGreen : BarColors.error)
                      .withOpacity(0.5),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                      color: BarColors.textPrimary, fontSize: 14),
                ),
                if (item.notes?.isNotEmpty ?? false)
                  Text(
                    item.notes!,
                    style: const TextStyle(
                      color: BarColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          Switch(
            value: item.inStock,
            onChanged: (_) async {
              try {
                await ref
                    .read(inventoryRepositoryProvider)
                    .toggleStock(item.id);
                ref.invalidate(inventoryProvider);
                ref.invalidate(drinksListProvider);
                ref.invalidate(drinkDetailProvider);
              } catch (error) {
                if (context.mounted) {
                  showAppToast(context, '库存更新失败：$error');
                }
              }
            },
            activeColor: BarColors.neonGreen,
            inactiveThumbColor: BarColors.error,
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateIngredientSheet(
      BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final notesController = TextEditingController();
    String selectedCategory = 'BASE_SPIRIT';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: BarColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '新增原料',
                    style: TextStyle(
                      color: BarColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: '名称'),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'BASE_SPIRIT', label: Text('基酒')),
                      ButtonSegment(value: 'SYRUP', label: Text('糖浆')),
                      ButtonSegment(value: 'MIXER', label: Text('辅料')),
                    ],
                    selected: {selectedCategory},
                    onSelectionChanged: (selection) {
                      setState(() => selectedCategory = selection.first);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(labelText: '备注'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) {
                        return;
                      }

                      try {
                        await ref
                            .read(inventoryRepositoryProvider)
                            .createIngredient(
                              name: name,
                              category: selectedCategory,
                              notes: notesController.text,
                            );
                        ref.invalidate(inventoryProvider);
                        ref.invalidate(drinksListProvider);
                        ref.invalidate(drinkDetailProvider);
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                      } catch (error) {
                        if (sheetContext.mounted) {
                          showAppToast(sheetContext, '新增原料失败：$error');
                        }
                      }
                    },
                    child: const Text('保存'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    notesController.dispose();
  }
}
