import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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

  static const _slides = <_QuoteSlide>[
    _QuoteSlide(
      icon: PhosphorIconsDuotone.confetti,
      accent: AppColors.primary,
      eyebrow: 'WELCOME TO DAWAT',
      english: 'Every meal\ntells a story.',
      hindi: 'हर भोजन एक कहानी कहता है।',
      telugu: 'ప్రతి భోజనం ఒక కథ చెబుతుంది.',
    ),
    _QuoteSlide(
      icon: PhosphorIconsDuotone.forkKnife,
      accent: AppColors.accentDark,
      eyebrow: 'CRAFT  ·  शिल्प  ·  నైపుణ్యం',
      english: 'Crafted with love,\nserved with pride.',
      hindi: 'प्रेम से बनाया, गर्व से परोसा।',
      telugu: 'ప్రేమతో తయారు చేసి, గర్వంగా వడ్డిస్తాం.',
    ),
    _QuoteSlide(
      icon: PhosphorIconsDuotone.sparkle,
      accent: AppColors.primary,
      eyebrow: 'YOUR CELEBRATION',
      english: 'Your celebration,\nour craft.',
      hindi: 'आपका उत्सव, हमारा कौशल।',
      telugu: 'మీ వేడుక, మా నైపుణ్యం.',
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
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.lg,
                AppSizes.sm,
                AppSizes.lg,
                0,
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: Material(
                  color: AppColors.primarySoft,
                  shape: const StadiumBorder(),
                  child: InkWell(
                    onTap: _skip,
                    customBorder: const StadiumBorder(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.md,
                        vertical: AppSizes.xs,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Skip',
                            style: AppTextStyles.captionBold.copyWith(
                              color: AppColors.primary,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            PhosphorIconsBold.arrowRight,
                            size: 12,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
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

class _QuoteSlide extends StatelessWidget {
  const _QuoteSlide({
    required this.icon,
    required this.accent,
    required this.eyebrow,
    required this.english,
    required this.hindi,
    required this.telugu,
  });

  final IconData icon;
  final Color accent;
  final String eyebrow;
  final String english;
  final String hindi;
  final String telugu;

  @override
  Widget build(BuildContext context) {
    final englishStyle = GoogleFonts.playfairDisplay(
      fontSize: 34,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
      height: 1.1,
      letterSpacing: -0.5,
    );
    final hindiStyle = GoogleFonts.notoSerifDevanagari(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
      height: 1.4,
    );
    final teluguStyle = GoogleFonts.notoSerifTelugu(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
      height: 1.4,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSizes.lg),
          Center(
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 70, color: accent),
            )
                .animate()
                .scale(
                  begin: const Offset(0.7, 0.7),
                  end: const Offset(1, 1),
                  duration: 500.ms,
                  curve: Curves.easeOutBack,
                )
                .fadeIn(),
          ),
          const SizedBox(height: AppSizes.xl),
          Text(
            eyebrow,
            style: AppTextStyles.overline.copyWith(color: accent),
          )
              .animate()
              .fadeIn(delay: 80.ms, duration: 320.ms)
              .slideY(begin: 0.1, end: 0),
          const SizedBox(height: AppSizes.sm),
          Text(english, style: englishStyle)
              .animate()
              .fadeIn(delay: 140.ms, duration: 380.ms)
              .slideY(begin: 0.1, end: 0),
          const SizedBox(height: AppSizes.lg),
          Container(
            width: 40,
            height: 2,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ).animate().fadeIn(delay: 220.ms, duration: 260.ms),
          const SizedBox(height: AppSizes.md),
          Text(hindi, style: hindiStyle)
              .animate()
              .fadeIn(delay: 260.ms, duration: 380.ms)
              .slideY(begin: 0.08, end: 0),
          const SizedBox(height: AppSizes.sm),
          Text(telugu, style: teluguStyle)
              .animate()
              .fadeIn(delay: 360.ms, duration: 380.ms)
              .slideY(begin: 0.08, end: 0),
          const SizedBox(height: AppSizes.xl),
        ],
      ),
    );
  }
}
