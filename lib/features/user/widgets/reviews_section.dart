import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/review.dart';
import '../../../shared/providers/review_providers.dart';

/// Top N reviews for a restaurant, rendered as a vertical list with stars,
/// author, date and comment. Empty state encourages the first review.
class ReviewsSection extends ConsumerWidget {
  const ReviewsSection({
    super.key,
    required this.restaurantId,
    this.maxItems = 5,
  });

  final String restaurantId;
  final int maxItems;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(restaurantReviewsProvider(restaurantId));
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.lg,
        AppSizes.pagePadding,
        AppSizes.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reviews', style: AppTextStyles.heading1),
          const SizedBox(height: AppSizes.md),
          async.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSizes.md),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (e, _) => _ErrorBox(
              message: '$e',
              onRetry: () =>
                  ref.invalidate(restaurantReviewsProvider(restaurantId)),
            ),
            data: (list) {
              if (list.isEmpty) return const _EmptyState();
              final shown = list.take(maxItems).toList(growable: false);
              return Column(
                children: [
                  for (final r in shown) _ReviewTile(review: r),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});
  final Review review;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StarChip(rating: review.rating),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: Text(
                  review.userName?.trim().isNotEmpty == true
                      ? review.userName!
                      : 'Anonymous',
                  style: AppTextStyles.bodyBold,
                ),
              ),
              Text(
                _formatDate(review.createdAt),
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
          if ((review.comment ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSizes.sm),
            Text(
              review.comment!,
              style: AppTextStyles.body
                  .copyWith(color: AppColors.textSecondary, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays >= 7) return '${dt.day}/${dt.month}/${dt.year % 100}';
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}

class _StarChip extends StatelessWidget {
  const _StarChip({required this.rating});
  final int rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.success,
        borderRadius: BorderRadius.circular(AppSizes.radiusXs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$rating',
            style: AppTextStyles.captionBold
                .copyWith(color: Colors.white, fontSize: 12),
          ),
          const SizedBox(width: 2),
          const Icon(Icons.star_rounded, color: Colors.white, size: 12),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md + 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Row(
        children: [
          const Icon(Icons.rate_review_rounded,
              color: AppColors.textMuted, size: 22),
          const SizedBox(width: AppSizes.sm + 2),
          Expanded(
            child: Text(
              'No reviews yet. Be the first to share your experience after your next order.',
              style: AppTextStyles.body
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 20, color: AppColors.textMuted),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(
              'Couldn\'t load reviews. $message',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Retry',
              style: AppTextStyles.bodyBold
                  .copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
