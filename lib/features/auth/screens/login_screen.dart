import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/supabase/supabase_client.dart' as sb;
import '../../../core/utils/validators.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/models/user_role.dart';
import '../../../shared/providers/auth_providers.dart';
import '../../../shared/providers/repositories_providers.dart';
import '../widgets/dev_sign_in_panel.dart';

// ───────────────────────── Palette ─────────────────────────

class _P {
  static const red = Color(0xFFE23744);
  static const accent = Color(0xFFE5A100);

  static const textPrimary = Color(0xFF1C1C1C);
  static const textSecondary = Color(0xFF4F4F4F);
  static const textMuted = Color(0xFF828282);
  static const textPlaceholder = Color(0xFFC4BAB2);

  static const border = Color(0xFFE0E0E0);
  static const divider = Color(0xFFF2F2F2);
  static const surface = Color(0xFFFDFBF9);

  static const green = Color(0xFF1BA672);

  // Feast-photo hero — full-bleed image behind a dark-red gradient (design).
  static const heroUrl =
      'https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8?w=900&q=80';
  static const heroOverlay = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x591C0B0B), Color(0x8C78141A), Color(0xEB5A0E14)],
    stops: [0.0, 0.55, 1.0],
  );
  // Shown behind the photo while it loads / if it fails.
  static const heroFallback = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B2033), Color(0xFF5A0E14)],
  );
}

/// App-standard sans (Plus Jakarta Sans) — matches AppTextStyles and the rest
/// of the app. Only the "Dawat" wordmark uses Instrument Serif.
TextStyle _sans({
  double fontSize = 14,
  FontWeight fontWeight = FontWeight.w400,
  Color color = _P.textPrimary,
  double? height,
  double? letterSpacing,
  FontStyle? fontStyle,
  TextDecoration? decoration,
}) =>
    GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      fontStyle: fontStyle,
      decoration: decoration,
    );

enum _Mode { signIn, signUp, forgot }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  _Mode _mode = _Mode.signIn;
  bool _loading = false;
  bool _oauthLoading = false;
  bool _obscure = true;
  String? _errorMessage;
  bool _sendingReset = false;

  @override
  void initState() {
    super.initState();
    // Rebuild on every keystroke so the live validation cues (green check /
    // inline error) stay in sync with what the user has typed.
    for (final c in [_emailCtrl, _passwordCtrl, _nameCtrl, _phoneCtrl]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ────────── Auth ──────────

  Future<void> _signInWithGoogle() async {
    if (!AppConfig.hasSupabase) {
      if (!mounted) return;
      context.go(AppRoutes.userHome);
      return;
    }
    setState(() => _oauthLoading = true);
    try {
      await sb.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo:
            kIsWeb ? null : 'io.supabase.banquetcatering://login-callback',
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign-in failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _oauthLoading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    try {
      if (!AppConfig.hasSupabase) {
        if (!mounted) return;
        context.go(AppRoutes.userHome);
        return;
      }
      if (_mode == _Mode.signUp) {
        await _createAccount(email, password);
      } else {
        await _signInOrCreate(email, password);
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Smooth sign-in: log the user in; if no account exists yet, create it on
  /// the spot (email confirmation is disabled, so signUp returns a session
  /// immediately). Supabase returns the same "invalid credentials" error for
  /// both a wrong password and a missing account, so we disambiguate by
  /// attempting a signUp — "already registered" means the password was wrong.
  Future<void> _signInOrCreate(String email, String password) async {
    try {
      await sb.auth.signInWithPassword(email: email, password: password);
      await _routeAfterAuth();
    } on AuthException catch (e) {
      if (!_isInvalidCredentials(e)) rethrow;
      // Maybe a brand-new user — try to create the account.
      try {
        final res = await sb.auth.signUp(email: email, password: password);
        if (_hasSession(res)) {
          await _routeAfterAuth();
          return;
        }
        // No session despite confirmation being off — surface gracefully.
        throw const AuthException(
          'Account created. Please check your email to verify, then sign in.',
        );
      } on AuthException catch (e2) {
        if (_isAlreadyRegistered(e2)) {
          throw const AuthException(
            'Incorrect password. Try again or use "Forgot?" to reset it.',
          );
        }
        rethrow;
      }
    }
  }

  /// Create-account form: instant signup (no verification email) + persist
  /// the name & phone so the profile is order-ready from the first session.
  /// If the email is already registered, fall back to validating the password.
  Future<void> _createAccount(String email, String password) async {
    try {
      final res = await sb.auth.signUp(email: email, password: password);
      if (!_hasSession(res)) {
        throw const AuthException(
          'Account created. Please check your email to verify, then sign in.',
        );
      }
      final user = res.user ?? sb.auth.currentUser;
      if (user != null) {
        final name = _nameCtrl.text.trim();
        final phone = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
        try {
          await ref.read(profileRepositoryProvider).upsert(
                UserProfile(
                  id: user.id,
                  role: UserRole.customer,
                  email: email,
                  name: name.isEmpty ? null : name,
                  phone: phone.isEmpty ? null : phone,
                ),
              );
        } catch (_) {
          // Trigger may not have populated yet — currentProfileProvider
          // will auto-create a default row on first read.
        }
      }
      await _routeAfterAuth();
    } on AuthException catch (e) {
      if (!_isAlreadyRegistered(e)) rethrow;
      // Email already has an account — try the password they entered.
      try {
        await sb.auth.signInWithPassword(email: email, password: password);
        await _routeAfterAuth();
      } on AuthException {
        throw const AuthException(
          'This email already has an account. Try signing in, or reset your '
          'password.',
        );
      }
    }
  }

  Future<void> _routeAfterAuth() async {
    ref.invalidate(currentProfileProvider);
    final profile = await ref.read(currentProfileProvider.future);
    if (!mounted) return;
    final role = profile?.role ?? UserRole.customer;
    context.go(switch (role) {
      UserRole.admin => AppRoutes.adminHome,
      UserRole.banquet => AppRoutes.banquetHome,
      UserRole.restaurant => AppRoutes.restaurantHome,
      UserRole.manager => AppRoutes.managerHome,
      UserRole.serviceBoy => AppRoutes.serviceBoyHome,
      UserRole.customer => AppRoutes.userHome,
    });
  }

  bool _hasSession(AuthResponse res) =>
      res.session != null || sb.auth.currentSession != null;

  bool _isInvalidCredentials(AuthException e) {
    final m = e.message.toLowerCase();
    return m.contains('invalid login credentials') ||
        m.contains('invalid credentials');
  }

  bool _isAlreadyRegistered(AuthException e) {
    final m = e.message.toLowerCase();
    return m.contains('already registered') ||
        m.contains('already exists') ||
        m.contains('user_already_exists') ||
        e.code == 'user_already_exists';
  }

  Future<void> _sendReset() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Enter your email first.');
      return;
    }
    setState(() {
      _sendingReset = true;
      _errorMessage = null;
    });
    try {
      if (AppConfig.hasSupabase) {
        await sb.auth.resetPasswordForEmail(email);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reset link sent to $email'),
          backgroundColor: _P.green,
        ),
      );
      setState(() => _mode = _Mode.signIn);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Could not send: $e');
    } finally {
      if (mounted) setState(() => _sendingReset = false);
    }
  }

  void _switchMode(_Mode mode) {
    setState(() {
      _mode = mode;
      _errorMessage = null;
    });
  }

  // ────────── Build ──────────

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        physics: const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PhotoHero(
              mode: _mode,
              topInset: topInset,
              onBack: () => _switchMode(_Mode.signIn),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
              child: _buildFormBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormBody() {
    switch (_mode) {
      case _Mode.signIn:
        return _buildSignIn();
      case _Mode.signUp:
        return _buildSignUp();
      case _Mode.forgot:
        return _buildForgot();
    }
  }

  // Live-validation trailing check for non-password fields.
  Widget? _checkFor(bool valid) => valid ? const _ValidCheck() : null;

  Widget _buildSignIn() {
    final emailValid = Validators.email(_emailCtrl.text) == null;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Title(
              'Welcome back.', 'Sign in to plan, track and host your events.'),
          const SizedBox(height: 20),
          // Local-dev only — renders nothing in prod via AppConfig gate.
          const DevSignInPanel(),
          _FieldLabel('Email address'),
          _InputField(
            controller: _emailCtrl,
            hint: 'you@email.com',
            leadingIcon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: Validators.email,
            trailing: _checkFor(emailValid),
          ),
          const SizedBox(height: 16),
          _LabelRow(
            label: 'Password',
            trailing: _InlineLink(
              'Forgot?',
              onTap: () => _switchMode(_Mode.forgot),
            ),
          ),
          _InputField(
            controller: _passwordCtrl,
            hint: 'Enter your password',
            leadingIcon: Icons.lock_outline_rounded,
            obscureText: _obscure,
            validator: _pwValidator,
            trailing: _EyeToggle(
              obscure: _obscure,
              onTap: () => setState(() => _obscure = !_obscure),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            _ErrorBanner(message: _errorMessage!),
          ],
          const SizedBox(height: 22),
          _PrimaryButton(
            label: _loading ? 'Signing in…' : 'Sign in',
            loading: _loading,
            onPressed: _submit,
          ),
          const _OrDivider('or continue with'),
          _SocialColumn(
            googleLoading: _oauthLoading,
            onGoogle: _signInWithGoogle,
            onApple: () => _showComingSoon(context, 'Apple sign-in'),
          ),
          const SizedBox(height: 20),
          _FooterToggle(
            prefix: 'New to Dawat? ',
            linkText: 'Create an account',
            onTap: () => _switchMode(_Mode.signUp),
          ),
          const _TermsLine(),
        ],
      ),
    );
  }

  Widget _buildSignUp() {
    final nameValid = _nameCtrl.text.trim().length >= 2;
    final emailValid = Validators.email(_emailCtrl.text) == null;
    final phoneValid = Validators.phone(_phoneCtrl.text) == null;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Title("Let's get you set up.",
              "A few details and you're ready to host."),
          const SizedBox(height: 20),
          _FieldLabel('Full name'),
          _InputField(
            controller: _nameCtrl,
            hint: 'Riya Sharma',
            leadingIcon: Icons.person_outline_rounded,
            textCapitalization: TextCapitalization.words,
            validator: (v) => (v == null || v.trim().length < 2)
                ? 'Please enter your name'
                : null,
            trailing: _checkFor(nameValid),
          ),
          const SizedBox(height: 14),
          _FieldLabel('Email address'),
          _InputField(
            controller: _emailCtrl,
            hint: 'you@email.com',
            leadingIcon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: Validators.email,
            trailing: _checkFor(emailValid),
          ),
          const SizedBox(height: 14),
          _FieldLabel('Mobile number'),
          _InputField(
            controller: _phoneCtrl,
            hint: '98765 43210',
            leadingIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            prefixText: '+91',
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            validator: Validators.phone,
            trailing: _checkFor(phoneValid),
          ),
          const SizedBox(height: 14),
          _FieldLabel('Create password'),
          _InputField(
            controller: _passwordCtrl,
            hint: 'Min. 6 characters',
            leadingIcon: Icons.lock_outline_rounded,
            obscureText: _obscure,
            validator: _pwValidator,
            trailing: _EyeToggle(
              obscure: _obscure,
              onTap: () => setState(() => _obscure = !_obscure),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            _ErrorBanner(message: _errorMessage!),
          ],
          const SizedBox(height: 22),
          _PrimaryButton(
            label: _loading ? 'Creating account…' : 'Create account',
            loading: _loading,
            onPressed: _submit,
          ),
          const _OrDivider('or sign up with'),
          _SocialColumn(
            googleLoading: _oauthLoading,
            onGoogle: _signInWithGoogle,
            onApple: () => _showComingSoon(context, 'Apple sign-in'),
          ),
          const SizedBox(height: 20),
          _FooterToggle(
            prefix: 'Already have an account? ',
            linkText: 'Sign in',
            onTap: () => _switchMode(_Mode.signIn),
          ),
          const _TermsLine(),
        ],
      ),
    );
  }

  Widget _buildForgot() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Title(
          'Reset password',
          "Enter your email and we'll send you a reset link.",
        ),
        const SizedBox(height: 24),
        _FieldLabel('Email address'),
        _InputField(
          controller: _emailCtrl,
          hint: 'you@email.com',
          leadingIcon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 14),
          _ErrorBanner(message: _errorMessage!),
        ],
        const SizedBox(height: 22),
        _PrimaryButton(
          label: _sendingReset ? 'Sending…' : 'Send reset link',
          loading: _sendingReset,
          onPressed: _sendReset,
        ),
        const SizedBox(height: 24),
        _FooterToggle(
          prefix: 'Remember your password? ',
          linkText: 'Sign in',
          onTap: () => _switchMode(_Mode.signIn),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  String? _pwValidator(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 6) return 'At least 6 characters';
    return null;
  }

  void _showComingSoon(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label — coming soon.')),
    );
  }
}

// ───────────────────────── Photo hero ─────────────────────────

class _PhotoHero extends StatelessWidget {
  const _PhotoHero({
    required this.mode,
    required this.topInset,
    required this.onBack,
  });

  final _Mode mode;
  final double topInset;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final tall = mode == _Mode.signIn;
    final height = (tall ? 232.0 : 168.0) + topInset;
    final (overline, wordSize) = switch (mode) {
      _Mode.signIn => ('Banquet · Catering · One app', 52.0),
      _Mode.signUp => ('Create your account', 40.0),
      _Mode.forgot => ('Reset your password', 40.0),
    };

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Base brand gradient — visible while the photo loads / on error.
          const DecoratedBox(
            decoration: BoxDecoration(gradient: _P.heroFallback),
          ),
          Image.network(
            _P.heroUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(gradient: _P.heroOverlay),
          ),
          // Back button on sign-up / forgot.
          if (mode != _Mode.signIn)
            Positioned(
              top: topInset + 12,
              left: 12,
              child: _CircleBack(onTap: onBack),
            ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Dawat',
                  style: GoogleFonts.instrumentSerif(
                    fontSize: wordSize,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                    height: 1,
                    letterSpacing: -1,
                  ),
                ).animate().fadeIn(duration: 320.ms),
                const SizedBox(height: 8),
                Text(
                  overline.toUpperCase(),
                  style: _sans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _P.accent,
                    letterSpacing: 1.6,
                  ),
                ),
                if (tall) ...[
                  const SizedBox(height: 12),
                  const _SocialProofPill(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialProofPill extends StatelessWidget {
  const _SocialProofPill();

  @override
  Widget build(BuildContext context) {
    const dots = [Color(0xFFE5A100), Color(0xFF1BA672), Color(0xFF2B6CB0)];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 18 + 12.0 * 2,
            height: 18,
            child: Stack(
              children: [
                for (var i = 0; i < dots.length; i++)
                  Positioned(
                    left: i * 12.0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: dots[i],
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '10,000+ events hosted',
            style: _sans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleBack extends StatelessWidget {
  const _CircleBack({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 40,
          height: 40,
          child:
              Icon(Icons.arrow_back_rounded, size: 20, color: _P.textPrimary),
        ),
      ),
    );
  }
}

// ───────────────────────── Title ─────────────────────────

class _Title extends StatelessWidget {
  const _Title(this.title, this.sub);
  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: _sans(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: _P.textPrimary,
            height: 1.15,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          sub,
          style: _sans(
            fontSize: 14,
            color: _P.textMuted,
            fontWeight: FontWeight.w400,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── Field label ─────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: _labelStyle()),
    );
  }
}

/// Label row with a trailing widget (e.g. the "Forgot?" link beside Password).
class _LabelRow extends StatelessWidget {
  const _LabelRow({required this.label, required this.trailing});
  final String label;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: _labelStyle()),
          trailing,
        ],
      ),
    );
  }
}

TextStyle _labelStyle() => _sans(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: _P.textSecondary,
    );

class _InlineLink extends StatelessWidget {
  const _InlineLink(this.text, {required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Text(
          text,
          style: _sans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _P.red,
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Input field ─────────────────────────

class _InputField extends StatefulWidget {
  const _InputField({
    required this.controller,
    required this.hint,
    required this.leadingIcon,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
    this.trailing,
    this.prefixText,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String hint;
  final IconData leadingIcon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final FormFieldValidator<String>? validator;
  final Widget? trailing;
  final String? prefixText;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;

  @override
  State<_InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<_InputField> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: _focused ? Colors.white : _P.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _focused ? _P.red : _P.border,
          width: 1.5,
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: _P.red.withValues(alpha: 0.08),
                  blurRadius: 6,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focus,
        keyboardType: widget.keyboardType,
        obscureText: widget.obscureText,
        textCapitalization: widget.textCapitalization,
        inputFormatters: widget.inputFormatters,
        validator: widget.validator,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        style: _sans(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: _P.textPrimary,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          hintText: widget.hint,
          hintStyle: _sans(
            fontSize: 15,
            color: _P.textPlaceholder,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 10),
            child: Icon(
              widget.leadingIcon,
              size: 18,
              color: _focused ? _P.red : _P.textMuted,
            ),
          ),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 0, minHeight: 0),
          prefix: widget.prefixText == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    widget.prefixText!,
                    style: _sans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _P.textSecondary,
                    ),
                  ),
                ),
          suffixIcon: widget.trailing == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: widget.trailing,
                ),
          suffixIconConstraints:
              const BoxConstraints(minWidth: 0, minHeight: 0),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          errorStyle: _sans(
            color: _P.red,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ValidCheck extends StatelessWidget {
  const _ValidCheck();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.check_circle_rounded, size: 18, color: _P.green);
  }
}

class _EyeToggle extends StatelessWidget {
  const _EyeToggle({required this.obscure, required this.onTap});
  final bool obscure;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Icon(
          obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: 20,
          color: _P.textMuted,
        ),
      ),
    );
  }
}

// ───────────────────────── Primary button ─────────────────────────

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Material(
        color: _P.red,
        borderRadius: BorderRadius.circular(16),
        elevation: 4,
        shadowColor: _P.red.withValues(alpha: 0.25),
        child: InkWell(
          onTap: loading
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onPressed();
                },
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.4,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: _sans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 18),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── OR divider ─────────────────────────

class _OrDivider extends StatelessWidget {
  const _OrDivider(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Row(
        children: [
          const Expanded(child: Divider(color: _P.divider, thickness: 1)),
          const SizedBox(width: 12),
          Text(
            label,
            style: _sans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _P.textMuted,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Divider(color: _P.divider, thickness: 1)),
        ],
      ),
    );
  }
}

// ───────────────────────── Social buttons (stacked) ─────────────────────────

class _SocialColumn extends StatelessWidget {
  const _SocialColumn({
    required this.googleLoading,
    required this.onGoogle,
    required this.onApple,
  });

  final bool googleLoading;
  final VoidCallback onGoogle;
  final VoidCallback onApple;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SocialButton(
          onTap: onGoogle,
          loading: googleLoading,
          label: 'Continue with Google',
          leading: SvgPicture.asset(
            'assets/icons/google_g.svg',
            width: 20,
            height: 20,
          ),
        ),
        const SizedBox(height: 10),
        _SocialButton(
          onTap: onApple,
          loading: false,
          label: 'Continue with Apple',
          leading:
              const Icon(Icons.apple_rounded, size: 22, color: _P.textPrimary),
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.onTap,
    required this.loading,
    required this.label,
    required this.leading,
  });

  final VoidCallback onTap;
  final bool loading;
  final String label;
  final Widget leading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: loading ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _P.border, width: 1.5),
            ),
            alignment: Alignment.center,
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      leading,
                      const SizedBox(width: 10),
                      Text(
                        label,
                        style: _sans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _P.textSecondary,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Error banner ─────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _P.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _P.red.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: _P.red, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: _sans(
                fontSize: 13,
                color: _P.red,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Footer toggle ─────────────────────────

class _FooterToggle extends StatelessWidget {
  const _FooterToggle({
    required this.prefix,
    required this.linkText,
    required this.onTap,
  });

  final String prefix;
  final String linkText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: prefix,
              style: _sans(fontSize: 14, color: _P.textSecondary),
            ),
            TextSpan(
              text: linkText,
              style: _sans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _P.red,
              ),
              recognizer: _tapRecognizer(onTap),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _TermsLine extends StatelessWidget {
  const _TermsLine();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Center(
        child: Text.rich(
          TextSpan(
            style: _sans(
              fontSize: 11,
              color: _P.textMuted,
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
            children: [
              const TextSpan(text: 'By continuing, you agree to our '),
              TextSpan(
                text: 'Terms',
                style: _sans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _P.textPrimary,
                ),
              ),
              const TextSpan(text: ' & '),
              TextSpan(
                text: 'Privacy Policy',
                style: _sans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _P.textPrimary,
                ),
              ),
              const TextSpan(text: '.'),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ───────────────────────── Helpers ─────────────────────────

TapGestureRecognizer _tapRecognizer(VoidCallback onTap) =>
    TapGestureRecognizer()..onTap = onTap;
