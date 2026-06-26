import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../shared/widgets/app_toast.dart';

enum AccountLoginMode { login, register }

class AccountLoginSheet extends StatefulWidget {
  const AccountLoginSheet({
    super.key,
    required this.onLogin,
    required this.onRegister,
    this.initialMode = AccountLoginMode.login,
  });

  final Future<String?> Function(String phone, String password) onLogin;
  final Future<String?> Function(
    String phone,
    String nickname,
    String inviteCode,
    String password,
    String confirmPassword,
  ) onRegister;
  final AccountLoginMode initialMode;

  @override
  State<AccountLoginSheet> createState() => _AccountLoginSheetState();
}

class _AccountLoginSheetState extends State<AccountLoginSheet> {
  final _phoneController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _inviteController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  late bool _isRegister = widget.initialMode == AccountLoginMode.register;
  bool _submitting = false;
  String? _errorText;

  @override
  void dispose() {
    _phoneController.dispose();
    _nicknameController.dispose();
    _inviteController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: _isRegister ? 0.86 : 0.64,
      minChildSize: 0.32,
      maxChildSize: 0.92,
      builder: (context, scrollController) => SafeArea(
        child: SingleChildScrollView(
          controller: scrollController,
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 18,
            bottom: MediaQuery.of(context).viewInsets.bottom + 22,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _isRegister ? '手机号注册' : '账号密码登录',
                style: const TextStyle(
                  color: BarColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _isRegister
                    ? '邀请码正确后即可进入 Drunkard 私人酒馆。'
                    : '有账号就直接进入；第一次来请点下方“手机号注册”。',
                style: const TextStyle(
                  color: BarColors.textSecondary,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              if (_errorText != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: BarColors.error.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: BarColors.error.withOpacity(0.32)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: BarColors.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorText!,
                          style: const TextStyle(
                            color: BarColors.textPrimary,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 11,
                decoration: const InputDecoration(
                  labelText: '手机号',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              if (_isRegister) ...[
                TextField(
                  controller: _nicknameController,
                  maxLength: 16,
                  decoration: const InputDecoration(
                    labelText: '顾客名',
                    hintText: '例如 小王 / 老李 / 阿森',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _inviteController,
                  decoration: const InputDecoration(labelText: '邀请码'),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '密码'),
              ),
              if (_isRegister) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '确认密码'),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: Text(
                    _submitting ? '处理中...' : (_isRegister ? '注册并进入' : '进入应用')),
              ),
              TextButton(
                onPressed: _submitting
                    ? null
                    : () => setState(() {
                          _isRegister = !_isRegister;
                          _errorText = null;
                        }),
                child: Text(_isRegister ? '已有账号，去登录' : '没有账号，手机号注册'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    if (!RegExp(r'^\d{11}$').hasMatch(phone)) {
      _toast('手机号必须是 11 位数字');
      return;
    }
    if (password.isEmpty) {
      _toast('请输入密码');
      return;
    }
    if (_isRegister && password != _confirmController.text) {
      _toast('两次密码不一致');
      return;
    }
    if (_isRegister && _nicknameController.text.trim().isEmpty) {
      _toast('请填写顾客名');
      return;
    }
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    try {
      String? error;
      if (_isRegister) {
        error = await widget.onRegister(
          phone,
          _nicknameController.text.trim(),
          _inviteController.text.trim(),
          password,
          _confirmController.text,
        );
      } else {
        error = await widget.onLogin(phone, password);
      }
      if (error != null && mounted) {
        setState(() => _errorText = error);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _toast(String message) {
    showAppToast(context, message);
  }
}
