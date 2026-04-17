import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/supabase/supabase_client.dart' as sb;
import '../../../core/utils/validators.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/models/user_role.dart';
import '../../../shared/providers/auth_providers.dart';
import '../../../shared/providers/repositories_providers.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/primary_button.dart';

enum _Mode { signIn, signUp }

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

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

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
          backgroundColor: AppColors.success,
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
      final hasSession = res.session != null || sb.auth.currentSession != null;
      if (user == null || !hasSession) {
        setState(() => _needsVerification = true);
        throw const AuthException(
          'Verify your email first. Check your inbox for the confirmation link.',
        );
      }

      // Only set name on first-time sign-up. Don't clobber role/name on sign-in.
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

  @override
  Widget build(BuildContext context) {
    final isSignUp = _mode == _Mode.signUp;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Stack(
        children: [
          const _OrnateBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: screenHeight - 60),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: screenHeight * 0.08),
                    _BrandMark(),
                    SizedBox(height: screenHeight * 0.05),
                    _FormCard(
                      formKey: _formKey,
                      isSignUp: isSignUp,
                      emailCtrl: _emailCtrl,
                      passwordCtrl: _passwordCtrl,
                      nameCtrl: _nameCtrl,
                      obscure: _obscure,
                      loading: _loading,
                      oauthLoading: _oauthLoading,
                      errorMessage: _errorMessage,
                      needsVerification: _needsVerification,
                      resending: _resending,
                      onResend: _resendVerification,
                      onToggleObscure: () =>
                          setState(() => _obscure = !_obscure),
                      onSubmit: _submit,
                      onGoogle: _signInWithGoogle,
                      onToggleMode: () => setState(() {
                        _mode = isSignUp ? _Mode.signIn : _Mode.signUp;
                        _errorMessage = null;
                        _needsVerification = false;
                      }),
                    ),
                    const SizedBox(height: AppSizes.xl),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Decorative background — gradient + soft sparkle pattern
// ---------------------------------------------------------------------------

class _OrnateBackground extends StatelessWidget {
  const _OrnateBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF6A1530),
                Color(0xFF8B1E3F),
                Color(0xFFB23A5E),
              ],
            ),
          ),
        ),
        // Soft gold glow top-right
        Positioned(
          top: -80,
          right: -80,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.accent.withValues(alpha: 0.35),
                  AppColors.accent.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
        // Deep glow bottom-left
        Positioned(
          bottom: -80,
          left: -80,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF6A1530).withValues(alpha: 0.6),
                  const Color(0xFF6A1530).withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
        // Floating sparkles
        const _FloatingSparkles(),
      ],
    );
  }
}

class _FloatingSparkles extends StatelessWidget {
  const _FloatingSparkles();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          _sparkle(top: 70, left: 30, size: 12, delay: 0),
          _sparkle(top: 140, right: 40, size: 16, delay: 200),
          _sparkle(top: 220, left: 70, size: 9, delay: 400),
          _sparkle(bottom: 160, right: 30, size: 14, delay: 600),
          _sparkle(bottom: 80, left: 40, size: 10, delay: 800),
        ],
      ),
    );
  }

  Widget _sparkle({
    double? top,
    double? left,
    double? right,
    double? bottom,
    required double size,
    required int delay,
  }) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Icon(
        PhosphorIconsFill.sparkle,
        color: AppColors.accent.withValues(alpha: 0.55),
        size: size,
      )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .fadeIn(duration: 900.ms, delay: delay.ms)
          .scale(
            begin: const Offset(0.7, 0.7),
            end: const Offset(1.1, 1.1),
            duration: 2400.ms,
            curve: Curves.easeInOut,
          ),
    );
  }
}

// ---------------------------------------------------------------------------
// Brand mark — big serif "Dawat" + gold sparkle accent + tagline
// ---------------------------------------------------------------------------

class _BrandMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(PhosphorIconsFill.sparkle,
                color: AppColors.accent, size: 22),
            const SizedBox(width: AppSizes.sm),
            Text(
              'Dawat',
              style: AppTextStyles.display.copyWith(
                color: Colors.white,
                fontSize: 56,
                letterSpacing: -1,
                height: 1,
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            const Icon(PhosphorIconsFill.sparkle,
                color: AppColors.accent, size: 22),
          ],
        )
            .animate()
            .fadeIn(duration: 500.ms)
            .slideY(begin: -0.15, end: 0, duration: 500.ms),
        const SizedBox(height: AppSizes.sm),
        Container(
          width: 44,
          height: 1,
          color: AppColors.accent.withValues(alpha: 0.6),
        ),
        const SizedBox(height: AppSizes.sm),
        Text(
          'HOST   WITH   HEART',
          style: AppTextStyles.overline.copyWith(
            color: AppColors.accent,
            fontSize: 11,
            letterSpacing: 5,
          ),
        ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Floating form card — cream surface on top of maroon background
// ---------------------------------------------------------------------------

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.formKey,
    required this.isSignUp,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.nameCtrl,
    required this.obscure,
    required this.loading,
    required this.oauthLoading,
    required this.errorMessage,
    required this.needsVerification,
    required this.resending,
    required this.onResend,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.onGoogle,
    required this.onToggleMode,
  });

  final GlobalKey<FormState> formKey;
  final bool isSignUp;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final TextEditingController nameCtrl;
  final bool obscure;
  final bool loading;
  final bool oauthLoading;
  final String? errorMessage;
  final bool needsVerification;
  final bool resending;
  final VoidCallback onResend;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  final VoidCallback onGoogle;
  final VoidCallback onToggleMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
      padding: const EdgeInsets.fromLTRB(
        AppSizes.xl,
        AppSizes.xl,
        AppSizes.xl,
        AppSizes.xl,
      ),
      decoration: BoxDecoration(
        color: AppColors.pageBg,
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isSignUp ? 'Create account' : 'Welcome back',
              style: AppTextStyles.display.copyWith(fontSize: 26),
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              isSignUp
                  ? 'Start planning your first event'
                  : 'Sign in to continue hosting',
              style: AppTextStyles.bodyMuted,
            ),
            const SizedBox(height: AppSizes.xl),
            if (isSignUp) ...[
              _FieldLabel('Your name'),
              AppTextField(
                label: 'Full name',
                controller: nameCtrl,
                prefixIcon: PhosphorIconsBold.user,
              ),
              const SizedBox(height: AppSizes.md),
            ],
            _FieldLabel('Email'),
            AppTextField(
              label: 'you@example.com',
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              prefixIcon: PhosphorIconsBold.envelope,
              validator: Validators.email,
            ),
            const SizedBox(height: AppSizes.md),
            _FieldLabel('Password'),
            TextFormField(
              controller: passwordCtrl,
              obscureText: obscure,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password is required';
                if (v.length < 6) return 'Minimum 6 characters';
                return null;
              },
              decoration: InputDecoration(
                hintText: 'At least 6 characters',
                prefixIcon: const Icon(PhosphorIconsBold.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscure
                        ? PhosphorIconsBold.eye
                        : PhosphorIconsBold.eyeSlash,
                    size: 18,
                  ),
                  onPressed: onToggleObscure,
                ),
              ),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: AppSizes.lg),
              _AuthErrorBanner(
                message: errorMessage!,
                needsVerification: needsVerification,
                resending: resending,
                onResend: onResend,
              ),
            ],
            const SizedBox(height: AppSizes.xl),
            PrimaryButton(
              label: isSignUp ? 'Create account' : 'Sign in',
              icon: PhosphorIconsBold.arrowRight,
              loading: loading,
              onPressed: onSubmit,
            ),
            const SizedBox(height: AppSizes.lg),
            Row(
              children: [
                const Expanded(
                  child: Divider(color: AppColors.border),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.md),
                  child: Text('OR', style: AppTextStyles.captionBold),
                ),
                const Expanded(
                  child: Divider(color: AppColors.border),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.lg),
            _GoogleButton(loading: oauthLoading, onPressed: onGoogle),
            const SizedBox(height: AppSizes.lg),
            Center(
              child: TextButton(
                onPressed: onToggleMode,
                child: Text.rich(
                  TextSpan(
                    text: isSignUp
                        ? 'Already have an account? '
                        : 'New here? ',
                    style: AppTextStyles.bodyMuted,
                    children: [
                      TextSpan(
                        text: isSignUp ? 'Sign in' : 'Create one',
                        style: AppTextStyles.bodyBold
                            .copyWith(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: Text(
                'By continuing you agree to our Terms & Privacy',
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms, delay: 200.ms)
        .slideY(begin: 0.08, end: 0, duration: 500.ms, delay: 200.ms);
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.xs + 2),
      child: Text(text, style: AppTextStyles.captionBold),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.loading, required this.onPressed});
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppSizes.buttonHeight,
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border, width: 1.2),
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
        ),
        child: loading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/icons/google_g.svg',
                    width: 20,
                    height: 20,
                  ),
                  const SizedBox(width: AppSizes.md),
                  Text(
                    'Continue with Google',
                    style: AppTextStyles.bodyBold,
                  ),
                ],
              ),
      ),
    );
  }
}

class _AuthErrorBanner extends StatelessWidget {
  const _AuthErrorBanner({
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
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(PhosphorIconsBold.warningCircle,
                  color: AppColors.error, size: 18),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: Text(
                  message,
                  style: AppTextStyles.body.copyWith(color: AppColors.error),
                ),
              ),
            ],
          ),
          if (needsVerification) ...[
            const SizedBox(height: AppSizes.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: resending ? null : onResend,
                icon: resending
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(PhosphorIconsBold.paperPlaneTilt, size: 14),
                label: Text(
                  resending ? 'Sending…' : 'Resend verification email',
                  style: AppTextStyles.bodyBold
                      .copyWith(color: AppColors.primary),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
