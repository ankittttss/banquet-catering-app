import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
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

// ───────────────────────── Slide data ─────────────────────────

class _Slide {
  const _Slide({
    required this.audience,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.fallbackTint,
  });

  final String audience;
  final String title;
  final String subtitle;
  final String imageUrl;
  final Color fallbackTint;
}

// Image URLs via Unsplash CDN. If a URL ever 404s or you want different
// art direction, swap them — the errorBuilder falls back to a tinted
// gradient so the layout stays intact either way.
const _slides = <_Slide>[
  _Slide(
    audience: 'For the host',
    title: 'A banquet,\nplanned in minutes',
    subtitle:
        'Pick a tier, browse kitchens, lock the venue. Your event scaffolded for any guest count.',
    imageUrl:
        'https://images.unsplash.com/photo-1519225421980-715cb0215aed?auto=format&fit=crop&w=900&q=80',
    fallbackTint: AppColors.accentSoft,
  ),
  _Slide(
    audience: 'Multi-vendor cart',
    title: 'Mix dishes from\nmany kitchens',
    subtitle:
        'Starters from one kitchen, biryani from another. We coordinate prep and pickup.',
    imageUrl:
        'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&w=900&q=80',
    fallbackTint: AppColors.catBlueLt,
  ),
  _Slide(
    audience: 'Honest totals',
    title: 'Per-guest pricing,\nall in',
    subtitle:
        'Food, banquet, service, water, GST — every line scaled to your guest count, no surprises.',
    imageUrl:
        'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?auto=format&fit=crop&w=900&q=80',
    fallbackTint: AppColors.catGoldLt,
  ),
];

// ───────────────────────── Onboarding screen ─────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _page = 0;

  Future<void> _next() async {
    HapticFeedback.selectionClick();
    if (_page < _slides.length - 1) {
      await _ctrl.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    } else {
      await markOnboardingSeen();
      if (!mounted) return;
      context.go(AppRoutes.login);
    }
  }

  Future<void> _back() async {
    if (_page == 0) return;
    HapticFeedback.selectionClick();
    await _ctrl.previousPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _skip() async {
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
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TopBar(onSkip: _skip),
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _SlideView(slide: _slides[i]),
              ),
            ),
            _BottomNav(
              total: _slides.length,
              index: _page,
              isLast: _page == _slides.length - 1,
              onNext: _next,
              onBack: _back,
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Top bar ─────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onSkip});
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          Text(
            'Dawat',
            style: GoogleFonts.instrumentSerif(
              fontSize: 26,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w400,
              color: AppColors.primary,
              letterSpacing: -0.4,
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: onSkip,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                'Skip',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Slide ─────────────────────────

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});
  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    // SingleChildScrollView lets the slide content scroll on tight
    // viewports (the hero image is a 1:1 aspect-ratio square plus a
    // multi-line title + subtitle — easily exceeds the PageView's
    // allotted height on smaller screens, causing a ~30px overflow).
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroImage(slide: slide),
          const SizedBox(height: 28),
          Text(
            slide.title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -0.6,
              color: AppColors.textPrimary,
            ),
          )
              .animate()
              .fadeIn(duration: 360.ms, delay: 80.ms)
              .slideY(begin: 0.05, end: 0, duration: 360.ms, delay: 80.ms),
          const SizedBox(height: 12),
          Text(
            slide.subtitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ).animate().fadeIn(duration: 360.ms, delay: 160.ms),
        ],
      ),
    );
  }
}

// ───────────────────────── Hero image ─────────────────────────

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.slide});
  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: slide.imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => _Fallback(tint: slide.fallbackTint),
              errorWidget: (_, __, ___) =>
                  _Fallback(tint: slide.fallbackTint),
              fadeInDuration: const Duration(milliseconds: 240),
            ),
            // Subtle bottom-left scrim so the audience tag stays legible
            // regardless of the underlying photo's brightness.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.55, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.36),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 18,
              bottom: 18,
              child: Text(
                slide.audience.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.tint});
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tint, tint.withValues(alpha: 0.6)],
        ),
      ),
    );
  }
}

// ───────────────────────── Bottom nav ─────────────────────────

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.total,
    required this.index,
    required this.isLast,
    required this.onNext,
    required this.onBack,
  });

  final int total;
  final int index;
  final bool isLast;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Progress bar — 3 segments, full-width pills.
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              children: [
                for (int i = 0; i < total; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                      height: 4,
                      decoration: BoxDecoration(
                        color: i == index
                            ? AppColors.primary
                            : AppColors.primary.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Row(
            children: [
              if (index > 0) ...[
                _BackButton(onTap: onBack),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: FilledButton(
                    onPressed: onNext,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isLast ? 'Get started' : 'Next',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                        if (!isLast) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 22,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.chevron_left_rounded,
          size: 26,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
