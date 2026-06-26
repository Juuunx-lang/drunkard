import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/colors.dart';
import '../../../shared/widgets/app_image.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/review_model.dart';

class ReviewCard extends StatelessWidget {
  const ReviewCard({
    super.key,
    required this.review,
    this.index = 0,
    this.compact = false,
  });

  final Review review;
  final int index;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final card = RepaintBoundary(
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: review.userId == null || review.userId!.isEmpty
                        ? null
                        : () => context.push('/users/${review.userId}'),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: compact ? 14 : 16,
                            backgroundColor:
                                BarColors.neonBlue.withValues(alpha: 0.3),
                            backgroundImage: appImageProvider(review.avatarUrl),
                            child: appImageProvider(review.avatarUrl) == null
                                ? Text(
                                    review.nickname.isEmpty
                                        ? '?'
                                        : review.nickname[0],
                                    style: TextStyle(
                                      color: BarColors.neonBlue,
                                      fontSize: compact ? 11 : 12,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              review.nickname,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: BarColors.textPrimary,
                                fontSize: compact ? 13 : 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (review.userId != null &&
                              review.userId!.isNotEmpty)
                            const Padding(
                              padding: EdgeInsets.only(left: 4, right: 8),
                              child: Icon(
                                Icons.chevron_right,
                                size: 16,
                                color: BarColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (review.rating != null)
                  Row(
                    children: List.generate(
                      5,
                      (starIndex) => Icon(
                        starIndex < review.rating!
                            ? Icons.star
                            : Icons.star_border,
                        size: compact ? 13 : 14,
                        color: BarColors.neonGold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              review.content,
              style: TextStyle(
                color: BarColors.textPrimary,
                fontSize: compact ? 13 : 14,
                height: 1.5,
              ),
            ),
            if (review.photos.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: review.photos
                    .map(
                      (photoUrl) => GestureDetector(
                        onTap: () =>
                            showImagePreview(context, source: photoUrl),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: appImage(
                            photoUrl,
                            width: compact ? 72 : 88,
                            height: compact ? 72 : 88,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              review.createdAt == null
                  ? '刚刚'
                  : DateFormat('yyyy-MM-dd HH:mm')
                      .format(review.createdAt!.toLocal()),
              style: const TextStyle(
                color: BarColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );

    if (compact || index >= 4) {
      return card;
    }

    return card.animate().fadeIn(delay: (48 * index).ms).slideY(begin: 0.03);
  }
}
