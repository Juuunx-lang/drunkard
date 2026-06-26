import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/colors.dart';
import '../../../shared/utils/image_upload_utils.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/review_actions_controller.dart';

class ReviewComposerSheet extends ConsumerStatefulWidget {
  const ReviewComposerSheet({
    super.key,
    required this.drinkId,
    required this.orderItemId,
    required this.drinkName,
  });

  final String drinkId;
  final String orderItemId;
  final String drinkName;

  @override
  ConsumerState<ReviewComposerSheet> createState() =>
      _ReviewComposerSheetState();
}

class _ReviewComposerSheetState extends ConsumerState<ReviewComposerSheet> {
  static const _quickEmojis = ['😍', '😋', '🥂', '🔥', '👍', '🫶'];

  final _controller = TextEditingController();
  final _picker = ImagePicker();
  final List<XFile> _photos = [];
  int _rating = 5;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(reviewActionsControllerProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '评价 ${widget.drinkName}',
            style: const TextStyle(
              color: BarColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '已完成的订单会保留在这里，方便你补评论和回看记录。',
            style: TextStyle(
              color: BarColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(
              5,
              (index) => IconButton(
                onPressed: actionState.isLoading
                    ? null
                    : () => setState(() => _rating = index + 1),
                icon: Icon(
                  index < _rating ? Icons.star : Icons.star_border,
                  color: BarColors.neonGold,
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: TextField(
              controller: _controller,
              enabled: !actionState.isLoading,
              maxLines: 5,
              minLines: 3,
              style: const TextStyle(color: BarColors.textPrimary),
              decoration: const InputDecoration(
                hintText: '像微信一样，直接说说口感、颜值、酒感和你的心情…',
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickEmojis
                .map(
                  (emoji) => ActionChip(
                    label: Text(emoji),
                    onPressed: actionState.isLoading
                        ? null
                        : () {
                            final text = _controller.text;
                            _controller.value = TextEditingValue(
                              text: text.isEmpty ? emoji : '$text $emoji',
                              selection: TextSelection.collapsed(
                                offset: (text.isEmpty ? emoji : '$text $emoji')
                                    .length,
                              ),
                            );
                            setState(() {});
                          },
                    backgroundColor: Colors.white.withOpacity(0.06),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: actionState.isLoading ? null : _pickPhotos,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text('添加图片 ${_photos.length}/9'),
              ),
              if (_photos.isNotEmpty) ...[
                const SizedBox(width: 10),
                const Text(
                  '支持多图',
                  style: TextStyle(
                    color: BarColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
          if (_photos.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final photo = _photos[index];
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
                                width: 84,
                                height: 84,
                                fit: BoxFit.cover,
                              );
                            }

                            return Container(
                              width: 84,
                              height: 84,
                              color: Colors.white.withOpacity(0.06),
                              alignment: Alignment.center,
                              child: snapshot.hasError
                                  ? const Icon(
                                      Icons.image_not_supported_outlined,
                                      color: BarColors.textSecondary,
                                    )
                                  : const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                            );
                          },
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: InkWell(
                          onTap: actionState.isLoading
                              ? null
                              : () => setState(() => _photos.removeAt(index)),
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
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: actionState.isLoading ? null : _submit,
              icon: actionState.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(actionState.isLoading ? '发布中...' : '发布评价'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPhotos() async {
    final remaining = 9 - _photos.length;
    if (remaining <= 0) {
      return;
    }

    final picked = await _picker.pickMultiImage(
      limit: remaining,
      imageQuality: 85,
      maxWidth: 2400,
      maxHeight: 2400,
    );
    if (picked.isEmpty) {
      return;
    }

    final compressed = await compressUploadImages(
      picked.take(remaining),
      initialMaxSide: 1600,
    );
    if (!mounted) return;

    setState(() {
      _photos.addAll(compressed);
    });
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty) {
      showAppToast(context, '先写点内容再发出去吧');
      return;
    }

    await ref.read(reviewActionsControllerProvider.notifier).submitReview(
          drinkId: widget.drinkId,
          orderItemId: widget.orderItemId,
          content: content,
          rating: _rating,
          photos: _photos,
        );

    final nextState = ref.read(reviewActionsControllerProvider);
    if (!mounted) {
      return;
    }

    if (nextState.hasError) {
      showAppToast(context, '评价发布失败：${nextState.error}');
      return;
    }

    Navigator.of(context).pop(true);
    showAppToast(context, '评价已发布');
  }
}
