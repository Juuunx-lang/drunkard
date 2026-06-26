import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/colors.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/auth_controller.dart';

class AccountSecurityScreen extends ConsumerStatefulWidget {
  const AccountSecurityScreen({super.key});

  @override
  ConsumerState<AccountSecurityScreen> createState() =>
      _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends ConsumerState<AccountSecurityScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _wechatController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).valueOrNull;
    _wechatController.text =
        user?.hasWechatName == true ? user!.wechatName! : '';
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _wechatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('账号安全'),
        leading: IconButton(
          onPressed: () => context.go('/profile'),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
              children: [
                GlassCard(
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
                        child: const Icon(
                          Icons.verified_user_outlined,
                          color: BarColors.neonBlue,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.phone ?? '未绑定手机号',
                              style: const TextStyle(
                                color: BarColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.isWechatBound
                                  ? '微信已绑定，绑定信息不可修改'
                                  : '可修改密码；微信授权登录后会自动绑定同一账号',
                              style: const TextStyle(
                                color: BarColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SettingsLikeCard(
                  icon: Icons.lock_reset_outlined,
                  title: '修改密码',
                  subtitle: '不填写则保持原密码不变',
                  color: BarColors.neonPink,
                  child: Column(
                    children: [
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: '新密码',
                          hintText: '至少 6 位',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: '确认新密码'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SettingsLikeCard(
                  icon: Icons.chat_bubble_outline,
                  title: user.isWechatBound ? '已绑定微信' : '微信信息',
                  subtitle: user.isWechatBound
                      ? '已通过微信授权绑定，不支持手动修改'
                      : '未通过微信授权绑定；可先记录微信号，后续微信登录会自动合并账号',
                  color: BarColors.neonGreen,
                  child: TextField(
                    controller: _wechatController,
                    enabled: !user.isWechatBound,
                    decoration: InputDecoration(
                      labelText: user.isWechatBound ? '微信昵称' : '微信号/昵称备注',
                      hintText: user.isWechatBound ? null : '可选，不等同于微信授权绑定',
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _submitting ? null : () => _save(user.nickname),
                  child: Text(_submitting ? '保存中...' : '保存账号设置'),
                ),
              ],
            ),
    );
  }

  Future<void> _save(String nickname) async {
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    if (password.isNotEmpty && password.length < 6) {
      _toast('新密码至少 6 位');
      return;
    }
    if (password.isNotEmpty && password != confirmPassword) {
      _toast('两次密码不一致');
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(authControllerProvider.notifier).updateAccount(
            nickname: nickname,
            password: password.isEmpty ? null : password,
            confirmPassword: confirmPassword.isEmpty ? null : confirmPassword,
            wechatName: _wechatController.text.trim().isEmpty
                ? null
                : _wechatController.text.trim(),
          );
      if (mounted) {
        _toast('账号设置已保存');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _toast(String message) {
    showAppToast(context, message);
  }
}

class _SettingsLikeCard extends StatelessWidget {
  const _SettingsLikeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: BarColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
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
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
