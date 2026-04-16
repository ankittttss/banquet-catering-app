import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/formatters.dart';

/// Invoice-style label + amount row.
/// Set [emphasis] = true for subtotal/total lines.
class PriceRow extends StatelessWidget {
  const PriceRow({
    super.key,
    required this.label,
    required this.amount,
    this.emphasis = false,
    this.isTotal = false,
    this.helper,
  });

  final String label;
  final double amount;
  final bool emphasis;
  final bool isTotal;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    if (isTotal) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: AppTextStyles.heading2
                      .copyWith(color: AppColors.textPrimary)),
            ),
            Text(Formatters.currency(amount),
                style: AppTextStyles.totalAmount),
          ],
        ),
      );
    }

    final labelStyle = emphasis
        ? AppTextStyles.bodyBold
        : AppTextStyles.body.copyWith(color: AppColors.textSecondary);
    final amountStyle =
        emphasis ? AppTextStyles.bodyBold : AppTextStyles.price;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: labelStyle),
                if (helper != null) ...[
                  const SizedBox(height: 2),
                  Text(helper!, style: AppTextStyles.caption),
                ],
              ],
            ),
          ),
          Text(Formatters.currency(amount), style: amountStyle),
        ],
      ),
    );
  }
}
