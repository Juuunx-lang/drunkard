import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../data/auth_controller.dart';
import '../../../core/theme/colors.dart';
import '../../../shared/widgets/neon_text.dart';
import 'account_login_sheet.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(authControllerProvider, (previous, next) {
      if (next.valueOrNull != null && context.mounted) {
        context.go('/');
      }
    });

    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D0D0D), Color(0xFF1A1A2E)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.local_bar,
                  size: 80,
                  color: BarColors.neonPink,
                ).animate().fadeIn(duration: 360.ms).scale(
                      begin: const Offset(0.96, 0.96),
                      end: const Offset(1, 1),
                    ),
                const SizedBox(height: 24),
                const NeonText(
                  text: 'Drunkard',
                  fontSize: 36,
                  color: BarColors.neonPink,
                ).animate().fadeIn(delay: 120.ms, duration: 360.ms),
                const SizedBox(height: 8),
                const Text(
                  '酒鬼聚集地',
                  style: TextStyle(
                    color: BarColors.textSecondary,
                    fontSize: 16,
                    letterSpacing: 4,
                  ),
                ).animate().fadeIn(delay: 180.ms, duration: 320.ms),
                const SizedBox(height: 78),
                _AuthActionButtons(isLoading: authState.isLoading),
                const SizedBox(height: 14),
                const Text(
                  '第一次来？快点击手机号注册吧',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: BarColors.textSecondary,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthActionButtons extends ConsumerWidget {
  const _AuthActionButtons({required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LoginButton(
            title: '账号登录',
            subtitle: '老酒鬼直接进场',
            icon: _LoginActionIcon.signIn,
            isPrimary: true,
            onTap: isLoading
                ? null
                : () => _showAccountSheet(
                      context,
                      ref,
                      AccountLoginMode.login,
                    ),
          ),
          const SizedBox(height: 12),
          _LoginButton(
            title: '手机号注册',
            subtitle: '第一次来先拿入场券',
            icon: _LoginActionIcon.signUp,
            isPrimary: false,
            onTap: isLoading
                ? null
                : () => _showAccountSheet(
                      context,
                      ref,
                      AccountLoginMode.register,
                    ),
          ),
        ],
      ),
    );
  }

  void _showAccountSheet(
    BuildContext context,
    WidgetRef ref,
    AccountLoginMode initialMode,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: BarColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => AccountLoginSheet(
        initialMode: initialMode,
        onLogin: (phone, password) async {
          try {
            await ref
                .read(authControllerProvider.notifier)
                .login(phone: phone, password: password);
          } catch (error) {
            return _friendlyAuthError(error);
          }
          if (sheetContext.mounted) {
            Navigator.of(sheetContext).pop();
          }
          if (context.mounted &&
              ref.read(authControllerProvider).valueOrNull != null) {
            context.go('/');
          }
          return null;
        },
        onRegister:
            (phone, nickname, inviteCode, password, confirmPassword) async {
          try {
            await ref.read(authControllerProvider.notifier).register(
                  phone: phone,
                  nickname: nickname,
                  inviteCode: inviteCode,
                  password: password,
                  confirmPassword: confirmPassword,
                );
          } catch (error) {
            return _friendlyAuthError(error);
          }
          if (sheetContext.mounted) {
            Navigator.of(sheetContext).pop();
          }
          if (context.mounted &&
              ref.read(authControllerProvider).valueOrNull != null) {
            context.go('/');
          }
          return null;
        },
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isPrimary,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final _LoginActionIcon icon;
  final bool isPrimary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = isPrimary
        ? [BarColors.neonPink, BarColors.neonGold]
        : [
            BarColors.neonBlue.withValues(alpha: 0.82),
            BarColors.neonPink.withValues(alpha: 0.62),
          ];
    final radius = BorderRadius.circular(isPrimary ? 30 : 24);
    const horizontalPadding = 26.0;
    const iconSize = 42.0;
    const contentGap = 18.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: isPrimary ? 17 : 13,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: radius,
        ),
        child: Row(
          children: [
            Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: CustomPaint(
                painter: _LoginActionIconPainter(icon),
              ),
            ),
            const SizedBox(width: contentGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isPrimary ? 20 : 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: isPrimary ? 1.2 : 0.6,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: isPrimary ? 12 : 11,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '→',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.86),
                fontSize: 24,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _LoginActionIcon { signIn, signUp }

class _LoginActionIconPainter extends CustomPainter {
  const _LoginActionIconPainter(this.icon);

  final _LoginActionIcon icon;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (icon) {
      case _LoginActionIcon.signIn:
        _paintSignIn(canvas, size, paint);
      case _LoginActionIcon.signUp:
        _paintSignUp(canvas, size, paint);
    }
  }

  void _paintSignIn(Canvas canvas, Size size, Paint paint) {
    final width = size.width;
    final height = size.height;
    canvas.drawLine(
      Offset(width * 0.28, height * 0.5),
      Offset(width * 0.62, height * 0.5),
      paint,
    );
    canvas.drawLine(
      Offset(width * 0.5, height * 0.34),
      Offset(width * 0.66, height * 0.5),
      paint,
    );
    canvas.drawLine(
      Offset(width * 0.5, height * 0.66),
      Offset(width * 0.66, height * 0.5),
      paint,
    );
    canvas.drawLine(
      Offset(width * 0.68, height * 0.26),
      Offset(width * 0.68, height * 0.74),
      paint,
    );
  }

  void _paintSignUp(Canvas canvas, Size size, Paint paint) {
    final width = size.width;
    final height = size.height;
    canvas.drawCircle(Offset(width * 0.36, height * 0.38), width * 0.1, paint);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(width * 0.36, height * 0.72),
        width: width * 0.42,
        height: height * 0.25,
      ),
      3.28,
      2.92,
      false,
      paint,
    );
    canvas.drawLine(
      Offset(width * 0.66, height * 0.34),
      Offset(width * 0.66, height * 0.6),
      paint,
    );
    canvas.drawLine(
      Offset(width * 0.53, height * 0.47),
      Offset(width * 0.79, height * 0.47),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _LoginActionIconPainter oldDelegate) {
    return oldDelegate.icon != icon;
  }
}

String _friendlyAuthError(Object? error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['error'] != null) {
      return data['error'].toString();
    }
    if (error.response?.statusCode == 401) {
      return '手机号或密码错误，请重新输入。';
    }
  }
  return error?.toString() ?? '登录失败，请稍后再试。';
}
