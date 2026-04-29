import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../shared/providers/delivery_providers.dart';
import '../../../shared/providers/repositories_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_scaffold.dart';

class DeliveryOtpScreen extends ConsumerStatefulWidget {
  const DeliveryOtpScreen({super.key, required this.assignmentId});
  final String assignmentId;

  @override
  ConsumerState<DeliveryOtpScreen> createState() => _State();
}

class _State extends ConsumerState<DeliveryOtpScreen> {
  final _controllers = List.generate(4, (_) => TextEditingController());
  final _focus = List.generate(4, (_) => FocusNode());
  bool _photoCaptured = false;
  bool _handedOver = false;
  bool _setupDone = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focus) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otp => _controllers.map((c) => c.text).join();
  bool get _canSubmit =>
      _otp.length == 4 && _handedOver && _setupDone && !_busy;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      padded: false,
      appBar: AppBar(
        title: const Text('Confirm delivery'),
        leading: IconButton(
          icon: const Icon(PhosphorIconsBold.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const SizedBox(height: AppSizes.lg),
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.catGreenLt,
                borderRadius:
                    BorderRadius.circular(AppSizes.radiusXl + 16),
              ),
              child: const Icon(PhosphorIconsFill.checkCircle,
                  color: AppColors.success, size: 40),
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          Center(
            child: Text('Enter delivery OTP',
                style: AppTextStyles.displaySm),
          ),
          const SizedBox(height: AppSizes.xs),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppSizes.xxxl),
            child: Text(
              'Ask the customer for the 4-digit OTP sent to their phone',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSizes.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 4; i++) ...[
                _OtpBox(
                  controller: _controllers[i],
                  focusNode: _focus[i],
                  onChanged: (v) {
                    if (v.length == 1 && i < 3) {
                      _focus[i + 1].requestFocus();
                    } else if (v.isEmpty && i > 0) {
                      _focus[i - 1].requestFocus();
                    }
                    setState(() {});
                  },
                ),
                if (i < 3) const SizedBox(width: AppSizes.sm + 2),
              ],
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSizes.md),
            Center(
              child: Text(
                _error!,
                style: AppTextStyles.captionBold
                    .copyWith(color: AppColors.primary),
              ),
            ),
          ],
          const SizedBox(height: AppSizes.xl),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.pagePadding),
            child: AppCard(
              onTap: () => setState(() => _photoCaptured = !_photoCaptured),
              padding: const EdgeInsets.all(AppSizes.md),
              color: _photoCaptured
                  ? AppColors.catGreenLt
                  : AppColors.surface,
              border: Border.all(
                color: _photoCaptured
                    ? AppColors.success
                    : AppColors.border,
                width: _photoCaptured ? 1.5 : 1,
                style: BorderStyle.solid,
              ),
              child: Container(
                height: 120,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _photoCaptured
                          ? PhosphorIconsFill.checkCircle
                          : PhosphorIconsBold.camera,
                      color: _photoCaptured
                          ? AppColors.success
                          : AppColors.textMuted,
                      size: 28,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _photoCaptured
                          ? 'Photo captured'
                          : 'Take delivery photo',
                      style: AppTextStyles.captionBold.copyWith(
                        color: _photoCaptured
                            ? AppColors.success
                            : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.md),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.pagePadding),
            child: Column(
              children: [
                _Check(
                  label: 'Food handed to customer',
                  checked: _handedOver,
                  onTap: () =>
                      setState(() => _handedOver = !_handedOver),
                ),
                _Check(
                  label: 'Setup assistance provided',
                  checked: _setupDone,
                  onTap: () => setState(() => _setupDone = !_setupDone),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.xl),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.pagePadding),
            child: SizedBox(
              height: AppSizes.buttonHeight,
              width: double.infinity,
              child: FilledButton(
                onPressed: _canSubmit ? _submit : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                  disabledBackgroundColor:
                      AppColors.success.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSizes.radiusSm),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _busy ? 'Verifying…' : 'Complete delivery',
                      style: AppTextStyles.buttonLabel
                          .copyWith(color: Colors.white),
                    ),
                    const SizedBox(width: 6),
                    const Icon(PhosphorIconsBold.arrowRight,
                        color: Colors.white, size: 18),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.xxl),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(deliveryRepositoryProvider).markDelivered(
            widget.assignmentId,
            otp: _otp,
          );
      if (!mounted) return;
      // Refresh history so the completed screen and history tab see it.
      ref.invalidate(deliveryHistoryProvider);
      context.go(AppRoutes.deliveryCompletedFor(widget.assignmentId));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Invalid OTP. Please try again.';
      });
    }
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 60,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: AppTextStyles.display.copyWith(fontSize: 24),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: AppColors.surfaceAlt,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusSm + 2),
            borderSide: const BorderSide(color: AppColors.border, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusSm + 2),
            borderSide: const BorderSide(color: AppColors.border, width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusSm + 2),
            borderSide:
                const BorderSide(color: AppColors.success, width: 2),
          ),
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({
    required this.label,
    required this.checked,
    required this.onTap,
  });
  final String label;
  final bool checked;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.divider),
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: checked ? AppColors.success : Colors.transparent,
                border: Border.all(
                  color: checked ? AppColors.success : AppColors.border,
                  width: 2,
                ),
                borderRadius:
                    BorderRadius.circular(AppSizes.radiusXs + 2),
              ),
              child: checked
                  ? const Icon(PhosphorIconsBold.check,
                      color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(child: Text(label, style: AppTextStyles.body)),
          ],
        ),
      ),
    );
  }
}
