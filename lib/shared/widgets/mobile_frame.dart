import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// On wide screens (web/desktop) shows a phone-sized frame, centered.
/// On narrow screens just renders the child full-bleed.
class MobileFrame extends StatelessWidget {
  const MobileFrame({super.key, required this.child});

  final Widget child;

  static const double _maxWidth = 440;
  static const double _maxHeight = 900;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final useFrame = kIsWeb && size.width > _maxWidth + 80;
    if (!useFrame) return child;

    return ColoredBox(
      color: AppColors.surfaceAlt,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Container(
            width: _maxWidth,
            height: size.height > _maxHeight ? _maxHeight : size.height - 40,
            decoration: BoxDecoration(
              color: AppColors.pageBg,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  blurRadius: 40,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                size: Size(
                  _maxWidth,
                  size.height > _maxHeight ? _maxHeight : size.height - 40,
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
