import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

// ───────────────────────── Translations ─────────────────────────

enum _Lang {
  tamil,
  hindi,
  telugu,
  bengali,
  kannada,
  malayalam,
  punjabi,
  marathi,
}

class _LangMeta {
  const _LangMeta(this.label, this.buildStyle);
  final String label;
  final TextStyle Function(double fontSize, Color color) buildStyle;
}

final Map<_Lang, _LangMeta> _langMeta = {
  _Lang.tamil: _LangMeta(
    'தமிழ்',
    (s, c) => GoogleFonts.notoSerifTamil(
      fontSize: s,
      fontWeight: FontWeight.w300,
      color: c,
      height: 1.4,
    ),
  ),
  _Lang.hindi: _LangMeta(
    'हिन्दी',
    (s, c) => GoogleFonts.notoSerifDevanagari(
      fontSize: s,
      fontWeight: FontWeight.w400,
      color: c,
      height: 1.4,
    ),
  ),
  _Lang.telugu: _LangMeta(
    'తెలుగు',
    (s, c) => GoogleFonts.notoSerifTelugu(
      fontSize: s,
      fontWeight: FontWeight.w400,
      color: c,
      height: 1.4,
    ),
  ),
  _Lang.bengali: _LangMeta(
    'বাংলা',
    (s, c) => GoogleFonts.notoSerifBengali(
      fontSize: s,
      fontWeight: FontWeight.w400,
      color: c,
      height: 1.4,
    ),
  ),
  _Lang.kannada: _LangMeta(
    'ಕನ್ನಡ',
    (s, c) => GoogleFonts.notoSerifKannada(
      fontSize: s,
      fontWeight: FontWeight.w400,
      color: c,
      height: 1.4,
    ),
  ),
  _Lang.malayalam: _LangMeta(
    'മലയാളം',
    (s, c) => GoogleFonts.notoSerifMalayalam(
      fontSize: s,
      fontWeight: FontWeight.w400,
      color: c,
      height: 1.4,
    ),
  ),
  _Lang.punjabi: _LangMeta(
    'ਪੰਜਾਬੀ',
    (s, c) => GoogleFonts.notoSerifGurmukhi(
      fontSize: s,
      fontWeight: FontWeight.w400,
      color: c,
      height: 1.4,
    ),
  ),
  _Lang.marathi: _LangMeta(
    'मराठी',
    (s, c) => GoogleFonts.notoSerifDevanagari(
      fontSize: s,
      fontWeight: FontWeight.w400,
      color: c,
      height: 1.4,
    ),
  ),
};

// ───────────────────────── Slide palette ─────────────────────────

class _SlideTheme {
  const _SlideTheme({
    required this.bgGradient,
    required this.primary,
    required this.tagLine,
    required this.headlineEm,
    required this.textPrimary,
    required this.langText,
    required this.glowAlign,
    required this.sparkleColor,
  });

  final List<Color> bgGradient;
  final Color primary;
  final Color tagLine;
  final Color headlineEm;
  final Color textPrimary;
  final Color langText;
  final Alignment glowAlign;
  final Color sparkleColor;
}

const _s1 = _SlideTheme(
  bgGradient: [Color(0xFFFFF5F0), Color(0xFFFFF0EC), Color(0xFFFEEAE4)],
  primary: Color(0xFFE23744),
  tagLine: Color(0xFFE23744),
  headlineEm: Color(0xFFC12E3A),
  textPrimary: Color(0xFF1A1A1A),
  langText: Color(0xFF3D2020),
  glowAlign: Alignment(-0.7, -0.7),
  sparkleColor: Color(0xFFE23744),
);

const _s2 = _SlideTheme(
  bgGradient: [Color(0xFFFFFBF2), Color(0xFFFFF8EB), Color(0xFFFFF3DA)],
  primary: Color(0xFFC4922A),
  tagLine: Color(0xFFA07A1E),
  headlineEm: Color(0xFF9E7520),
  textPrimary: Color(0xFF1A1A1A),
  langText: Color(0xFF3D3018),
  glowAlign: Alignment(0.7, -0.6),
  sparkleColor: Color(0xFFC4922A),
);

const _s3 = _SlideTheme(
  bgGradient: [Color(0xFFFFF5F3), Color(0xFFFFEDEA), Color(0xFFFFE4DF)],
  primary: Color(0xFFE23744),
  tagLine: Color(0xFFE23744),
  headlineEm: Color(0xFFC12E3A),
  textPrimary: Color(0xFF1A1A1A),
  langText: Color(0xFF3D2020),
  glowAlign: Alignment(-0.3, 0.2),
  sparkleColor: Color(0xFFD44050),
);

// ───────────────────────── Slide data ─────────────────────────

class _SlideData {
  const _SlideData({
    required this.theme,
    required this.tagLine,
    required this.headlineLead,
    required this.headlineEm,
    required this.translations,
    required this.orbit1,
    required this.orbit2,
    required this.center,
    required this.sparkles,
    required this.orbit1Duration,
    required this.orbit2Duration,
    required this.centerDuration,
  });

  final _SlideTheme theme;
  final String tagLine;
  /// Text that comes before the italic emphasis word.
  final String headlineLead;
  /// Italic emphasis at the end of the headline (e.g. "story.").
  final String headlineEm;
  final List<MapEntry<_Lang, String>> translations;

  /// 4 emojis positioned at the four compass points of orbit 1.
  final List<String> orbit1;
  /// 2 emojis on orbit 2 (counter-rotating, slower).
  final List<String> orbit2;
  /// The central spinning emoji.
  final String center;
  /// 7 sparkle positions (Alignment-style coords in [-1,1]).
  final List<Alignment> sparkles;
  final Duration orbit1Duration;
  final Duration orbit2Duration;
  final Duration centerDuration;
}

final _slides = <_SlideData>[
  _SlideData(
    theme: _s1,
    tagLine: 'Welcome to Dawat',
    headlineLead: 'Every meal\ntells a ',
    headlineEm: 'story.',
    translations: const [
      MapEntry(_Lang.tamil,
          'ஒவ்வொரு உணவும் ஒரு கதையைச் சொல்கிறது.'),
      MapEntry(_Lang.hindi, 'हर खाने की अपनी एक कहानी होती है।'),
      MapEntry(_Lang.telugu, 'ప్రతి భోజనం ఒక కథ చెబుతుంది.'),
      MapEntry(_Lang.bengali, 'প্রতিটি খাবার একটি গল্প বলে।'),
      MapEntry(_Lang.kannada, 'ಪ್ರತಿ ಊಟವೂ ಒಂದು ಕಥೆ ಹೇಳುತ್ತದೆ.'),
      MapEntry(_Lang.malayalam, 'ഓരോ ഭക്ഷണവും ഒരു കഥ പറയുന്നു.'),
      MapEntry(_Lang.punjabi, 'ਹਰ ਖਾਣਾ ਇੱਕ ਕਹਾਣੀ ਸੁਣਾਉਂਦਾ ਹੈ।'),
      MapEntry(_Lang.marathi, 'प्रत्येक जेवण एक कथा सांगतं.'),
    ],
    orbit1: const ['🎉', '🎁', '✨', '🎊'],
    orbit2: const ['🥂', '🎂'],
    center: '🎉',
    sparkles: const [
      Alignment(-0.72, -0.6),
      Alignment(0.6, -0.8),
      Alignment(-0.8, 0.1),
      Alignment(0.76, 0.05),
      Alignment(-0.44, 0.5),
      Alignment(-0.04, -0.5),
      Alignment(0.5, 0.4),
    ],
    orbit1Duration: Duration(seconds: 16),
    orbit2Duration: Duration(seconds: 25),
    centerDuration: Duration(seconds: 24),
  ),
  _SlideData(
    theme: _s2,
    tagLine: 'Crafted with love',
    headlineLead: 'Crafted with love,\nserved with ',
    headlineEm: 'pride.',
    translations: const [
      MapEntry(_Lang.bengali, 'ভালোবাসায় তৈরি, গর্বে পরিবেশিত।'),
      MapEntry(_Lang.hindi, 'प्यार से बना, गर्व से परोसा।'),
      MapEntry(_Lang.telugu, 'ప్రేమతో తయారు, గర్వంగా వడ్డించబడింది.'),
      MapEntry(_Lang.tamil,
          'அன்போடு செய்யப்பட்டது, பெருமையுடன் பரிமாறப்பட்டது.'),
      MapEntry(_Lang.kannada,
          'ಪ್ರೀತಿಯಿಂದ ತಯಾರಿಸಲಾಗಿದೆ, ಹೆಮ್ಮೆಯಿಂದ ಬಡಿಸಲಾಗಿದೆ.'),
      MapEntry(_Lang.malayalam,
          'സ്നേഹത്തോടെ ഉണ്ടാക്കിയത്, അഭിമാനത്തോടെ വിളമ്പിയത്.'),
      MapEntry(_Lang.punjabi, 'ਪਿਆਰ ਨਾਲ ਬਣਾਇਆ, ਮਾਣ ਨਾਲ ਪਰੋਸਿਆ।'),
      MapEntry(_Lang.marathi, 'प्रेमाने बनवलेलं, अभिमानाने वाढलेलं.'),
    ],
    orbit1: const ['🍛', '🍲', '🫕', '🥘'],
    orbit2: const ['🧁', '🍽️'],
    center: '🍴',
    sparkles: const [
      Alignment(-0.64, -0.55),
      Alignment(0.64, -0.75),
      Alignment(-0.76, 0.1),
      Alignment(0.72, -0.0),
      Alignment(-0.2, -0.3),
      Alignment(0.4, 0.4),
      Alignment(-0.3, 0.6),
    ],
    orbit1Duration: Duration(seconds: 18),
    orbit2Duration: Duration(seconds: 20),
    centerDuration: Duration(seconds: 24),
  ),
  _SlideData(
    theme: _s3,
    tagLine: 'Your celebration',
    headlineLead: 'Your celebration,\nour ',
    headlineEm: 'craft.',
    translations: const [
      MapEntry(_Lang.punjabi, 'ਤੁਹਾਡਾ ਜਸ਼ਨ, ਸਾਡਾ ਹੁਨਰ।'),
      MapEntry(_Lang.hindi, 'आपका जश्न, हमारी कला।'),
      MapEntry(_Lang.telugu, 'మీ పండుగ, మా నైపుణ్యం.'),
      MapEntry(_Lang.tamil, 'உங்கள் கொண்டாட்டம், எங்கள் கைவண்ணம்.'),
      MapEntry(_Lang.bengali, 'আপনার উৎসব, আমাদের শিল্প।'),
      MapEntry(_Lang.kannada, 'ನಿಮ್ಮ ಆಚರಣೆ, ನಮ್ಮ ಕರಕುಶಲ.'),
      MapEntry(_Lang.malayalam, 'നിങ്ങളുടെ ആഘോഷം, ഞങ്ങളുടെ കരവിരുത്.'),
      MapEntry(_Lang.marathi, 'तुमचा उत्सव, आमची कला.'),
    ],
    orbit1: const ['🎊', '🎶', '🪔', '💐'],
    orbit2: const ['🌟', '🎇'],
    center: '⭐',
    sparkles: const [
      Alignment(-0.68, -0.5),
      Alignment(0.64, -0.7),
      Alignment(-0.8, 0.2),
      Alignment(0.76, 0.0),
      Alignment(-0.12, -0.36),
      Alignment(0.44, 0.4),
      Alignment(-0.84, -0.16),
    ],
    orbit1Duration: Duration(seconds: 18),
    orbit2Duration: Duration(seconds: 26),
    centerDuration: Duration(seconds: 24),
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

  void _next() async {
    HapticFeedback.selectionClick();
    if (_page < _slides.length - 1) {
      _ctrl.nextPage(
        duration: const Duration(milliseconds: 380),
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
      body: PageView.builder(
        controller: _ctrl,
        itemCount: _slides.length,
        onPageChanged: (i) => setState(() => _page = i),
        itemBuilder: (_, i) => _SlideView(
          data: _slides[i],
          index: i,
          total: _slides.length,
          onSkip: _skip,
          onNext: _next,
        ),
      ),
    );
  }
}

// ───────────────────────── Slide ─────────────────────────

class _SlideView extends StatelessWidget {
  const _SlideView({
    required this.data,
    required this.index,
    required this.total,
    required this.onSkip,
    required this.onNext,
  });

  final _SlideData data;
  final int index;
  final int total;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final t = data.theme;
    final isLast = index == total - 1;

    return Stack(
      children: [
        // Background gradient.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: const Alignment(0, -1),
              end: const Alignment(0, 1),
              stops: const [0.0, 0.35, 1.0],
              colors: t.bgGradient,
            ),
          ),
          child: const SizedBox.expand(),
        ),

        // Ambient glow.
        Positioned.fill(
          child: IgnorePointer(
            child: Align(
              alignment: t.glowAlign,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.primary.withValues(alpha: 0.18),
                ),
              ),
            ),
          ),
        ),

        // Sparkles.
        for (int i = 0; i < data.sparkles.length; i++)
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: data.sparkles[i],
                child: _Sparkle(
                  color: t.sparkleColor,
                  delay: Duration(milliseconds: 200 * i),
                ),
              ),
            ),
          ),

        SafeArea(
          child: Column(
            children: [
              // Top row: Skip.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _SkipButton(theme: t, onTap: onSkip),
                ),
              ),

              // Scene: plate + orbits.
              SizedBox(
                height: 360,
                child: Center(
                  child: _Plate(data: data),
                ),
              ),

              // Bottom content.
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(28, 0, 28, 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TagLine(text: data.tagLine, theme: t),
                      const SizedBox(height: 12),
                      _Headline(data: data),
                      const SizedBox(height: 20),
                      _LangTicker(data: data),
                      const SizedBox(height: 24),
                      _NavRow(
                        total: total,
                        index: index,
                        isLast: isLast,
                        theme: t,
                        onNext: onNext,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── Skip button ─────────────────────────

class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.theme, required this.onTap});
  final _SlideTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.primary.withValues(alpha: 0.08),
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Text(
            'Skip →',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.tagLine,
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Sparkle ─────────────────────────

class _Sparkle extends StatelessWidget {
  const _Sparkle({required this.color, required this.delay});
  final Color color;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .fadeIn(duration: 1200.ms, delay: delay)
        .scale(
          begin: const Offset(0.7, 0.7),
          end: const Offset(1.3, 1.3),
          duration: 2400.ms,
          curve: Curves.easeInOut,
        );
  }
}

// ───────────────────────── Plate ─────────────────────────

class _Plate extends StatefulWidget {
  const _Plate({required this.data});
  final _SlideData data;

  @override
  State<_Plate> createState() => _PlateState();
}

class _PlateState extends State<_Plate>
    with TickerProviderStateMixin {
  late final AnimationController _o1;
  late final AnimationController _o2;
  late final AnimationController _center;

  @override
  void initState() {
    super.initState();
    _o1 = AnimationController(
      vsync: this,
      duration: widget.data.orbit1Duration,
    )..repeat();
    _o2 = AnimationController(
      vsync: this,
      duration: widget.data.orbit2Duration,
    )..repeat();
    _center = AnimationController(
      vsync: this,
      duration: widget.data.centerDuration,
    )..repeat();
  }

  @override
  void dispose() {
    _o1.dispose();
    _o2.dispose();
    _center.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.data.theme;
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer circle backdrop.
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: t.primary.withValues(alpha: 0.10),
                width: 2,
              ),
              gradient: RadialGradient(
                colors: [
                  t.primary.withValues(alpha: 0.04),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.7],
              ),
            ),
          ),

          // Orbit 1 — 4 dots at compass points, forward rotation.
          RotationTransition(
            turns: _o1,
            child: SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                children: [
                  _orbitDot(widget.data.orbit1[0],
                      alignment: const Alignment(0, -1.09)),
                  _orbitDot(widget.data.orbit1[1],
                      alignment: const Alignment(1.13, 0)),
                  _orbitDot(widget.data.orbit1[2],
                      alignment: const Alignment(0, 1.09)),
                  _orbitDot(widget.data.orbit1[3],
                      alignment: const Alignment(-1.13, 0)),
                ],
              ),
            ),
          ),

          // Orbit 2 — 2 dots at diagonals, reverse rotation.
          RotationTransition(
            turns: ReverseAnimation(_o2),
            child: SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                children: [
                  _orbitDot(widget.data.orbit2[0],
                      alignment: const Alignment(-0.78, -0.78)),
                  _orbitDot(widget.data.orbit2[1],
                      alignment: const Alignment(0.78, 0.78)),
                ],
              ),
            ),
          ),

          // Inner circle.
          Container(
            width: 136,
            height: 136,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: t.primary.withValues(alpha: 0.08),
                width: 1.4,
              ),
            ),
            alignment: Alignment.center,
            child: RotationTransition(
              turns: ReverseAnimation(_center),
              child: RotationTransition(
                turns: _center,
                child: Text(
                  widget.data.center,
                  style: const TextStyle(fontSize: 60),
                ),
              ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 600.ms, curve: Curves.easeOut)
        .scale(
          begin: const Offset(0.65, 0.65),
          end: const Offset(1, 1),
          duration: 700.ms,
          curve: Curves.easeOutBack,
        );
  }

  Widget _orbitDot(String emoji, {required Alignment alignment}) {
    return Align(
      alignment: alignment,
      child: Text(
        emoji,
        style: const TextStyle(fontSize: 26),
      ),
    );
  }
}

// ───────────────────────── Tag line ─────────────────────────

class _TagLine extends StatelessWidget {
  const _TagLine({required this.text, required this.theme});
  final String text;
  final _SlideTheme theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 2,
          decoration: BoxDecoration(
            color: theme.tagLine,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text.toUpperCase(),
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.5,
            color: theme.tagLine,
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── Headline ─────────────────────────

class _Headline extends StatelessWidget {
  const _Headline({required this.data});
  final _SlideData data;

  @override
  Widget build(BuildContext context) {
    final t = data.theme;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: data.headlineLead,
            style: GoogleFonts.instrumentSerif(
              fontSize: 38,
              fontWeight: FontWeight.w400,
              height: 1.1,
              letterSpacing: -0.5,
              color: t.textPrimary,
            ),
          ),
          TextSpan(
            text: data.headlineEm,
            style: GoogleFonts.instrumentSerif(
              fontSize: 38,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w400,
              height: 1.1,
              letterSpacing: -0.5,
              color: t.headlineEm,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(
          begin: 0.08,
          end: 0,
          duration: 400.ms,
          delay: 100.ms,
          curve: Curves.easeOut,
        );
  }
}

// ───────────────────────── Language ticker ─────────────────────────

class _LangTicker extends StatefulWidget {
  const _LangTicker({required this.data});
  final _SlideData data;

  @override
  State<_LangTicker> createState() => _LangTickerState();
}

class _LangTickerState extends State<_LangTicker> {
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2600), (_) {
      if (!mounted) return;
      setState(() =>
          _index = (_index + 1) % widget.data.translations.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.data.theme;
    final current = widget.data.translations[_index];
    final meta = _langMeta[current.key]!;

    return Container(
      height: 86,
      padding: const EdgeInsets.only(left: 16),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: t.primary.withValues(alpha: 0.25),
            width: 2.5,
          ),
        ),
      ),
      child: ClipRect(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, anim) {
            final slide = Tween<Offset>(
              begin: const Offset(0, 0.25),
              end: Offset.zero,
            ).animate(anim);
            return FadeTransition(
              opacity: anim,
              child: SlideTransition(position: slide, child: child),
            );
          },
          child: Column(
            key: ValueKey(current.key),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                meta.label,
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                  color: t.tagLine,
                ),
              ),
              const SizedBox(height: 6),
              Flexible(
                child: Text(
                  current.value,
                  style: meta.buildStyle(19, t.langText),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Nav row ─────────────────────────

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.total,
    required this.index,
    required this.isLast,
    required this.theme,
    required this.onNext,
  });

  final int total;
  final int index;
  final bool isLast;
  final _SlideTheme theme;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            for (int i = 0; i < total; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 360),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.only(right: 6),
                width: i == index ? 28 : 6,
                height: 4,
                decoration: BoxDecoration(
                  color: i == index
                      ? theme.primary
                      : theme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
        _NavButton(theme: theme, label: isLast ? 'Get started' : 'Next',
            onTap: onNext),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.theme,
    required this.label,
    required this.onTap,
  });

  final _SlideTheme theme;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.primary,
      borderRadius: BorderRadius.circular(16),
      elevation: 4,
      shadowColor: theme.primary.withValues(alpha: 0.35),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 28),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Keep math import used (silences warnings on some analyzer configs).
// ignore: unused_element
final _ = math.pi;
