import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/primary_button.dart';

class OrderSuccessScreen extends StatelessWidget {
  const OrderSuccessScreen({super.key, required this.orderId});

  final String orderId;

  String get _shortId => orderId.length > 8
      ? orderId.substring(0, 8).toUpperCase()
      : orderId.toUpperCase();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      padded: false,
      body: Stack(
        children: [
          // Confetti background — gold sparkles cascading
          const _ConfettiLayer(),
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
              child: Column(
                children: [
                  const Spacer(),
                  _Hero(),
                  const SizedBox(height: AppSizes.xl),
                  Text('Booking requested!',
                          style: AppTextStyles.display.copyWith(fontSize: 30))
                      .animate()
                      .fadeIn(delay: 320.ms)
                      .slideY(begin: 0.2, end: 0, duration: 360.ms),
                  const SizedBox(height: AppSizes.xs),
                  Text('Your booking reference',
                          style: AppTextStyles.bodyMuted)
                      .animate()
                      .fadeIn(delay: 440.ms),
                  const SizedBox(height: AppSizes.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.lg,
                      vertical: AppSizes.sm,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusPill),
                    ),
                    child: Text(
                      '#$_shortId',
                      style: AppTextStyles.heading1.copyWith(
                          color: AppColors.primary, letterSpacing: 1.5),
                    ),
                  ).animate().fadeIn(delay: 520.ms).scale(
                        begin: const Offset(0.85, 0.85),
                        end: const Offset(1, 1),
                        duration: 360.ms,
                      ),
                  const SizedBox(height: AppSizes.xl),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSizes.lg),
                    child: Text(
                      'Our team will reach out shortly to confirm your event and share payment details.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMuted,
                    ),
                  ).animate().fadeIn(delay: 620.ms),
                  const Spacer(),
                  _Actions(orderId: _shortId),
                  const SizedBox(height: AppSizes.lg),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.3),
          width: 3,
        ),
      ),
      alignment: Alignment.center,
      child: const Icon(
        PhosphorIconsFill.checkCircle,
        color: AppColors.success,
        size: 86,
      ),
    )
        .animate()
        .scale(
          begin: const Offset(0.4, 0.4),
          end: const Offset(1, 1),
          duration: 540.ms,
          curve: Curves.elasticOut,
        )
        .fadeIn();
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.orderId});
  final String orderId;

  void _share(BuildContext context) {
    HapticFeedback.lightImpact();
    final text = 'My catering booking is confirmed on Dawat — reference #$orderId';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Booking details copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _share(context),
                icon: const Icon(PhosphorIconsBold.share, size: 18),
                label: const Text('Share'),
                style: OutlinedButton.styleFrom(
                  minimumSize:
                      const Size.fromHeight(AppSizes.buttonHeight),
                ),
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            Expanded(
              flex: 2,
              child: PrimaryButton(
                label: 'View my events',
                icon: PhosphorIconsBold.calendarCheck,
                onPressed: () => context.go(AppRoutes.myEvents),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.sm),
        TextButton(
          onPressed: () => context.go(AppRoutes.userHome),
          child: Text('Back to home',
              style: AppTextStyles.bodyBold
                  .copyWith(color: AppColors.textSecondary)),
        ),
      ],
    ).animate().fadeIn(delay: 720.ms).slideY(begin: 0.1, end: 0);
  }
}

// ---------------------------------------------------------------------------
// Confetti background — sparkles falling + gold accents
// ---------------------------------------------------------------------------

class _ConfettiLayer extends StatelessWidget {
  const _ConfettiLayer();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          for (final c in _confettiBits)
            Positioned(
              left: c.left,
              top: c.top,
              child: Icon(
                c.icon,
                size: c.size,
                color: c.color.withValues(alpha: c.opacity),
              )
                  .animate(
                    onPlay: (ctrl) => ctrl.repeat(period: 3.seconds),
                  )
                  .moveY(
                    begin: 0,
                    end: 80,
                    duration: 3.seconds,
                    curve: Curves.easeInOut,
                  )
                  .fadeIn(duration: 600.ms)
                  .then(delay: 1500.ms)
                  .fadeOut(duration: 600.ms),
            ),
        ],
      ),
    );
  }
}

class _ConfettiBit {
  const _ConfettiBit({
    required this.left,
    required this.top,
    required this.size,
    required this.icon,
    required this.color,
    required this.opacity,
  });
  final double left;
  final double top;
  final double size;
  final IconData icon;
  final Color color;
  final double opacity;
}

const _confettiBits = [
  _ConfettiBit(left: 30, top: 80, size: 14, icon: PhosphorIconsFill.sparkle,
      color: AppColors.accent, opacity: 0.7),
  _ConfettiBit(left: 90, top: 140, size: 10, icon: PhosphorIconsFill.star,
      color: AppColors.primary, opacity: 0.5),
  _ConfettiBit(left: 200, top: 100, size: 16, icon: PhosphorIconsFill.sparkle,
      color: AppColors.accentDark, opacity: 0.6),
  _ConfettiBit(left: 280, top: 180, size: 12, icon: PhosphorIconsFill.star,
      color: AppColors.accent, opacity: 0.6),
  _ConfettiBit(left: 50, top: 220, size: 8, icon: PhosphorIconsFill.heart,
      color: AppColors.primary, opacity: 0.45),
  _ConfettiBit(left: 250, top: 260, size: 10, icon: PhosphorIconsFill.sparkle,
      color: AppColors.accent, opacity: 0.5),
  _ConfettiBit(left: 150, top: 320, size: 14, icon: PhosphorIconsFill.star,
      color: AppColors.accentDark, opacity: 0.55),
  _ConfettiBit(left: 320, top: 380, size: 9, icon: PhosphorIconsFill.heart,
      color: AppColors.primary, opacity: 0.5),
  _ConfettiBit(left: 20, top: 420, size: 12, icon: PhosphorIconsFill.sparkle,
      color: AppColors.accent, opacity: 0.6),
  _ConfettiBit(left: 290, top: 480, size: 10, icon: PhosphorIconsFill.star,
      color: AppColors.accent, opacity: 0.55),
];
