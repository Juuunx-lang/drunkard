import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/colors.dart';
import '../../../shared/widgets/app_image.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/public_profile_repository.dart';

class PublicProfileScreen extends ConsumerWidget {
  const PublicProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(publicProfileProvider(userId));

    return Scaffold(
      body: profileState.when(
        data: (profile) {
          final avatarProvider = appImageProvider(profile.avatarUrl);
          final backgroundProvider = appImageProvider(profile.backgroundUrl);

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                leading: IconButton(
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      context.pop();
                    } else {
                      context.go('/community');
                    }
                  },
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                ),
                title: Text(profile.nickname),
                flexibleSpace: FlexibleSpaceBar(
                  background: GestureDetector(
                    onTap: profile.backgroundUrl == null
                        ? null
                        : () => showImagePreview(
                              context,
                              source: profile.backgroundUrl!,
                            ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            image: backgroundProvider == null
                                ? null
                                : DecorationImage(
                                    image: backgroundProvider,
                                    fit: BoxFit.cover,
                                    colorFilter: ColorFilter.mode(
                                      Colors.black.withOpacity(0.2),
                                      BlendMode.darken,
                                    ),
                                  ),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                BarColors.neonPink.withOpacity(0.28),
                                BarColors.neonBlue.withOpacity(0.18),
                                BarColors.background,
                              ],
                            ),
                          ),
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.02),
                                BarColors.background.withOpacity(0.86),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 112),
                sliver: SliverList.list(
                  children: [
                    GlassCard(
                      borderRadius: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: profile.avatarUrl == null
                                    ? null
                                    : () => showImagePreview(
                                          context,
                                          source: profile.avatarUrl!,
                                        ),
                                child: CircleAvatar(
                                  radius: 42,
                                  backgroundColor:
                                      BarColors.neonPink.withOpacity(0.18),
                                  backgroundImage: avatarProvider,
                                  child: avatarProvider == null
                                      ? Text(
                                          profile.nickname.isEmpty
                                              ? 'D'
                                              : profile.nickname[0],
                                          style: const TextStyle(
                                            color: BarColors.neonPink,
                                            fontSize: 32,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      profile.nickname,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: BarColors.textPrimary,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    _RoleBadge(isAdmin: profile.isAdmin),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            profile.signature?.trim().isNotEmpty == true
                                ? profile.signature!.trim()
                                : '这个人还没留下今晚的签名。',
                            style: const TextStyle(
                              color: BarColors.textPrimary,
                              fontSize: 15,
                              height: 1.55,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              _StatCell(
                                label: '社区',
                                value: profile.communityPosts,
                              ),
                              _StatCell(label: '评价', value: profile.reviews),
                              _StatCell(label: '喜欢', value: profile.favorites),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '加入于 ${DateFormat('yyyy-MM-dd').format(profile.createdAt.toLocal())}',
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
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '用户资料加载失败：$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: BarColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.isAdmin});

  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final color = isAdmin ? BarColors.neonBlue : BarColors.neonGold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.38)),
      ),
      child: Text(
        isAdmin ? '调酒师' : '顾客',
        style:
            TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.055),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: const TextStyle(
                color: BarColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style:
                  const TextStyle(color: BarColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
