import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/review.dart';
import '../../../shared/providers/auth_providers.dart';
import '../../../shared/providers/repositories_providers.dart';
import '../../../shared/providers/review_providers.dart';

/// Bottom sheet that lets a user rate a restaurant for a specific order.
/// Pre-fills from any existing review so re-opening the sheet edits rather
/// than creating a duplicate.
Future<Review?> showRateOrderSheet(
  BuildContext context, {
  required String restaurantId,
  required String restaurantName,
  String? orderId,
  Review? existing,
}) {
  return showModalBottomSheet<Review?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _RateOrderSheet(
      restaurantId: restaurantId,
      restaurantName: restaurantName,
      orderId: orderId,
      existing: existing,
    ),
  );
}

class _RateOrderSheet extends ConsumerStatefulWidget {
  const _RateOrderSheet({
    required this.restaurantId,
    required this.restaurantName,
    required this.orderId,
    required this.existing,
  });

  final String restaurantId;
  final String restaurantName;
  final String? orderId;
  final Review? existing;

  @override
  ConsumerState<_RateOrderSheet> createState() => _RateOrderSheetState();
}

class _RateOrderSheetState extends ConsumerState<_RateOrderSheet> {
  late int _rating = widget.existing?.rating ?? 0;
  late final TextEditingController _comment =
      TextEditingController(text: widget.existing?.comment ?? '');
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      setState(() => _error = 'Please sign in to leave a review.');
      return;
    }
    if (_rating < 1) {
      setState(() => _error = 'Tap a star to pick a rating.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final review = await ref.read(reviewRepositoryProvider).submit(
            id: widget.existing?.id,
            userId: userId,
            restaurantId: widget.restaurantId,
            orderId: widget.orderId,
            rating: _rating,
            comment: _comment.text.trim().isEmpty
                ? null
                : _comment.text.trim(),
          );
      ref.invalidate(restaurantReviewsProvider(widget.restaurantId));
      if (widget.orderId != null) {
        ref.invalidate(myReviewForOrderProvider(widget.orderId!));
      }
      if (!mounted) return;
      Navigator.of(context).pop(review);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Could not submit: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.pagePadding,
            AppSizes.md,
            AppSizes.pagePadding,
            AppSizes.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.md),
              Text(
                widget.existing == null
                    ? 'How was your experience?'
                    : 'Update your review',
                style: AppTextStyles.heading1,
              ),
              const SizedBox(height: 4),
              Text(
                widget.restaurantName,
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSizes.lg),
              _StarRow(
                rating: _rating,
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  setState(() => _rating = v);
                },
              ),
              const SizedBox(height: AppSizes.md),
              TextField(
                controller: _comment,
                maxLines: 4,
                maxLength: 500,
                style: AppTextStyles.body,
                decoration: InputDecoration(
                  hintText: 'Share a few words (optional)',
                  hintStyle: AppTextStyles.body
                      .copyWith(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surfaceAlt,
                  contentPadding: const EdgeInsets.all(AppSizes.md),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSizes.sm),
                Text(
                  _error!,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.error),
                ),
              ],
              const SizedBox(height: AppSizes.sm),
              SizedBox(
                width: double.infinity,
                height: AppSizes.buttonHeight,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusMd),
                    ),
                  ),
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.4,
                          ),
                        )
                      : Text(
                          widget.existing == null
                              ? 'Submit review'
                              : 'Update review',
                          style: AppTextStyles.buttonLabel
                              .copyWith(color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating, required this.onChanged});
  final int rating;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final filled = i < rating;
        return IconButton(
          iconSize: 36,
          onPressed: () => onChanged(i + 1),
          icon: Icon(
            filled ? Icons.star_rounded : Icons.star_outline_rounded,
            color: filled ? AppColors.accent : AppColors.textMuted,
          ),
        );
      }),
    );
  }
}
