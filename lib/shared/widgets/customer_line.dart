import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_text_styles.dart';

/// One-line "who is this booking from?" identifier for operator and
/// manager cards.
///
/// Shows the best available customer identifier in this priority order:
///   1. customer name
///   2. customer phone
///   3. customer email
///   4. short booking id (`#abcd1234`)
///
/// The chosen identifier is shown bold, with the short booking id
/// rendered as a muted secondary tag so the operator can still
/// disambiguate two same-named bookings.
class CustomerLine extends StatelessWidget {
  const CustomerLine({
    super.key,
    required this.bookingId,
    this.name,
    this.phone,
    this.email,
    this.compact = false,
  });

  final String bookingId;
  final String? name;
  final String? phone;
  final String? email;

  /// When true, omits the user icon and tightens spacing — used inside
  /// compact card rows.
  final bool compact;

  bool _has(String? s) => s != null && s.trim().isNotEmpty;

  String get _primary {
    if (_has(name)) return name!.trim();
    if (_has(phone)) return phone!.trim();
    if (_has(email)) return email!.trim();
    return _shortId;
  }

  String get _shortId =>
      bookingId.length >= 8 ? '#${bookingId.substring(0, 8)}' : '#$bookingId';

  bool get _hasNamedIdentifier =>
      _has(name) || _has(phone) || _has(email);

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 14.0 : 16.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          PhosphorIconsDuotone.user,
          size: iconSize,
          color: AppColors.textMuted,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            _primary,
            style: AppTextStyles.bodyBold.copyWith(
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Always show the short id as a secondary "ID #abcd1234" tag
        // when we already have a named identifier — disambiguates
        // duplicate-name bookings without looking like a random hash.
        if (_hasNamedIdentifier) ...[
          const SizedBox(width: AppSizes.sm),
          RichText(
            text: TextSpan(
              style: AppTextStyles.caption.copyWith(
                fontSize: 11,
                color: AppColors.textMuted,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              children: [
                const TextSpan(
                  text: 'ID ',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: _shortId),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
