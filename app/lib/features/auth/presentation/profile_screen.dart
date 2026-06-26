import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/colors.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../bar/data/bar_status_repository.dart';
import '../../community/data/community_repository.dart';
import '../../reviews/data/reviews_repository.dart';
import '../data/auth_controller.dart';
import '../data/profile_customization_controller.dart';
import '../data/public_profile_repository.dart';
import '../data/user_model.dart';

const _maxProfileImageDataUrlLength = 420000;
const _maxStoredProfileImageDataUrlLength = 900000;

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final Set<String> _syncedLocalProfileUserIds = {};

  Future<void> _syncLocalProfileIfNeeded(
    User user,
    ProfileCustomization customization,
  ) async {
    if (_syncedLocalProfileUserIds.contains(user.id)) return;
    _syncedLocalProfileUserIds.add(user.id);

    final avatarDataUrl = customization.avatarDataUrl;
    final backgroundDataUrl = customization.backgroundDataUrl;
    final signature = customization.signature?.trim();
    final hasLocalAvatar = avatarDataUrl != null &&
        avatarDataUrl.isNotEmpty &&
        (user.avatarUrl == null || user.avatarUrl!.isEmpty) &&
        avatarDataUrl != user.avatarUrl;
    final hasLocalBackground = backgroundDataUrl != null &&
        backgroundDataUrl.isNotEmpty &&
        (user.backgroundUrl == null || user.backgroundUrl!.isEmpty) &&
        backgroundDataUrl != user.backgroundUrl;
    final hasLocalSignature = signature != null &&
        signature.isNotEmpty &&
        (user.signature == null || user.signature!.isEmpty) &&
        signature != user.signature;

    if (!hasLocalAvatar && !hasLocalBackground && !hasLocalSignature) return;

    try {
      await ref.read(authControllerProvider.notifier).updateLocalProfile(
            nickname: user.nickname,
            avatarUrl: hasLocalAvatar ? avatarDataUrl : null,
            backgroundUrl: hasLocalBackground ? backgroundDataUrl : null,
            signature: hasLocalSignature ? signature : null,
          );
      ref.invalidate(publicProfileProvider(user.id));
      ref.invalidate(communityPostsProvider);
      ref.invalidate(drinkReviewsProvider);
    } catch (_) {
      _syncedLocalProfileUserIds.remove(user.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).valueOrNull;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final customizationState = ref.watch(profileCustomizationProvider(user.id));
    final savedCustomization =
        customizationState.valueOrNull ?? const ProfileCustomization();
    final customization = ProfileCustomization(
      avatarDataUrl: user.avatarUrl ?? savedCustomization.avatarDataUrl,
      backgroundDataUrl:
          user.backgroundUrl ?? savedCustomization.backgroundDataUrl,
      signature: user.signature ?? savedCustomization.signature,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncLocalProfileIfNeeded(user, customization);
      }
    });
    final helpSubtitle = _helpSubtitleFor(user);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            stretch: true,
            expandedHeight: 220,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            title: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: BarColors.background.withOpacity(0.42),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: const Text('我的'),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: IconButton.filledTonal(
                  onPressed: () => _showSettingsSheet(context, ref, user),
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: '设置',
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
                StretchMode.fadeTitle,
              ],
              background: _ProfileBackdrop(
                user: user,
                customization: customization,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 112),
            sliver: SliverList.list(
              children: [
                _MemberCard(
                  user: user,
                  customization: customization,
                  onEdit: () => _showProfileEditorSheet(
                    context,
                    ref,
                    user,
                    customization,
                  ),
                ),
                const SizedBox(height: 18),
                _ProfileSection(
                  title: '我的酒馆轨迹',
                  subtitle: '历史订单、评价、喜欢都收在这里',
                  children: [
                    _FeatureTile(
                      icon: Icons.receipt_long_outlined,
                      title: '历史订单',
                      subtitle: '进入独立归档卡片，回看已完成与已取消订单',
                      color: BarColors.neonPink,
                      onTap: () => context.push('/profile/history-orders'),
                    ),
                    _FeatureTile(
                      icon: Icons.rate_review_outlined,
                      title: '我的评论',
                      subtitle: '进入独立评价卡片，查看自己发过的文字、表情和图片',
                      color: BarColors.neonBlue,
                      onTap: () => context.push('/profile/reviews'),
                    ),
                    _FeatureTile(
                      icon: Icons.favorite_border,
                      title: '我的喜欢',
                      subtitle: '查看点亮爱心的酒，快速回到详情页',
                      color: BarColors.neonGold,
                      onTap: () => context.push('/profile/favorites'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _ProfileSection(
                  title: '功能中心',
                  subtitle: user.isAdmin
                      ? '今晚的吧台控制台，状态、数据和说明都在这里'
                      : '按你的节奏继续探索，点酒、说明和个人入口都在这里',
                  children: [
                    _FeatureTile(
                      icon: Icons.help_outline,
                      title: '新手说明',
                      subtitle: helpSubtitle,
                      color: BarColors.neonGreen,
                      onTap: () => context.push('/profile/help'),
                    ),
                    if (user.isAdmin)
                      _FeatureTile(
                        icon: Icons.inventory_2_outlined,
                        title: '吧台状态',
                        subtitle: '切换当前状态：空闲、忙碌、未营业',
                        color: BarColors.neonGold,
                        onTap: () => _showBarStatusSheet(context, ref),
                      ),
                    if (user.isAdmin)
                      _FeatureTile(
                        icon: Icons.dataset_outlined,
                        title: '数据库 GUI',
                        subtitle: '可视化查看用户、订单、评论、喜欢和社区数据',
                        color: BarColors.neonBlue,
                        onTap: () => context.push('/admin/database'),
                      )
                    else
                      _FeatureTile(
                        icon: Icons.local_bar_outlined,
                        title: '再点一杯',
                        subtitle: '回到酒单，选择今晚的下一杯',
                        color: BarColors.neonGold,
                        onTap: () => context.go('/'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _helpSubtitleFor(User user) {
    if (user.isAdmin) {
      return '快速回顾接单、改吧台状态、维护酒单和数据的流程';
    }
    return '快速了解选酒、已选酒单、订单进度和评价发布';
  }

  Future<void> _showProfileEditorSheet(
    BuildContext context,
    WidgetRef ref,
    User user,
    ProfileCustomization customization,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: BarColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _ProfileEditorSheet(
        user: user,
        customization: customization,
        onSubmit: ({
          required String nickname,
          required String signature,
          required String? avatarDataUrl,
          required String? backgroundDataUrl,
          required bool clearAvatar,
          required bool clearBackground,
        }) async {
          await ref.read(profileCustomizationProvider(user.id).notifier).save(
                avatarDataUrl: avatarDataUrl,
                backgroundDataUrl: backgroundDataUrl,
                signature: signature.trim().isEmpty ? null : signature.trim(),
                clearAvatar: clearAvatar,
                clearBackground: clearBackground,
                clearSignature: signature.trim().isEmpty,
              );
          await ref.read(authControllerProvider.notifier).updateLocalProfile(
                nickname: nickname,
                avatarUrl: clearAvatar ? null : avatarDataUrl,
                backgroundUrl: clearBackground ? null : backgroundDataUrl,
                signature: signature.trim().isEmpty ? null : signature.trim(),
                clearAvatar: clearAvatar,
                clearBackground: clearBackground,
                clearSignature: signature.trim().isEmpty,
              );
          ref.invalidate(publicProfileProvider(user.id));
          ref.invalidate(communityPostsProvider);
          ref.invalidate(reviewsRepositoryProvider);
          if (sheetContext.mounted) {
            Navigator.of(sheetContext).pop();
          }
        },
      ),
    );
  }

  Future<void> _showSettingsSheet(
    BuildContext context,
    WidgetRef ref,
    User user,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: BarColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                '设置',
                style: TextStyle(
                  color: BarColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              _SettingsTile(
                icon: Icons.security_outlined,
                title: '账号安全',
                subtitle: user.isWechatBound
                    ? '修改密码 / 已绑定微信：${user.wechatName ?? '微信账号'}'
                    : '修改密码 / 绑定微信',
                color: BarColors.neonBlue,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/profile/account-security');
                },
              ),
              const SizedBox(height: 10),
              _SettingsTile(
                icon: Icons.privacy_tip_outlined,
                title: '隐私政策',
                subtitle: '说明本地开发数据、头像和评论图片用途',
                color: BarColors.neonGold,
                onTap: () => _showPolicyDialog(
                  sheetContext,
                  title: '隐私政策',
                  message:
                      'Drunkard 私人调酒吧仅为受邀成员提供点单、评价、收藏和社区交流服务。我们会在本地或私有服务器保存你的手机号、昵称、头像、微信绑定标识、订单、评论、喜欢列表、社区内容和必要的登录凭证，用于账号识别、服务履约、安全审计和体验优化。\n\n除法律要求、服务维护或你主动公开发布的内容外，我们不会向无关第三方出售个人信息。你可以在个人名片编辑昵称、头像、背景和签名，也可以在“账号安全”中修改密码和绑定微信；如需删除账号、订单、评论或图片，请联系管理员处理。请勿在评论或社区中发布身份证号、住址、银行卡等高敏感信息。',
                ),
              ),
              _SettingsTile(
                icon: Icons.info_outline,
                title: '酒品声明',
                subtitle: '理性饮酒、过敏原和自备原料提醒',
                color: BarColors.neonPink,
                onTap: () => _showPolicyDialog(
                  sheetContext,
                  title: '酒品声明',
                  message:
                      'Drunkard 展示的酒品、酒精度、原料与库存状态仅用于私人聚会点单和备货参考，不构成医疗、营养或安全建议。请理性饮酒，未成年人、孕期/哺乳期人群、驾驶人员、服药期间或不适宜饮酒者请勿饮酒。\n\n如你对酒精、柑橘、乳制品、蛋白、坚果、香料或其他原料过敏，请在下单前主动告知。遇到缺货原料，系统会明确提示并写入订单备注；继续下单即表示你知晓并愿意自备对应材料。',
                ),
              ),
              _SettingsTile(
                icon: Icons.logout,
                title: '退出登录',
                subtitle: '清除当前会话并回到登录入口',
                color: BarColors.error,
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _confirmLogout(context, ref);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showBarStatusSheet(BuildContext context, WidgetRef ref) async {
    final current = ref.read(barStatusProvider).valueOrNull?.status ?? 'IDLE';
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: BarColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '吧台状态',
                style: TextStyle(
                  color: BarColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              ...[
                ('IDLE', '空闲', Icons.check_circle_outline, BarColors.neonGreen),
                (
                  'BUSY',
                  '忙碌',
                  Icons.local_fire_department_outlined,
                  BarColors.neonGold
                ),
                ('CLOSED', '未营业', Icons.nightlife_outlined, BarColors.error),
              ].map(
                (item) => _SettingsTile(
                  icon: item.$3,
                  title: item.$2,
                  subtitle: current == item.$1 ? '当前状态' : '切换为${item.$2}',
                  color: item.$4,
                  onTap: () async {
                    await ref
                        .read(barStatusRepositoryProvider)
                        .updateStatus(item.$1);
                    ref.invalidate(barStatusProvider);
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    await ref.read(authControllerProvider.notifier).logout();
    if (context.mounted) {
      context.go('/login');
    }
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final shouldLogout = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: BarColors.surface,
            title: const Text('确认退出登录？'),
            content: const Text(
              '退出后需要重新登录才能继续点酒、查看订单和维护个人信息。',
              style: TextStyle(height: 1.45),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('再看看'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: BarColors.error,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('确认退出'),
              ),
            ],
          ),
        ) ??
        false;

    if (shouldLogout && context.mounted) {
      await _logout(context, ref);
    }
  }

  void _showPolicyDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BarColors.surface,
        title: Text(title),
        content: Text(
          message,
          style: const TextStyle(height: 1.55),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }
}

class _ProfileEditorSheet extends StatefulWidget {
  const _ProfileEditorSheet({
    required this.user,
    required this.customization,
    required this.onSubmit,
  });

  final User user;
  final ProfileCustomization customization;
  final Future<void> Function({
    required String nickname,
    required String signature,
    required String? avatarDataUrl,
    required String? backgroundDataUrl,
    required bool clearAvatar,
    required bool clearBackground,
  }) onSubmit;

  @override
  State<_ProfileEditorSheet> createState() => _ProfileEditorSheetState();
}

class _ProfileEditorSheetState extends State<_ProfileEditorSheet> {
  late final TextEditingController _nicknameController;
  late final TextEditingController _signatureController;
  String? _avatarDataUrl;
  String? _backgroundDataUrl;
  bool _clearAvatar = false;
  bool _clearBackground = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(text: widget.user.nickname);
    _signatureController = TextEditingController(
      text: widget.customization.signature ?? '',
    );
    _avatarDataUrl = widget.customization.avatarDataUrl;
    _backgroundDataUrl = widget.customization.backgroundDataUrl;
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roleColor =
        widget.user.isAdmin ? BarColors.neonBlue : BarColors.neonPink;
    final avatarProvider =
        _profileImageProvider(_clearAvatar ? null : _avatarDataUrl);
    final backgroundProvider =
        _profileImageProvider(_clearBackground ? null : _backgroundDataUrl);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      minChildSize: 0.36,
      maxChildSize: 0.94,
      builder: (context, scrollController) => SafeArea(
        child: SingleChildScrollView(
          controller: scrollController,
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
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                '维护个人信息',
                style: TextStyle(
                  color: BarColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                height: 158,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  image: backgroundProvider == null
                      ? null
                      : DecorationImage(
                          image: backgroundProvider,
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(
                            Colors.black.withOpacity(0.25),
                            BlendMode.darken,
                          ),
                        ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      BarColors.neonPink.withOpacity(0.24),
                      BarColors.surfaceLight.withOpacity(0.9),
                    ],
                  ),
                  border: Border.all(color: Colors.white.withOpacity(0.14)),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 16,
                      bottom: 16,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: roleColor.withOpacity(0.18),
                            backgroundImage: avatarProvider,
                            child: avatarProvider == null
                                ? Text(
                                    widget.user.nickname.isEmpty
                                        ? 'D'
                                        : widget.user.nickname[0],
                                    style: TextStyle(
                                      color: roleColor,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 13),
                          SizedBox(
                            width: 190,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _nicknameController.text.trim().isEmpty
                                      ? widget.user.nickname
                                      : _nicknameController.text.trim(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: BarColors.textPrimary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  _signatureController.text.trim().isEmpty
                                      ? '写一句今晚的状态'
                                      : _signatureController.text.trim(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: BarColors.textSecondary,
                                    fontSize: 12,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _MediaButton(
                      icon: Icons.account_circle_outlined,
                      label: '修改头像',
                      onTap: () => _pickImage(isAvatar: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MediaButton(
                      icon: Icons.wallpaper_outlined,
                      label: '修改背景',
                      onTap: () => _pickImage(isAvatar: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (_avatarDataUrl != null && !_clearAvatar)
                    TextButton.icon(
                      onPressed: () => setState(() => _clearAvatar = true),
                      icon: const Icon(Icons.close),
                      label: const Text('清除头像'),
                    ),
                  if (_backgroundDataUrl != null && !_clearBackground)
                    TextButton.icon(
                      onPressed: () => setState(() => _clearBackground = true),
                      icon: const Icon(Icons.close),
                      label: const Text('清除背景'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nicknameController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: '昵称'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _signatureController,
                onChanged: (_) => setState(() {}),
                maxLength: 48,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: '个性签名',
                  hintText: '例如：今晚只喝漂亮的、微醺但清醒',
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: Text(_submitting ? '保存中...' : '保存并更新名片'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage({required bool isAvatar}) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: isAvatar ? 90 : 86,
      maxWidth: isAvatar ? 1800 : 2400,
      maxHeight: isAvatar ? 1800 : 2400,
    );
    if (image == null) {
      return;
    }

    final bytes = await image.readAsBytes();
    if (!mounted) return;

    final croppedBytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _ProfileImageCropScreen(
          imageBytes: bytes,
          title: isAvatar ? '裁切头像' : '裁切背景',
          aspectRatio: isAvatar ? 1 : 16 / 9,
          outputWidth: isAvatar ? 360 : 960,
          outputHeight: isAvatar ? 360 : 540,
        ),
      ),
    );
    if (croppedBytes == null || !mounted) return;

    final dataUrl = await _buildAdaptiveProfileDataUrl(
      croppedBytes,
      aspectRatio: isAvatar ? 1 : 16 / 9,
      initialWidth: isAvatar ? 360 : 960,
    );
    if (dataUrl == null) {
      if (mounted) showAppToast(context, '这张图信息量太大，已压缩到极限仍无法保存。');
      return;
    }

    setState(() {
      if (isAvatar) {
        _avatarDataUrl = dataUrl;
        _clearAvatar = false;
      } else {
        _backgroundDataUrl = dataUrl;
        _clearBackground = false;
      }
    });
  }

  Future<String?> _buildAdaptiveProfileDataUrl(
    Uint8List bytes, {
    required double aspectRatio,
    required int initialWidth,
  }) async {
    var width = initialWidth;
    while (width >= 160) {
      final height = (width / aspectRatio).round();
      final resized = await _resizeImageBytes(bytes, width, height);
      final dataUrl = 'data:image/png;base64,${base64Encode(resized)}';
      if (dataUrl.length <= _maxProfileImageDataUrlLength) {
        return dataUrl;
      }
      width = (width * 0.82).round();
    }
    return null;
  }

  Future<Uint8List> _resizeImageBytes(
    Uint8List bytes,
    int width,
    int height,
  ) async {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: width,
      targetHeight: height,
    );
    final frame = await codec.getNextFrame();
    final byteData =
        await frame.image.toByteData(format: ui.ImageByteFormat.png);
    final result = byteData?.buffer.asUint8List();
    if (result == null) {
      throw Exception('图片压缩失败');
    }
    return result;
  }

  Future<void> _submit() async {
    final nickname = _nicknameController.text.trim();
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        nickname: nickname.isEmpty ? widget.user.nickname : nickname,
        signature: _signatureController.text,
        avatarDataUrl: _clearAvatar ? null : _avatarDataUrl,
        backgroundDataUrl: _clearBackground ? null : _backgroundDataUrl,
        clearAvatar: _clearAvatar,
        clearBackground: _clearBackground,
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}

class _MediaButton extends StatelessWidget {
  const _MediaButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: BarColors.neonBlue,
        side: BorderSide(color: BarColors.neonBlue.withOpacity(0.34)),
        padding: const EdgeInsets.symmetric(vertical: 13),
      ),
    );
  }
}

class _ProfileBackdrop extends StatelessWidget {
  const _ProfileBackdrop({
    required this.user,
    required this.customization,
  });

  final User user;
  final ProfileCustomization customization;

  @override
  Widget build(BuildContext context) {
    final signature = customization.signature?.trim();
    final backgroundProvider =
        _profileImageProvider(customization.backgroundDataUrl);

    return LayoutBuilder(
      builder: (context, constraints) {
        final topPadding = MediaQuery.of(context).padding.top;
        final minHeight = kToolbarHeight + topPadding;
        final maxDelta = 220 - minHeight;
        final progress = maxDelta <= 0
            ? 1.0
            : ((constraints.maxHeight - minHeight) / maxDelta).clamp(0.0, 1.0);
        final contentOpacity = Curves.easeOutCubic.transform(
          ((progress - 0.22) / 0.78).clamp(0.0, 1.0),
        );
        final contentOffset = (1 - progress) * 34;
        final imageScale = 1 + (1 - progress) * 0.035;

        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Transform.scale(
                scale: imageScale,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    image: backgroundProvider == null
                        ? null
                        : DecorationImage(
                            image: backgroundProvider,
                            fit: BoxFit.cover,
                            colorFilter: ColorFilter.mode(
                              Colors.black.withOpacity(0.24),
                              BlendMode.darken,
                            ),
                          ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        BarColors.neonPink.withOpacity(0.28),
                        BarColors.surfaceLight.withOpacity(0.86),
                        BarColors.background,
                      ],
                    ),
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      BarColors.background.withOpacity(0.02),
                      BarColors.background.withOpacity(0.22),
                      BarColors.background.withOpacity(0.82),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: -28,
                bottom: -18 - contentOffset * 0.2,
                child: Opacity(
                  opacity: 0.35 + contentOpacity * 0.65,
                  child: Icon(
                    Icons.person_pin_circle_outlined,
                    size: 150,
                    color: Colors.white.withOpacity(0.055),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomLeft,
                child: Opacity(
                  opacity: contentOpacity,
                  child: Transform.translate(
                    offset: Offset(0, contentOffset * 1.2),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 0, 80, 28),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Text(
                          signature?.isNotEmpty == true
                              ? signature!
                              : (user.isAdmin
                                  ? 'Curate the private bar.'
                                  : 'Your table, your pour.'),
                          style: const TextStyle(
                            color: BarColors.textPrimary,
                            fontSize: 14,
                            height: 1.35,
                            letterSpacing: 0.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.user,
    required this.customization,
    required this.onEdit,
  });

  final User user;
  final ProfileCustomization customization;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final roleColor = user.isAdmin ? BarColors.neonBlue : BarColors.neonPink;
    final avatarProvider =
        _profileImageProvider(customization.avatarDataUrl ?? user.avatarUrl);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.12),
            BarColors.surfaceLight.withOpacity(0.85),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
        boxShadow: [
          BoxShadow(
            color: roleColor.withOpacity(0.18),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: roleColor.withOpacity(0.16),
            backgroundImage: avatarProvider,
            child: avatarProvider == null
                ? Text(
                    user.nickname.isEmpty ? 'D' : user.nickname[0],
                    style: TextStyle(
                      color: roleColor,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.nickname,
                  style: const TextStyle(
                    color: BarColors.textPrimary,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    _RoleChip(
                      label: user.isAdmin ? '管理员' : '访客',
                      color: roleColor,
                    ),
                    const SizedBox(width: 8),
                    const _RoleChip(
                      label: 'Drunkard',
                      color: BarColors.neonGold,
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
            color: BarColors.textSecondary,
            tooltip: '维护个人信息',
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.38)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: BarColors.surface.withOpacity(0.78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: BarColors.textPrimary,
              fontSize: 17,
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
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.045),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
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
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: BarColors.textSecondary,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: BarColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _FeatureTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      color: color,
      onTap: onTap,
    );
  }
}

class _ProfileImageCropScreen extends StatefulWidget {
  const _ProfileImageCropScreen({
    required this.imageBytes,
    required this.title,
    required this.aspectRatio,
    required this.outputWidth,
    required this.outputHeight,
  });

  final Uint8List imageBytes;
  final String title;
  final double aspectRatio;
  final int outputWidth;
  final int outputHeight;

  @override
  State<_ProfileImageCropScreen> createState() =>
      _ProfileImageCropScreenState();
}

class _ProfileImageCropScreenState extends State<_ProfileImageCropScreen> {
  ui.Image? _sourceImage;
  Size? _viewportSize;
  double _baseScale = 1;
  double _scale = 1;
  double _gestureStartScale = 1;
  Offset _offset = Offset.zero;
  Offset _gestureStartOffset = Offset.zero;
  Offset _gestureStartFocalPoint = Offset.zero;
  bool _cropping = false;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  Future<void> _decode() async {
    final codec = await ui.instantiateImageCodec(widget.imageBytes);
    final frame = await codec.getNextFrame();
    if (!mounted) return;
    setState(() => _sourceImage = frame.image);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
        actions: [
          TextButton(
            onPressed: _cropping ? null : _finishCrop,
            child: Text(_cropping ? '处理中...' : '使用图片'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '拖动、双指缩放，把想展示的部分放进裁切框',
                style: TextStyle(
                  color: BarColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '确认后会自动压缩到适合展示与保存的大小，不用再手动找小图。',
                style: TextStyle(color: BarColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 18),
              Expanded(child: Center(child: _buildViewport())),
              const SizedBox(height: 16),
              Row(
                children: [
                  IconButton.filledTonal(
                    onPressed:
                        _sourceImage == null ? null : () => _adjustScale(0.9),
                    icon: const Icon(Icons.remove),
                  ),
                  Expanded(
                    child: Slider(
                      value: _sliderValue,
                      min: _sliderMin,
                      max: _sliderMax,
                      onChanged: _sourceImage == null
                          ? null
                          : (value) => setState(() => _setScale(value)),
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed:
                        _sourceImage == null ? null : () => _adjustScale(1.12),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _cropping ? null : _finishCrop,
                  icon: const Icon(Icons.check),
                  label: Text(_cropping ? '处理中...' : '确认裁切'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double get _sliderMin => _baseScale <= 0 ? 1 : _baseScale;
  double get _sliderMax => _baseScale <= 0 ? 5 : _baseScale * 5;
  double get _sliderValue => _scale.clamp(_sliderMin, _sliderMax);

  Size? get _containSize {
    final image = _sourceImage;
    final viewport = _viewportSize;
    if (image == null || viewport == null) return null;
    final imageAspect = image.width / image.height;
    final viewportAspect = viewport.width / viewport.height;
    return imageAspect >= viewportAspect
        ? Size(viewport.width, viewport.width / imageAspect)
        : Size(viewport.height * imageAspect, viewport.height);
  }

  Widget _buildViewport() {
    if (_sourceImage == null) {
      return const CircularProgressIndicator();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        var width = constraints.maxWidth;
        var height = width / widget.aspectRatio;
        if (height > constraints.maxHeight) {
          height = constraints.maxHeight;
          width = height * widget.aspectRatio;
        }
        final viewportSize = Size(width, height);
        if (_viewportSize != viewportSize) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _ensureViewport(viewportSize));
          });
        }

        return SizedBox(
          width: width,
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: GestureDetector(
              onScaleStart: (details) {
                _gestureStartScale = _scale;
                _gestureStartOffset = _offset;
                _gestureStartFocalPoint = details.localFocalPoint;
              },
              onScaleUpdate: (details) {
                setState(() {
                  _scale = (_gestureStartScale * details.scale).clamp(
                    _sliderMin,
                    _sliderMax,
                  );
                  _offset = _clampOffset(
                    _gestureStartOffset +
                        details.localFocalPoint -
                        _gestureStartFocalPoint,
                    viewportSize,
                    _scale,
                  );
                });
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: BarColors.background),
                  Transform.translate(
                    offset: _offset,
                    child: Center(
                      child: Transform.scale(
                        scale: _scale,
                        child: SizedBox(
                          width: _containSize?.width ?? width,
                          height: _containSize?.height ?? height,
                          child: RawImage(
                            image: _sourceImage,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: BarColors.neonGold.withOpacity(0.95),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _ensureViewport(Size viewportSize) {
    if (_sourceImage == null || _viewportSize == viewportSize) return;
    _viewportSize = viewportSize;
    _baseScale = _coverScale(viewportSize);
    _scale = _baseScale * 1.04;
    _offset = Offset.zero;
  }

  void _adjustScale(double factor) {
    _setScale(_scale * factor);
    setState(() {});
  }

  void _setScale(double value) {
    final viewport = _viewportSize;
    if (viewport == null) return;
    _scale = value.clamp(_sliderMin, _sliderMax);
    _offset = _clampOffset(_offset, viewport, _scale);
  }

  double _coverScale(Size viewport) {
    final contain = _containSize;
    if (contain == null) return 1;
    return math.max(
        viewport.width / contain.width, viewport.height / contain.height);
  }

  Offset _clampOffset(Offset offset, Size viewport, double scale) {
    final contain = _containSize;
    if (contain == null) return Offset.zero;
    final displayWidth = contain.width * scale;
    final displayHeight = contain.height * scale;
    final maxX = math.max(0.0, (displayWidth - viewport.width) / 2);
    final maxY = math.max(0.0, (displayHeight - viewport.height) / 2);
    return Offset(
      offset.dx.clamp(-maxX, maxX),
      offset.dy.clamp(-maxY, maxY),
    );
  }

  Future<void> _finishCrop() async {
    setState(() => _cropping = true);
    try {
      final source = _sourceImage;
      final viewport = _viewportSize;
      final contain = _containSize;
      if (source == null || viewport == null || contain == null) {
        throw Exception('图片还没准备好');
      }

      final displayWidth = contain.width * _scale;
      final displayHeight = contain.height * _scale;
      final displayLeft = (viewport.width - displayWidth) / 2 + _offset.dx;
      final displayTop = (viewport.height - displayHeight) / 2 + _offset.dy;
      final sourceRect = Rect.fromLTWH(
        (-displayLeft / displayWidth * source.width)
            .clamp(0.0, source.width.toDouble()),
        (-displayTop / displayHeight * source.height)
            .clamp(0.0, source.height.toDouble()),
        (viewport.width / displayWidth * source.width)
            .clamp(1.0, source.width.toDouble()),
        (viewport.height / displayHeight * source.height)
            .clamp(1.0, source.height.toDouble()),
      );
      final safeRect = Rect.fromLTWH(
        sourceRect.left.clamp(0.0, source.width - 1.0),
        sourceRect.top.clamp(0.0, source.height - 1.0),
        math.min(sourceRect.width, source.width - sourceRect.left),
        math.min(sourceRect.height, source.height - sourceRect.top),
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final outputSize = Size(
        widget.outputWidth.toDouble(),
        widget.outputHeight.toDouble(),
      );
      canvas.drawImageRect(
        source,
        safeRect,
        Offset.zero & outputSize,
        Paint()..filterQuality = FilterQuality.high,
      );
      final picture = recorder.endRecording();
      final cropped = await picture.toImage(
        widget.outputWidth,
        widget.outputHeight,
      );
      final byteData = await cropped.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();
      if (bytes == null) throw Exception('图片裁切失败');
      if (mounted) Navigator.of(context).pop(bytes);
    } catch (error) {
      if (mounted) showAppToast(context, '裁切失败：$error');
    } finally {
      if (mounted) setState(() => _cropping = false);
    }
  }
}

ImageProvider? _profileImageProvider(String? source) {
  if (source == null || source.trim().isEmpty) {
    return null;
  }

  final value = source.trim();
  if (value.length > _maxStoredProfileImageDataUrlLength) {
    return null;
  }

  if (!value.startsWith('data:image/')) {
    return NetworkImage(value);
  }

  final commaIndex = value.indexOf(',');
  if (commaIndex < 0) {
    return null;
  }

  try {
    return MemoryImage(base64Decode(value.substring(commaIndex + 1)));
  } catch (_) {
    return null;
  }
}
