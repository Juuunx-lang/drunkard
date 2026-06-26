import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/colors.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/admin_database_repository.dart';

class AdminDatabaseScreen extends ConsumerStatefulWidget {
  const AdminDatabaseScreen({super.key});

  @override
  ConsumerState<AdminDatabaseScreen> createState() =>
      _AdminDatabaseScreenState();
}

class _AdminDatabaseScreenState extends ConsumerState<AdminDatabaseScreen> {
  String? _selectedTable;

  @override
  Widget build(BuildContext context) {
    final tablesState = ref.watch(adminDatabaseTablesProvider);
    final selectedTable = _selectedTable;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
        title: const Text('数据库管理'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: () {
              ref.invalidate(adminDatabaseTablesProvider);
              if (selectedTable != null) {
                ref.invalidate(adminDatabaseTableProvider(selectedTable));
              }
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: tablesState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _StateView(
          icon: Icons.warning_amber_rounded,
          title: '数据库入口加载失败',
          message: '$error',
          actionLabel: '重试',
          onAction: () => ref.invalidate(adminDatabaseTablesProvider),
        ),
        data: (tables) {
          final activeTable =
              selectedTable ?? (tables.isEmpty ? null : tables.first.key);
          if (_selectedTable == null && activeTable != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _selectedTable = activeTable);
            });
          }

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                sliver: SliverToBoxAdapter(
                  child: _HeaderCard(tables: tables),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 118,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      final table = tables[index];
                      final isSelected = table.key == activeTable;
                      return _TablePill(
                        table: table,
                        isSelected: isSelected,
                        onTap: () => setState(() => _selectedTable = table.key),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemCount: tables.length,
                  ),
                ),
              ),
              if (activeTable == null)
                const SliverFillRemaining(
                  child: _StateView(
                    icon: Icons.dataset_outlined,
                    title: '暂无可管理数据表',
                    message: '后端暂未返回管理员可视化数据表。',
                  ),
                )
              else
                _TableRecordsSliver(table: activeTable),
            ],
          );
        },
      ),
    );
  }
}

class _TableRecordsSliver extends ConsumerWidget {
  const _TableRecordsSliver({required this.table});

  final String table;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tableState = ref.watch(adminDatabaseTableProvider(table));

    return tableState.when(
      loading: () => const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => SliverFillRemaining(
        child: _StateView(
          icon: Icons.cloud_off_outlined,
          title: '记录加载失败',
          message: '$error',
          actionLabel: '重试',
          onAction: () => ref.invalidate(adminDatabaseTableProvider(table)),
        ),
      ),
      data: (data) => SliverPadding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 120),
        sliver: SliverList.list(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    data.table.label,
                    style: const TextStyle(
                      color: BarColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _showRecordEditor(context, ref, data),
                  icon: const Icon(Icons.add),
                  label: const Text('新增'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              data.table.description,
              style:
                  const TextStyle(color: BarColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 14),
            if (data.records.isEmpty)
              _EmptyRecordsCard(
                  onCreate: () => _showRecordEditor(context, ref, data))
            else
              ...data.records.map(
                (record) => _RecordCard(
                  data: data,
                  record: record,
                  onEdit: () =>
                      _showRecordEditor(context, ref, data, record: record),
                  onDelete: () => _confirmDelete(context, ref, data, record),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRecordEditor(
    BuildContext context,
    WidgetRef ref,
    AdminDatabaseTableData data, {
    AdminDatabaseRecord? record,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: BarColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) => _RecordEditorSheet(data: data, record: record),
    );
    ref.invalidate(adminDatabaseTablesProvider);
    ref.invalidate(adminDatabaseTableProvider(data.table.key));
    if (saved == true && context.mounted) {
      showAppToast(context, '已保存数据库记录');
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AdminDatabaseTableData data,
    AdminDatabaseRecord record,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BarColors.surface,
        title: Text('删除${data.table.label}记录？'),
        content: Text(
          '将删除「${record.summary}」。这个动作会直接写入数据库，删除后无法在界面内撤销。',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref
          .read(adminDatabaseRepositoryProvider)
          .deleteRecord(data.table.key, record.id);
      ref.invalidate(adminDatabaseTablesProvider);
      ref.invalidate(adminDatabaseTableProvider(data.table.key));
      if (context.mounted) {
        showAppToast(context, '已删除记录');
      }
    } catch (error) {
      if (context.mounted) {
        showAppToast(context, '删除失败：$error');
      }
    }
  }
}

class _RecordEditorSheet extends ConsumerStatefulWidget {
  const _RecordEditorSheet({
    required this.data,
    this.record,
  });

  final AdminDatabaseTableData data;
  final AdminDatabaseRecord? record;

  @override
  ConsumerState<_RecordEditorSheet> createState() => _RecordEditorSheetState();
}

class _RecordEditorSheetState extends ConsumerState<_RecordEditorSheet> {
  late final Map<String, TextEditingController> _controllers;
  late final Map<String, dynamic> _values;
  bool _submitting = false;

  bool get _isEditing => widget.record != null;

  @override
  void initState() {
    super.initState();
    final recordValues = widget.record?.values ?? {};
    _controllers = {};
    _values = {};
    for (final field in widget.data.fields) {
      final initial = recordValues[field.key];
      if (field.type == 'boolean') {
        _values[field.key] = initial == true;
      } else if (field.type == 'select') {
        _values[field.key] = initial?.toString() ??
            (field.options.isNotEmpty ? field.options.first.value : '');
      } else if (field.type == 'multiselect') {
        _values[field.key] = (initial is List)
            ? initial.map((item) => item.toString()).toSet()
            : <String>{};
      } else {
        _controllers[field.key] = TextEditingController(
          text: field.type == 'password' ? '' : (initial?.toString() ?? ''),
        );
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final writableFields = widget.data.fields.where((field) {
      return _isEditing ? field.editable : field.creatable;
    }).toList();

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 14,
          bottom: MediaQuery.of(context).viewInsets.bottom + 22,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _isEditing
                  ? '编辑${widget.data.table.label}'
                  : '新增${widget.data.table.label}',
              style: const TextStyle(
                color: BarColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '表单仅展示管理员可读字段，保存后会立即写入数据库。',
              style: TextStyle(color: BarColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ...writableFields.map(_buildField),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: Icon(_isEditing ? Icons.save_outlined : Icons.add),
              label:
                  Text(_submitting ? '保存中...' : (_isEditing ? '保存修改' : '创建记录')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(AdminDatabaseField field) {
    if (field.type == 'boolean') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SwitchListTile(
          value: _values[field.key] == true,
          onChanged: (value) => setState(() => _values[field.key] = value),
          title: Text(field.label),
          subtitle: Text(field.required ? '必填' : '可选'),
          activeColor: BarColors.neonGold,
        ),
      );
    }

    if (field.type == 'select') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<String>(
          value: _values[field.key]?.toString(),
          items: field.options
              .map(
                (option) => DropdownMenuItem(
                  value: option.value,
                  child: Text(option.label, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (value) =>
              setState(() => _values[field.key] = value ?? ''),
          decoration: InputDecoration(
            labelText: field.required ? '${field.label} *' : field.label,
          ),
        ),
      );
    }

    if (field.type == 'multiselect') {
      final selected = (_values[field.key] as Set<String>?) ?? <String>{};
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                field.required ? '${field.label} *' : field.label,
                style: const TextStyle(
                  color: BarColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              if (field.options.isEmpty)
                const Text(
                  '暂无可选项',
                  style: TextStyle(color: BarColors.textSecondary),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: field.options.map((option) {
                    final checked = selected.contains(option.value);
                    return FilterChip(
                      selected: checked,
                      label: Text(option.label),
                      onSelected: (value) {
                        setState(() {
                          final next = {...selected};
                          if (value) {
                            next.add(option.value);
                          } else {
                            next.remove(option.value);
                          }
                          _values[field.key] = next;
                        });
                      },
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      );
    }

    final controller = _controllers[field.key]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: field.type == 'password',
        keyboardType: field.type == 'number'
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        maxLines: field.type == 'textarea' ? 4 : 1,
        decoration: InputDecoration(
          labelText: field.required ? '${field.label} *' : field.label,
          hintText: field.type == 'password' && _isEditing ? '留空表示不修改密码' : null,
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final payload = <String, dynamic>{};
    for (final field in widget.data.fields) {
      final writable = _isEditing ? field.editable : field.creatable;
      if (!writable) continue;

      if (field.type == 'boolean' || field.type == 'select') {
        payload[field.key] = _values[field.key];
      } else if (field.type == 'multiselect') {
        payload[field.key] =
            ((_values[field.key] as Set<String>?) ?? <String>{}).toList();
      } else {
        payload[field.key] = _controllers[field.key]?.text.trim();
      }
    }

    final password = payload['password']?.toString() ?? '';
    if (password.isNotEmpty && password.length < 6) {
      showAppToast(context, '密码至少 6 位；留空表示不修改密码');
      return;
    }

    setState(() => _submitting = true);
    try {
      final repository = ref.read(adminDatabaseRepositoryProvider);
      if (_isEditing) {
        await repository.updateRecord(
          widget.data.table.key,
          widget.record!.id,
          payload,
        );
      } else {
        await repository.createRecord(widget.data.table.key, payload);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        showAppToast(context, '保存失败：$error');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.data,
    required this.record,
    required this.onEdit,
    required this.onDelete,
  });

  final AdminDatabaseTableData data;
  final AdminDatabaseRecord record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        borderRadius: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.summary.isEmpty ? '未命名记录' : record.summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: BarColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        record.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: BarColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '编辑',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: '删除',
                  onPressed: onDelete,
                  color: BarColors.error,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: data.fields.take(6).map((field) {
                final value = record.values[field.key];
                return _ValueChip(
                  label: field.label,
                  value: _readableValue(field, value),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValueChip extends StatelessWidget {
  const _ValueChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 230),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Text(
        '$label：$value',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: BarColors.textSecondary, fontSize: 12),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.tables});

  final List<AdminDatabaseTable> tables;

  @override
  Widget build(BuildContext context) {
    final total = tables.fold<int>(0, (sum, table) => sum + table.count);
    return GlassCard(
      borderRadius: 22,
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  BarColors.neonBlue.withOpacity(0.9),
                  BarColors.neonPink.withOpacity(0.9),
                ],
              ),
            ),
            child: const Icon(Icons.dataset_outlined, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '管理员数据工作台',
                  style: TextStyle(
                    color: BarColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '选择业务表后进行新增、修改和删除；共 ${tables.length} 张表，$total 条记录。',
                  style: const TextStyle(
                      color: BarColors.textSecondary, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TablePill extends StatelessWidget {
  const _TablePill({
    required this.table,
    required this.isSelected,
    required this.onTap,
  });

  final AdminDatabaseTable table;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 160,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    BarColors.neonBlue.withOpacity(0.24),
                    BarColors.neonPink.withOpacity(0.16),
                  ],
                )
              : null,
          color: isSelected ? null : Colors.white.withOpacity(0.045),
          border: Border.all(
            color: isSelected
                ? BarColors.neonBlue.withOpacity(0.5)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              table.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: BarColors.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            Text(
              '${table.count} 条记录',
              style: TextStyle(
                color:
                    isSelected ? BarColors.neonBlue : BarColors.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRecordsCard extends StatelessWidget {
  const _EmptyRecordsCard({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 18,
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined,
              size: 42, color: BarColors.textSecondary),
          const SizedBox(height: 10),
          const Text('这张表还没有记录', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('创建第一条'),
          ),
        ],
      ),
    );
  }
}

class _StateView extends StatelessWidget {
  const _StateView({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: BarColors.textSecondary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: BarColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: BarColors.textSecondary, height: 1.45),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

String _readableValue(AdminDatabaseField field, dynamic value) {
  if (field.type == 'password') {
    return value == null || value.toString().trim().isEmpty ? '未设置' : '已加密保存';
  }
  if (value == null || value.toString().trim().isEmpty) return '未填写';
  if (field.type == 'boolean') return value == true ? '是' : '否';
  if (field.type == 'select') {
    for (final option in field.options) {
      if (option.value == value.toString()) return option.label;
    }
    return value.toString();
  }
  return value.toString();
}
