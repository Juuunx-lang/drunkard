import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/colors.dart';
import '../data/auth_controller.dart';

class AuthCallbackScreen extends ConsumerStatefulWidget {
  const AuthCallbackScreen({super.key, required this.token});

  final String? token;

  @override
  ConsumerState<AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends ConsumerState<AuthCallbackScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_complete);
  }

  Future<void> _complete() async {
    final token = widget.token;
    if (token == null || token.trim().isEmpty) {
      setState(() => _error = '微信登录缺少凭证，请重新登录');
      return;
    }

    try {
      await ref
          .read(authControllerProvider.notifier)
          .completeWechatCallback(token);
      if (!mounted) return;
      final user = ref.read(authControllerProvider).valueOrNull;
      context.go(user?.phone == null ? '/bind-phone' : '/');
    } catch (error) {
      if (mounted) {
        setState(() => _error = '微信登录失败：$error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _error == null
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      '正在完成微信登录...',
                      style: TextStyle(color: BarColors.textSecondary),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: BarColors.error, size: 42),
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      style: const TextStyle(color: BarColors.textPrimary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('重新登录'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
