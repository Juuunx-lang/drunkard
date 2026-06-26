import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/colors.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/auth_controller.dart';

class BindPhoneScreen extends ConsumerStatefulWidget {
  const BindPhoneScreen({super.key});

  @override
  ConsumerState<BindPhoneScreen> createState() => _BindPhoneScreenState();
}

class _BindPhoneScreenState extends ConsumerState<BindPhoneScreen> {
  final _phoneController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    final nickname = user?.nickname.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('绑定手机号'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _submitting
                ? null
                : () => ref.read(authControllerProvider.notifier).logout(),
            child: const Text('退出'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 112),
        children: [
          GlassCard(
            borderRadius: 22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.phone_iphone_rounded,
                  color: BarColors.neonGold,
                  size: 36,
                ),
                const SizedBox(height: 16),
                Text(
                  '为了避免一人多号，请绑定手机号',
                  style: const TextStyle(
                    color: BarColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  nickname == null || nickname.isEmpty
                      ? '微信快捷登录已完成。输入你之前注册过的手机号，系统会自动合并到同一个账号。'
                      : '$nickname，微信快捷登录已完成。输入你之前注册过的手机号，系统会自动合并到同一个账号。',
                  style: const TextStyle(
                    color: BarColors.textSecondary,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 11,
                  enabled: !_submitting,
                  decoration: const InputDecoration(
                    labelText: '手机号',
                    hintText: '请输入 11 位手机号',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: Text(_submitting ? '绑定中...' : '绑定并进入'),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '如果该手机号已注册，会把当前微信绑定到原账号；如果没有注册，会补齐到当前微信账号。',
                  style: TextStyle(
                    color: BarColors.textSecondary,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final phone = _phoneController.text.trim();
    if (!RegExp(r'^\d{11}$').hasMatch(phone)) {
      showAppToast(context, '手机号必须是 11 位数字');
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(authControllerProvider.notifier).bindPhone(phone);
      if (mounted) context.go('/');
    } catch (error) {
      if (mounted) showAppToast(context, '绑定失败：$error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
