import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/router/app_routes.dart';

const _onboardingSeenKey = 'dawat.onboarding.seen.v1';

Future<bool> hasSeenOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_onboardingSeenKey) ?? false;
}

Future<void> markOnboardingSeen() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_onboardingSeenKey, true);
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _page = 0;

  final _slides = const [
    _Slide(
      icon: PhosphorIconsDuotone.confetti,
      title: 'Plan any event,\nany size.',
      subtitle:
          'Weddings, birthdays, corporate lunches — pick an event type and we\'ll handle the rest.',
      accent: AppColors.primary,
    ),
    _Slide(
      icon: PhosphorIconsDuotone.forkKnife,
      title: 'Curated menus\nfrom top chefs.',
      subtitle:
          'Multi-cuisine thalis, live counters, plated courses — mix and match to your taste.',
      accent: AppColors.accentDark,
    ),
    _Slide(
      icon: PhosphorIconsDuotone.sparkle,
      title: 'Setup, service,\ndelivered.',
      subtitle:
          'Buffet setup, trained service staff, and on-time delivery — included in every booking.',
      accent: AppColors.primary,
    ),
  ];

  void _next() async {
    HapticFeedback.selectionClick();
    if (_page < _slides.length - 1) {
      _ctrl.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      await markOnboardingSeen();
      if (!mounted) return;
      context.go(AppRoutes.login);
    }
  }

  void _skip() async {
    await markOnboardingSeen();
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _skip,
                child: Text('Skip',
                    style: AppTextStyles.bodyBold
                        .copyWith(color: AppColors.textSecondary)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _slides[i],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSizes.pagePadding),
              child: Row(
                children: [
                  Row(
                    children: [
                      for (int i = 0; i < _slides.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 260),
                          margin:
                              const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _page ? 22 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _page
                                ? AppColors.primary
                                : AppColors.border,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _next,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.xl,
                        vertical: AppSizes.md,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _page == _slides.length - 1
                              ? 'Get started'
                              : 'Next',
                          style: AppTextStyles.buttonLabel
                              .copyWith(color: Colors.white),
                        ),
                        const SizedBox(width: AppSizes.xs),
                        const Icon(PhosphorIconsBold.arrowRight,
                            color: Colors.white, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 90, color: accent),
          )
              .animate()
              .scale(
                begin: const Offset(0.7, 0.7),
                end: const Offset(1, 1),
                duration: 500.ms,
                curve: Curves.easeOutBack,
              )
              .fadeIn(),
          const SizedBox(height: AppSizes.xxl),
          Text(title,
                  style: AppTextStyles.display
                      .copyWith(fontSize: 36, height: 1.1))
              .animate()
              .fadeIn(delay: 120.ms, duration: 380.ms)
              .slideY(begin: 0.1, end: 0),
          const SizedBox(height: AppSizes.md),
          Text(subtitle, style: AppTextStyles.bodyMuted)
              .animate()
              .fadeIn(delay: 260.ms, duration: 380.ms),
        ],
      ),
    );
  }
}
