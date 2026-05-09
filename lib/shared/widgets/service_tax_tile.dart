import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/formatters.dart';

/// Bill-summary row for the optional service-tax charge.
///
/// Visually a highlighted band that **extends slightly past the bill
/// column edges** (a few px of overhang on each side) so the chrome
/// reads as a distinct card, *while the label and amount inside stay
/// pixel-aligned with the regular `_BillRow`s above and below*:
///
/// ```
///  Item total                                ₹2,500
///  Delivery fee                                FREE
/// ┌──────────────────────────────────────────────┐
/// │Service tax (5%)                          ₹152│  ← same x as siblings
/// │Optional · tap to skip                ●━━○   │
/// └──────────────────────────────────────────────┘
///  To pay                                  ₹3,354
/// ```
///
/// Trick: a `Stack` with `clipBehavior: Clip.none` lets a `Positioned`
/// layer (the bg + border) render `_overhang` px past the natural
/// column width on each side, while the content layer above it sits at
/// the column's natural left/right — so the text never moves.
///
/// Tap anywhere on the band to flip the toggle. When [included] is false
/// the amount renders as "—" (struck through) and the caption flips to a
/// positive savings note; the upstream total drops via the shared
/// `includeServiceTaxProvider`.
class ServiceTaxTile extends StatelessWidget {
  const ServiceTaxTile({
    super.key,
    required this.percent,
    required this.amount,
    required this.included,
    required this.onChanged,
  });

  final double percent;

  /// Amount the customer would pay if service tax IS included. Always
  /// passed in so the tile can show "you save ₹X" when the toggle is off.
  final double amount;

  final bool included;
  final ValueChanged<bool> onChanged;

  /// How far the bg + border peeks past the column edges on each side.
  static const double _overhang = 8;

  String _pct(double v) =>
      v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1);

  @override
  Widget build(BuildContext context) {
    // Match _BillRow's value styling exactly so the column stays consistent.
    final labelStyle = AppTextStyles.body.copyWith(fontSize: 13);
    final valueStyle = AppTextStyles.body.copyWith(
      color: included ? AppColors.textPrimary : AppColors.textMuted,
      fontSize: 13,
      fontWeight: FontWeight.w500,
      decoration: included ? null : TextDecoration.lineThrough,
      decorationColor: AppColors.textMuted,
    );

    final fillColor =
        included ? AppColors.accentSoft : AppColors.surfaceAlt;
    final borderColor = included
        ? AppColors.accent.withValues(alpha: 0.30)
        : AppColors.border;
    final radius = BorderRadius.circular(AppSizes.radiusSm);

    return Padding(
      // Breathing room separating the band from neighbouring rows.
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Layer 1: bg + border, peeking past the column edges ──
          Positioned(
            left: -_overhang,
            right: -_overhang,
            top: 0,
            bottom: 0,
            child: Material(
              color: Colors.transparent,
              borderRadius: radius,
              child: Ink(
                decoration: BoxDecoration(
                  color: fillColor,
                  borderRadius: radius,
                  border: Border.all(color: borderColor, width: 0.8),
                ),
                child: InkWell(
                  borderRadius: radius,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onChanged(!included);
                  },
                ),
              ),
            ),
          ),
          // ── Layer 2: content sits at the column's natural width ──
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top line — aligns with every bill row in the column.
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Service tax (${_pct(percent)}%)',
                        style: labelStyle,
                      ),
                    ),
                    Text(
                      included ? Formatters.currency(amount) : '—',
                      style: valueStyle,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Affordance line — caption + compact toggle, indented
                // to the same column edges as the line above.
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        included
                            ? 'Optional · tap to skip'
                            : 'Skipped · you save '
                                '${Formatters.currency(amount)}',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 11,
                          color: included
                              ? AppColors.accentDark
                              : AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 22,
                      child: Transform.scale(
                        scale: 0.78,
                        alignment: Alignment.centerRight,
                        child: Switch(
                          value: included,
                          onChanged: (v) {
                            HapticFeedback.selectionClick();
                            onChanged(v);
                          },
                          activeThumbColor: AppColors.primary,
                          activeTrackColor:
                              AppColors.primary.withValues(alpha: 0.45),
                          inactiveThumbColor: AppColors.surface,
                          inactiveTrackColor: AppColors.border,
                          trackOutlineColor: const WidgetStatePropertyAll(
                            Colors.transparent,
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
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
}
