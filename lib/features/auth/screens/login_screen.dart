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

// ───────────────────────── Palette ─────────────────────────

class _P {
  static const red = Color(0xFFE23744);
  static const redDark = Color(0xFF8B2033);
  static const gold = Color(0xFFC4922A);

  static const textPrimary = Color(0xFF1A1A1A);
  static const textLabel = Color(0xFF4A3F38);
  static const textMuted = Color(0xFF8C8078);
  static const textPlaceholder = Color(0xFFC4BAB2);

  static const border = Color(0xFFE8E0D8);
  static const borderSoft = Color(0xFFD0C8C0);
  static const surface = Color(0xFFFDFBF9);
  static const pullTab = Color(0xFFE0D8D0);

  static const bgGrad1 = Color(0xFFFFF5F0);
  static const bgGrad2 = Color(0xFFFFF0EC);

  static const green = Color(0xFF1BA672);
  static const amber = Color(0xFFE5A100);
}

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

  _Mode _mode = _Mode.signIn;
  bool _loading = false;
  bool _oauthLoading = false;
  bool _obscure = true;
  String? _errorMessage;
  bool _needsVerification = false;
  bool _resending = false;
  bool _sendingReset = false;

  @override
  void initState() {
    super.initState();
    _passwordCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  // ────────── Auth methods (unchanged logic) ──────────

  Future<void> _resendVerification() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !AppConfig.hasSupabase) return;
    setState(() => _resending = true);
    try {
      await sb.auth.resend(type: OtpType.signup, email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification email sent to $email'),
          backgroundColor: _P.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not resend: $e')),
      );
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

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
        redirectTo: kIsWeb
            ? null
            : 'io.supabase.banquetcatering://login-callback',
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
      _needsVerification = false;
    });

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    try {
      if (!AppConfig.hasSupabase) {
        if (!mounted) return;
        context.go(AppRoutes.userHome);
        return;
      }

      AuthResponse res;
      if (_mode == _Mode.signUp) {
        res = await sb.auth.signUp(email: email, password: password);
      } else {
        res = await sb.auth.signInWithPassword(
          email: email,
          password: password,
        );
      }

      final user = res.user ?? sb.auth.currentUser;
      final hasSession =
          res.session != null || sb.auth.currentSession != null;
      if (user == null || !hasSession) {
        setState(() => _needsVerification = true);
        throw const AuthException(
          'Verify your email first. Check your inbox for the confirmation link.',
        );
      }

      if (_mode == _Mode.signUp && _nameCtrl.text.trim().isNotEmpty) {
        try {
          await ref.read(profileRepositoryProvider).upsert(
                UserProfile(
                  id: user.id,
                  role: UserRole.user,
                  email: email,
                  name: _nameCtrl.text.trim(),
                ),
              );
        } catch (_) {
          // trigger may not have populated yet — currentProfileProvider
          // will auto-create a default row on first read.
        }
      }

      ref.invalidate(currentProfileProvider);
      final profile = await ref.read(currentProfileProvider.future);
      if (!mounted) return;
      final role = profile?.role ?? UserRole.user;
      context.go(role == UserRole.admin
          ? AppRoutes.adminHome
          : AppRoutes.userHome);
    } on AuthException catch (e) {
      if (!mounted) return;
      final msg = e.message.toLowerCase();
      setState(() {
        _errorMessage = e.message;
        if (msg.contains('not confirmed') || msg.contains('verify')) {
          _needsVerification = true;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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

  // ────────── Build ──────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _P.bgGrad1,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Header(),
                    Expanded(
                      child: _FormCard(child: _buildFormBody()),
                    ),
                  ],
                ),
              ),
            ),
          ),
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

  Widget _buildSignIn() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Title('Welcome back', 'Sign in to continue hosting'),
          const SizedBox(height: 24),
          _FieldLabel('Email'),
          _InputField(
            controller: _emailCtrl,
            hint: 'you@example.com',
            leadingIcon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: Validators.email,
          ),
          const SizedBox(height: 16),
          _FieldLabel('Password'),
          _InputField(
            controller: _passwordCtrl,
            hint: 'At least 6 characters',
            leadingIcon: Icons.lock_outline_rounded,
            obscureText: _obscure,
            validator: _pwValidator,
            trailing: _EyeToggle(
              obscure: _obscure,
              onTap: () => setState(() => _obscure = !_obscure),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  setState(() {
                    _mode = _Mode.forgot;
                    _errorMessage = null;
                    _needsVerification = false;
                  });
                },
                child: Text(
                  'Forgot password?',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _P.red,
                  ),
                ),
              ),
            ],
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(
              message: _errorMessage!,
              needsVerification: _needsVerification,
              resending: _resending,
              onResend: _resendVerification,
            ),
          ],
          const SizedBox(height: 12),
          _PrimaryButton(
            label: 'Sign in',
            loading: _loading,
            onPressed: _submit,
          ),
          const _OrDivider(),
          _SocialRow(
            googleLoading: _oauthLoading,
            onGoogle: _signInWithGoogle,
            onApple: () => _showComingSoon(context, 'Apple sign-in'),
          ),
          const SizedBox(height: 20),
          _FooterToggle(
            prefix: 'New here? ',
            linkText: 'Create account',
            onTap: () => setState(() {
              _mode = _Mode.signUp;
              _errorMessage = null;
              _needsVerification = false;
            }),
          ),
          const _TermsLine(),
        ],
      ),
    );
  }

  Widget _buildSignUp() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Title('Create account', 'Start planning your first event'),
          const SizedBox(height: 24),
          _FieldLabel('Your name'),
          _InputField(
            controller: _nameCtrl,
            hint: 'Full name',
            leadingIcon: Icons.person_outline_rounded,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          _FieldLabel('Email'),
          _InputField(
            controller: _emailCtrl,
            hint: 'you@example.com',
            leadingIcon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: Validators.email,
          ),
          const SizedBox(height: 16),
          _FieldLabel('Password'),
          _InputField(
            controller: _passwordCtrl,
            hint: 'At least 6 characters',
            leadingIcon: Icons.lock_outline_rounded,
            obscureText: _obscure,
            validator: _pwValidator,
            trailing: _EyeToggle(
              obscure: _obscure,
              onTap: () => setState(() => _obscure = !_obscure),
            ),
          ),
          const SizedBox(height: 8),
          _StrengthBar(password: _passwordCtrl.text),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(
              message: _errorMessage!,
              needsVerification: _needsVerification,
              resending: _resending,
              onResend: _resendVerification,
            ),
          ],
          const SizedBox(height: 20),
          _PrimaryButton(
            label: 'Create account',
            loading: _loading,
            onPressed: _submit,
          ),
          const _OrDivider(),
          _SocialRow(
            googleLoading: _oauthLoading,
            onGoogle: _signInWithGoogle,
            onApple: () => _showComingSoon(context, 'Apple sign-in'),
          ),
          const SizedBox(height: 20),
          _FooterToggle(
            prefix: 'Already have an account? ',
            linkText: 'Sign in',
            onTap: () => setState(() {
              _mode = _Mode.signIn;
              _errorMessage = null;
              _needsVerification = false;
            }),
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
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextButton.icon(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: _P.textMuted,
            ),
            onPressed: () => setState(() {
              _mode = _Mode.signIn;
              _errorMessage = null;
            }),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: Text(
              'Back',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _P.textMuted,
              ),
            ),
          ),
        ),
        _Title(
          'Reset password',
          "Enter your email and we'll send you a reset link",
        ),
        const SizedBox(height: 24),
        _FieldLabel('Email'),
        _InputField(
          controller: _emailCtrl,
          hint: 'you@example.com',
          leadingIcon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          _ErrorBanner(
            message: _errorMessage!,
            needsVerification: false,
            resending: false,
            onResend: () {},
          ),
        ],
        const SizedBox(height: 20),
        _PrimaryButton(
          label: 'Send reset link',
          loading: _sendingReset,
          onPressed: _sendReset,
        ),
        const SizedBox(height: 28),
        _FooterToggle(
          prefix: 'Remember your password? ',
          linkText: 'Sign in',
          onTap: () => setState(() {
            _mode = _Mode.signIn;
            _errorMessage = null;
          }),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  String? _pwValidator(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 6) return 'Minimum 6 characters';
    return null;
  }

  void _showComingSoon(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label — coming soon.')),
    );
  }
}

// ───────────────────────── Header ─────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 36, 28, 36),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: const Alignment(0, -1),
          end: const Alignment(0, 1),
          colors: const [_P.bgGrad1, _P.bgGrad2],
        ),
      ),
      child: Column(
        children: [
          // Logo mark — gradient rounded-square with dawat.png inside.
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_P.redDark, _P.red, _P.gold],
                stops: [0.0, 0.5, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: _P.red.withValues(alpha: 0.25),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.all(10),
              child: Image.asset(
                'assets/images/dawat.png',
                fit: BoxFit.contain,
                color: Colors.white,
                colorBlendMode: BlendMode.srcIn,
                errorBuilder: (_, __, ___) => const Center(
                  child: Text(
                    '🍽',
                    style: TextStyle(fontSize: 32),
                  ),
                ),
              ),
            ),
          ).animate().fadeIn(duration: 360.ms).scale(
                begin: const Offset(0.7, 0.7),
                end: const Offset(1, 1),
                duration: 420.ms,
                curve: Curves.easeOutBack,
              ),
          const SizedBox(height: 16),
          Text(
            'Dawat',
            style: GoogleFonts.instrumentSerif(
              fontSize: 36,
              fontWeight: FontWeight.w400,
              color: _P.textPrimary,
              letterSpacing: -1,
            ),
          ).animate().fadeIn(delay: 80.ms, duration: 320.ms),
          const SizedBox(height: 10),
          Container(
            width: 32,
            height: 2,
            decoration: BoxDecoration(
              color: _P.red,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'HOST WITH HEART',
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _P.gold,
              letterSpacing: 3.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Form card ─────────────────────────

class _FormCard extends StatelessWidget {
  const _FormCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            offset: Offset(0, -4),
            blurRadius: 30,
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 32),
      child: Column(
        children: [
          // Pull tab.
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: _P.pullTab,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
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
          style: GoogleFonts.instrumentSerif(
            fontSize: 28,
            fontWeight: FontWeight.w400,
            color: _P.textPrimary,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          sub,
          style: GoogleFonts.outfit(
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
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _P.textLabel,
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
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String hint;
  final IconData leadingIcon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final FormFieldValidator<String>? validator;
  final Widget? trailing;
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
    _focus.addListener(() {
      setState(() => _focused = _focus.hasFocus);
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: _focused ? Colors.white : _P.surface,
        borderRadius: BorderRadius.circular(14),
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
        validator: widget.validator,
        style: GoogleFonts.outfit(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: _P.textPrimary,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
          hintText: widget.hint,
          hintStyle: GoogleFonts.outfit(
            fontSize: 15,
            color: _P.textPlaceholder,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Icon(
              widget.leadingIcon,
              size: 20,
              color: _focused ? _P.red : _P.textPlaceholder,
            ),
          ),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 0, minHeight: 0),
          suffixIcon: widget.trailing == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: widget.trailing,
                ),
          suffixIconConstraints:
              const BoxConstraints(minWidth: 0, minHeight: 0),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          errorStyle: GoogleFonts.outfit(
            color: _P.red,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
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
        padding: const EdgeInsets.all(4),
        child: Icon(
          obscure
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          size: 20,
          color: _P.textMuted,
        ),
      ),
    );
  }
}

// ───────────────────────── Strength bar ─────────────────────────

class _StrengthBar extends StatelessWidget {
  const _StrengthBar({required this.password});
  final String password;

  @override
  Widget build(BuildContext context) {
    final score = _score(password);
    Color c;
    if (score <= 1) {
      c = _P.red;
    } else if (score <= 2) {
      c = _P.amber;
    } else {
      c = _P.green;
    }

    return Row(
      children: List.generate(4, (i) {
        final on = password.isNotEmpty && i < score;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i == 3 ? 0 : 4),
            height: 3,
            decoration: BoxDecoration(
              color: on ? c : _P.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  int _score(String v) {
    if (v.isEmpty) return 0;
    var s = 0;
    if (v.length >= 6) s++;
    if (v.length >= 8) s++;
    if (RegExp(r'[A-Z]').hasMatch(v) && RegExp(r'[0-9]').hasMatch(v)) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(v)) s++;
    return s;
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
                      const Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
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

// ───────────────────────── OR divider ─────────────────────────

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Row(
        children: [
          const Expanded(child: Divider(color: _P.border, thickness: 1)),
          const SizedBox(width: 14),
          Text(
            'OR',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _P.textPlaceholder,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(child: Divider(color: _P.border, thickness: 1)),
        ],
      ),
    );
  }
}

// ───────────────────────── Social row ─────────────────────────

class _SocialRow extends StatelessWidget {
  const _SocialRow({
    required this.googleLoading,
    required this.onGoogle,
    required this.onApple,
  });

  final bool googleLoading;
  final VoidCallback onGoogle;
  final VoidCallback onApple;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SocialButton(
            onTap: onGoogle,
            loading: googleLoading,
            label: 'Google',
            leading: SvgPicture.asset(
              'assets/icons/google_g.svg',
              width: 20,
              height: 20,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SocialButton(
            onTap: onApple,
            loading: false,
            label: 'Apple',
            leading: const Icon(
              Icons.apple_rounded,
              size: 22,
              color: _P.textPrimary,
            ),
          ),
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
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _P.textLabel,
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
  const _ErrorBanner({
    required this.message,
    required this.needsVerification,
    required this.resending,
    required this.onResend,
  });

  final String message;
  final bool needsVerification;
  final bool resending;
  final VoidCallback onResend;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: _P.red, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: _P.red,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          if (needsVerification) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: resending ? null : onResend,
                icon: resending
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded,
                        size: 14, color: _P.red),
                label: Text(
                  resending ? 'Sending…' : 'Resend verification email',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _P.red,
                  ),
                ),
              ),
            ),
          ],
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
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: _P.textMuted,
              ),
            ),
            TextSpan(
              text: linkText,
              style: GoogleFonts.outfit(
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
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        'By continuing you agree to our Terms & Privacy Policy',
        textAlign: TextAlign.center,
        style: GoogleFonts.outfit(
          fontSize: 11,
          color: _P.textPlaceholder,
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
      ),
    );
  }
}

// ───────────────────────── Helpers ─────────────────────────

TapGestureRecognizer _tapRecognizer(VoidCallback onTap) =>
    TapGestureRecognizer()..onTap = onTap;
