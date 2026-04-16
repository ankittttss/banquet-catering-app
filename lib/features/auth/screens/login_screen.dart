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
import '../../../shared/widgets/app_scaffold.dart';
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

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
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
      // Web: browser redirects back and the authStateChanges stream
      // drives the router's redirect to home.
      // Native: same, via the deep-link callback.
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } on Exception catch (e) {
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
    setState(() => _loading = true);

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
      if (user == null) {
        throw const AuthException(
          'Check your email to confirm sign-up, then sign in.',
        );
      }

      // Make sure the profile row exists (trigger handles it, this upsert
      // is belt-and-braces + lets us set name on signup).
      await ref.read(profileRepositoryProvider).upsert(
            UserProfile(
              id: user.id,
              role: UserRole.user,
              email: email,
              name: _mode == _Mode.signUp
                  ? _nameCtrl.text.trim().isEmpty
                      ? null
                      : _nameCtrl.text.trim()
                  : null,
            ),
          );
      ref.invalidate(currentProfileProvider);

      final profile = await ref.read(currentProfileProvider.future);
      if (!mounted) return;
      final role = profile?.role ?? UserRole.user;
      context.go(role == UserRole.admin
          ? AppRoutes.adminHome
          : AppRoutes.userHome);
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Something went wrong: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSignUp = _mode == _Mode.signUp;

    return AppScaffold(
      padded: false,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Hero(isSignUp: isSignUp),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.pagePadding,
                AppSizes.xl,
                AppSizes.pagePadding,
                AppSizes.pagePadding,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSignUp ? 'Create account' : 'Welcome back',
                      style: AppTextStyles.display,
                    ),
                    const SizedBox(height: AppSizes.xs),
                    Text(
                      isSignUp
                          ? 'Sign up to plan your first event'
                          : 'Sign in to continue',
                      style: AppTextStyles.bodyMuted,
                    ),
                    const SizedBox(height: AppSizes.xl),
                    if (isSignUp) ...[
                      Text('Your name',
                          style: AppTextStyles.captionBold),
                      const SizedBox(height: AppSizes.sm),
                      AppTextField(
                        label: 'Full name',
                        controller: _nameCtrl,
                        prefixIcon: PhosphorIconsBold.user,
                      ),
                      const SizedBox(height: AppSizes.md),
                    ],
                    Text('Email', style: AppTextStyles.captionBold),
                    const SizedBox(height: AppSizes.sm),
                    AppTextField(
                      label: 'you@example.com',
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: PhosphorIconsBold.envelope,
                      validator: Validators.email,
                    ),
                    const SizedBox(height: AppSizes.md),
                    Text('Password', style: AppTextStyles.captionBold),
                    const SizedBox(height: AppSizes.sm),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscure,
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Password is required';
                        }
                        if (v.length < 6) return 'Minimum 6 characters';
                        return null;
                      },
                      decoration: InputDecoration(
                        hintText: 'At least 6 characters',
                        prefixIcon:
                            const Icon(PhosphorIconsBold.lock),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? PhosphorIconsBold.eye
                              : PhosphorIconsBold.eyeSlash),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSizes.xl),
                    PrimaryButton(
                      label:
                          isSignUp ? 'Create account' : 'Sign in',
                      icon: PhosphorIconsBold.arrowRight,
                      loading: _loading,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: AppSizes.lg),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.md),
                          child: Text('OR',
                              style: AppTextStyles.captionBold),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: AppSizes.lg),
                    _GoogleButton(
                      loading: _oauthLoading,
                      onPressed: _signInWithGoogle,
                    ),
                    const SizedBox(height: AppSizes.md),
                    Center(
                      child: TextButton(
                        onPressed: () => setState(() {
                          _mode = isSignUp
                              ? _Mode.signIn
                              : _Mode.signUp;
                        }),
                        child: Text.rich(
                          TextSpan(
                            text: isSignUp
                                ? 'Already have an account? '
                                : 'New here? ',
                            style: AppTextStyles.bodyMuted,
                            children: [
                              TextSpan(
                                text: isSignUp
                                    ? 'Sign in'
                                    : 'Create one',
                                style: AppTextStyles.bodyBold
                                    .copyWith(
                                        color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSizes.sm),
                    Center(
                      child: Text(
                        'By continuing you agree to our Terms & Privacy',
                        style: AppTextStyles.caption,
                      ),
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.08, end: 0),
            ),
          ],
        ),
      ),
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

class _Hero extends StatelessWidget {
  const _Hero({required this.isSignUp});
  final bool isSignUp;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + AppSizes.lg,
        left: AppSizes.pagePadding,
        right: AppSizes.pagePadding,
        bottom: AppSizes.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.md),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: const Icon(
              PhosphorIconsDuotone.confetti,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(height: AppSizes.md),
          Text(
            'Plan beautifully.',
            style: AppTextStyles.display.copyWith(color: Colors.white),
          ),
          Text(
            'Book with a tap.',
            style: AppTextStyles.display.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}
