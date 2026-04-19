import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OtpType;

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/supabase/supabase_client.dart' as sb;
import '../../../data/models/user_profile.dart';
import '../../../data/models/user_role.dart';
import '../../../shared/providers/auth_providers.dart';
import '../../../shared/providers/repositories_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/primary_button.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.phone});

  final String phone;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final otp = _ctrl.text.trim();
    if (otp.length != 6) return;

    setState(() => _loading = true);
    try {
      if (AppConfig.hasSupabase) {
        await sb.auth.verifyOTP(
          phone: widget.phone,
          token: otp,
          type: OtpType.sms,
        );
        // Ensure a profile row exists for this user.
        final user = sb.auth.currentUser;
        if (user != null) {
          await ref.read(profileRepositoryProvider).upsert(
                UserProfile(
                  id: user.id,
                  role: UserRole.user,
                  phone: widget.phone,
                ),
              );
          ref.invalidate(currentProfileProvider);
        }
      }
      if (!mounted) return;
      final role = AppConfig.hasSupabase
          ? (await ref.read(currentProfileProvider.future))?.role ??
              UserRole.user
          : UserRole.user;
      context.go(switch (role) {
        UserRole.admin => AppRoutes.adminHome,
        UserRole.delivery => AppRoutes.deliveryHome,
        UserRole.user => AppRoutes.userHome,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid OTP: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsBold.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSizes.xl),
          Text('Verify your number', style: AppTextStyles.display),
          const SizedBox(height: AppSizes.sm),
          Text(
            'We sent a 6-digit code to ${widget.phone}',
            style: AppTextStyles.bodyMuted,
          ),
          const SizedBox(height: AppSizes.xl),
          _OtpField(controller: _ctrl, onFilled: _verify),
          const SizedBox(height: AppSizes.xl),
          PrimaryButton(
            label: 'Verify & Continue',
            icon: PhosphorIconsBold.checkCircle,
            loading: _loading,
            onPressed: _verify,
          ),
          const SizedBox(height: AppSizes.lg),
          Center(
            child: TextButton(
              onPressed: () => context.pop(),
              child: Text(
                'Change number',
                style: AppTextStyles.bodyBold
                    .copyWith(color: AppColors.primary),
              ),
            ),
          ),
        ],
      )
          .animate()
          .fadeIn(duration: 400.ms)
          .slideY(begin: 0.08, end: 0),
    );
  }
}

class _OtpField extends StatelessWidget {
  const _OtpField({required this.controller, required this.onFilled});

  final TextEditingController controller;
  final VoidCallback onFilled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      maxLength: 6,
      autofocus: true,
      style: AppTextStyles.displaySm
          .copyWith(letterSpacing: 12, color: AppColors.textPrimary),
      textAlign: TextAlign.center,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: const InputDecoration(
        counterText: '',
        hintText: '••••••',
      ),
      onChanged: (v) {
        if (v.length == 6) onFilled();
      },
    );
  }
}
