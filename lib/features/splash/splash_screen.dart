import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/router/app_routes.dart';
import '../../core/supabase/supabase_client.dart' as sb;
import '../../data/models/user_role.dart';
import '../../shared/providers/auth_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  Future<void> _route() async {
    // Small pause for brand flash.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    if (!AppConfig.hasSupabase) {
      // Dev mode: go straight to user home for local UI work.
      context.go(AppRoutes.userHome);
      return;
    }

    final user = sb.auth.currentUser;
    if (user == null) {
      context.go(AppRoutes.login);
      return;
    }

    // Wait for profile to resolve, then route by role.
    final profile = await ref.read(currentProfileProvider.future);
    if (!mounted) return;
    final role = profile?.role ?? UserRole.user;
    context.go(role == UserRole.admin
        ? AppRoutes.adminHome
        : AppRoutes.userHome);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                PhosphorIconsDuotone.confetti,
                color: Colors.white,
                size: 48,
              ),
            ).animate().scale(
                  duration: 500.ms,
                  begin: const Offset(0.7, 0.7),
                  end: const Offset(1, 1),
                  curve: Curves.easeOutBack,
                ),
            const SizedBox(height: AppSizes.xl),
            Text(
              'Dawat',
              style: AppTextStyles.display.copyWith(
                color: Colors.white,
                fontSize: 56,
                letterSpacing: -1,
              ),
            )
                .animate()
                .fadeIn(duration: 500.ms, delay: 200.ms)
                .slideY(begin: 0.2, end: 0, duration: 500.ms, delay: 200.ms),
            const SizedBox(height: AppSizes.sm),
            Text(
              'Host with heart.',
              style: AppTextStyles.body.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 15,
                letterSpacing: 2,
              ),
            ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
          ],
        ),
      ),
    );
  }
}
