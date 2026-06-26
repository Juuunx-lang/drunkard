import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/theme/colors.dart';
import '../data/community_repository.dart';

const _communityCategories = [
  ('ALL', '全部'),
  ('BAR', '本店'),
  ('OFFICIAL', '官方'),
  ('LIFE', '生活'),
  ('MY', '我的'),
];

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(communityFilterProvider);
    final postsState = ref.watch(communityPostsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('社区')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/community/new'),
        backgroundColor: BarColors.neonPink,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: _CategoryPicker(
              selected: filter.category,
              onChanged: (category) {
                ref.read(communityFilterProvider.notifier).state =
                    filter.copyWith(category: category);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                ref.read(communityFilterProvider.notifier).state =
                    ref.read(communityFilterProvider).copyWith(query: value);
              },
              decoration: InputDecoration(
                hintText: '在当前栏目搜索标题 / 昵称',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: filter.query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          ref.read(communityFilterProvider.notifier).state =
                              ref.read(communityFilterProvider).copyWith(query: '');
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
          ),
          Expanded(
            child: postsState.when(
              data: (posts) {
                if (posts.isEmpty) {
                  return const Center(
                    child: Text(
                      '这个栏目还很安静，来发第一条吧。',
                      style: TextStyle(color: BarColors.textSecondary),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.refresh(communityPostsProvider.future),
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 112),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.66,
                    ),
                    itemCount: posts.length,
                    itemBuilder: (context, index) => _PostCard(post: posts[index]),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text(
                  '社区加载失败：$error',
                  style: const TextStyle(color: BarColors.textSecondary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _communityCategories.map((item) {
        final active = selected == item.$1;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onChanged(item.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active
                      ? BarColors.neonPink.withOpacity(0.18)
                      : Colors.white.withOpacity(0.045),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: active
                        ? BarColors.neonPink.withOpacity(0.52)
                        : Colors.white.withOpacity(0.08),
                  ),
                ),
                child: Text(
                  item.$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: active ? BarColors.textPrimary : BarColors.textSecondary,
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PostCard extends ConsumerStatefulWidget {
  const _PostCard({required this.post});

  final CommunityPost post;

  @override
  ConsumerState<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<_PostCard> {
  late bool _liked = widget.post.likedByMe;
  late int _likeCount = widget.post.likeCount;
  bool _busy = false;

  @override
  void didUpdateWidget(covariant _PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id ||
        oldWidget.post.likedByMe != widget.post.likedByMe ||
        oldWidget.post.likeCount != widget.post.likeCount) {
      _liked = widget.post.likedByMe;
      _likeCount = widget.post.likeCount;
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.post.photos.isEmpty
        ? null
        : ApiConstants.resolveUrl(widget.post.photos.first);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => context.push('/community/${widget.post.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: BarColors.surface.withOpacity(0.82),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: imageUrl == null
                  ? Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            BarColors.neonPink.withOpacity(0.22),
                            BarColors.neonBlue.withOpacity(0.16),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Text(
                          widget.post.displayCategory,
                          style: const TextStyle(
                            color: BarColors.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    )
                  : Image.network(imageUrl, fit: BoxFit.cover),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.post.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: BarColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        height: 1.18,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.post.nickname,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: BarColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: _busy ? null : _toggleLike,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Row(
                              children: [
                                Icon(
                                  _liked ? Icons.favorite : Icons.favorite_border,
                                  size: 17,
                                  color: _liked
                                      ? BarColors.neonPink
                                      : BarColors.textSecondary,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '$_likeCount',
                                  style: const TextStyle(
                                    color: BarColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleLike() async {
    setState(() => _busy = true);
    try {
      final result =
          await ref.read(communityRepositoryProvider).toggleLike(widget.post.id);
      setState(() {
        _liked = result.liked;
        _likeCount = result.likeCount;
      });
      ref.invalidate(communityPostsProvider);
      ref.invalidate(communityPostProvider(widget.post.id));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
