import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/colors.dart';
import '../../../shared/widgets/app_image.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../auth/data/auth_controller.dart';
import '../data/community_repository.dart';

class CommunityPostDetailScreen extends ConsumerStatefulWidget {
  const CommunityPostDetailScreen({super.key, required this.postId});

  final String postId;

  @override
  ConsumerState<CommunityPostDetailScreen> createState() =>
      _CommunityPostDetailScreenState();
}

class _CommunityPostDetailScreenState
    extends ConsumerState<CommunityPostDetailScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final postState = ref.watch(communityPostProvider(widget.postId));
    final user = ref.watch(authControllerProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('社区详情'),
        leading: IconButton(
          onPressed: () => context.go('/community'),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
      ),
      body: postState.when(
        data: (post) {
          final canEdit = user?.id == post.userId;
          final canDelete = canEdit || (user?.isAdmin ?? false);

          return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
          children: [
            GlassCard(
              borderRadius: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: post.userId.isEmpty
                        ? null
                        : () => context.push('/users/${post.userId}'),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: BarColors.neonPink.withOpacity(0.14),
                            backgroundImage: appImageProvider(post.avatarUrl),
                            child: appImageProvider(post.avatarUrl) == null
                                ? Text(post.nickname.isEmpty ? 'D' : post.nickname[0])
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  post.nickname,
                                  style: const TextStyle(
                                    color: BarColors.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${post.displayCategory} · ${DateFormat('yyyy-MM-dd HH:mm').format(post.createdAt.toLocal())}',
                                  style: const TextStyle(
                                    color: BarColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: BarColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    post.title,
                    style: const TextStyle(
                      color: BarColors.textPrimary,
                      fontSize: 24,
                      height: 1.2,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    post.content,
                    style: const TextStyle(
                      color: BarColors.textPrimary,
                      fontSize: 15,
                      height: 1.7,
                    ),
                  ),
                  if (post.photos.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ...post.photos.map(
                      (photo) {
                        final heroTag = 'community-${post.id}-$photo';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GestureDetector(
                            onTap: () => showImagePreview(
                              context,
                              source: photo,
                              heroTag: heroTag,
                            ),
                            child: Hero(
                              tag: heroTag,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: appImage(photo, fit: BoxFit.cover),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 8,
                      children: [
                        if (canEdit)
                          OutlinedButton.icon(
                            onPressed: () => context.push('/community/${post.id}/edit'),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('编辑'),
                          ),
                        if (canDelete)
                          OutlinedButton.icon(
                            onPressed: _busy ? null : () => _deletePost(post.id),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('删除'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: BarColors.error,
                            ),
                          ),
                        FilledButton.icon(
                          onPressed: _busy ? null : () => _toggleLike(post),
                          icon: Icon(
                            post.likedByMe
                                ? Icons.favorite
                                : Icons.favorite_border,
                          ),
                          label: Text('${post.likeCount}'),
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
          child: Text(
            '详情加载失败：$error',
            style: const TextStyle(color: BarColors.textSecondary),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleLike(CommunityPost post) async {
    setState(() => _busy = true);
    try {
      await ref.read(communityRepositoryProvider).toggleLike(post.id);
      ref.invalidate(communityPostProvider(post.id));
      ref.invalidate(communityPostsProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deletePost(String postId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BarColors.surface,
        title: const Text('删除这条内容？'),
        content: const Text('删除后不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(communityRepositoryProvider).deletePost(postId);
      ref.invalidate(communityPostsProvider);
      if (mounted) context.go('/community');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
