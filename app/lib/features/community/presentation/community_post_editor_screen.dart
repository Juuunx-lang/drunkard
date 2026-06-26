import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/api_constants.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/utils/image_upload_utils.dart';
import '../../auth/data/auth_controller.dart';
import '../data/community_repository.dart';

class CommunityPostEditorScreen extends ConsumerStatefulWidget {
  const CommunityPostEditorScreen({super.key, this.postId});

  final String? postId;

  @override
  ConsumerState<CommunityPostEditorScreen> createState() =>
      _CommunityPostEditorScreenState();
}

class _CommunityPostEditorScreenState
    extends ConsumerState<CommunityPostEditorScreen> {
  static const _emojis = ['🥂', '🍸', '😋', '🔥', '🫶', '😎', '🙃', '💅'];

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _picker = ImagePicker();
  final List<XFile> _photos = [];
  final List<String> _existingPhotoUrls = [];
  String _category = 'LIFE';
  bool _submitting = false;
  bool _loadingExisting = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin =
        ref.watch(authControllerProvider).valueOrNull?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.postId == null ? '发布内容' : '编辑内容'),
        leading: IconButton(
          onPressed: () => context.go('/community'),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        children: [
          if (_loadingExisting) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 14),
          ],
          SegmentedButton<String>(
            segments: [
              const ButtonSegment(value: 'LIFE', label: Text('生活')),
              const ButtonSegment(value: 'BAR', label: Text('本店')),
              if (isAdmin)
                const ButtonSegment(value: 'OFFICIAL', label: Text('官方')),
            ],
            selected: {_category},
            onSelectionChanged: (selection) =>
                setState(() => _category = selection.first),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _titleController,
            maxLength: 40,
            decoration: const InputDecoration(
              labelText: '标题',
              hintText: '给这条内容取个标题',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _contentController,
            minLines: 7,
            maxLines: 12,
            decoration: const InputDecoration(
              labelText: '内容',
              hintText: '写点真实的、好玩的、带点情绪的…',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _emojis
                .map(
                  (emoji) => ActionChip(
                    label: Text(emoji),
                    onPressed: _submitting ? null : () => _appendEmoji(emoji),
                    backgroundColor: Colors.white.withOpacity(0.06),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _submitting ? null : _pickPhotos,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text('添加图片 ${_existingPhotoUrls.length + _photos.length}/3'),
          ),
          if (_existingPhotoUrls.isNotEmpty || _photos.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _existingPhotoUrls.length + _photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  if (index < _existingPhotoUrls.length) {
                    return _ExistingPhotoThumb(
                      url: _existingPhotoUrls[index],
                      onRemove: _submitting
                          ? null
                          : () => setState(
                              () => _existingPhotoUrls.removeAt(index)),
                    );
                  }
                  final photoIndex = index - _existingPhotoUrls.length;
                  final photo = _photos[photoIndex];
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: FutureBuilder(
                          future: photo.readAsBytes(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return Image.memory(
                                snapshot.data!,
                                width: 92,
                                height: 92,
                                fit: BoxFit.cover,
                              );
                            }
                            return Container(
                              width: 92,
                              height: 92,
                              color: Colors.white.withOpacity(0.06),
                            );
                          },
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: InkWell(
                          onTap: _submitting
                              ? null
                              : () =>
                                  setState(() => _photos.removeAt(photoIndex)),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: Text(_submitting
                ? (widget.postId == null ? '发布中...' : '保存中...')
                : (widget.postId == null ? '发布' : '保存修改')),
          ),
        ],
      ),
    );
  }

  Future<void> _loadExisting() async {
    final postId = widget.postId;
    if (postId == null) return;
    setState(() => _loadingExisting = true);
    try {
      final post = await ref.read(communityRepositoryProvider).getPost(postId);
      if (!mounted) return;
      setState(() {
        _category = post.category == 'SHARE' ? 'LIFE' : post.category;
        _titleController.text = post.title;
        _contentController.text = post.content;
        _existingPhotoUrls
          ..clear()
          ..addAll(post.photos.take(3));
      });
    } catch (error) {
      if (mounted) _toast('内容加载失败：$error');
    } finally {
      if (mounted) setState(() => _loadingExisting = false);
    }
  }

  void _appendEmoji(String emoji) {
    final text = _contentController.text;
    final next = text.isEmpty ? emoji : '$text $emoji';
    _contentController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  Future<void> _pickPhotos() async {
    final remaining = 3 - _existingPhotoUrls.length - _photos.length;
    if (remaining <= 0) return;
    final picked = await _picker.pickMultiImage(
      limit: remaining,
      imageQuality: 84,
      maxWidth: 2400,
      maxHeight: 2400,
    );
    if (picked.isEmpty) return;
    final compressed = await compressUploadImages(
      picked.take(remaining),
      initialMaxSide: 1600,
    );
    if (!mounted) return;
    setState(() => _photos.addAll(compressed));
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.length < 2) {
      _toast('标题至少 2 个字');
      return;
    }
    if (content.length < 2) {
      _toast('内容至少 2 个字');
      return;
    }

    setState(() => _submitting = true);
    try {
      final repository = ref.read(communityRepositoryProvider);
      final photoUrls = await repository.uploadPhotos(_photos);
      final allPhotoUrls =
          [..._existingPhotoUrls, ...photoUrls].take(3).toList();
      if (widget.postId == null) {
        await repository.createPost(
          category: _category,
          title: title,
          content: content,
          photoUrls: allPhotoUrls,
        );
      } else {
        await repository.updatePost(
          id: widget.postId!,
          category: _category,
          title: title,
          content: content,
          photoUrls: allPhotoUrls,
        );
        ref.invalidate(communityPostProvider(widget.postId!));
      }
      ref.invalidate(communityPostsProvider);
      if (mounted) {
        context.go(widget.postId == null
            ? '/community'
            : '/community/${widget.postId}');
      }
    } catch (error) {
      if (mounted) _toast('发布失败：$error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _toast(String message) {
    showAppToast(context, message);
  }
}

class _ExistingPhotoThumb extends StatelessWidget {
  const _ExistingPhotoThumb({required this.url, required this.onRemove});

  final String url;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.network(
            ApiConstants.resolveUrl(url) ?? url,
            width: 92,
            height: 92,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: InkWell(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
