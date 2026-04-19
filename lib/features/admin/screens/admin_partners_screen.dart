import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/partner_invite.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';

final partnerInvitesProvider =
    FutureProvider.autoDispose<List<PartnerInvite>>((ref) async {
  if (!AppConfig.hasSupabase) return const [];
  final rows = await supabase
      .from('partner_invites')
      .select()
      .order('created_at', ascending: false);
  return rows.map(PartnerInvite.fromMap).toList(growable: false);
});

class AdminPartnersScreen extends ConsumerWidget {
  const AdminPartnersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invites = ref.watch(partnerInvitesProvider);

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Delivery partners'),
        leading: IconButton(
          icon: const Icon(PhosphorIconsBold.arrowLeft),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsBold.arrowClockwise),
            onPressed: () => ref.invalidate(partnerInvitesProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(PhosphorIconsBold.userPlus),
        label: const Text('Invite partner'),
        onPressed: () => _InviteForm.show(context, ref),
      ),
      body: invites.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorView(
            error: e, onRetry: () => ref.invalidate(partnerInvitesProvider)),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              title: 'No partners invited yet',
              message:
                  'Tap "Invite partner" to create a delivery account. '
                  'The driver signs up with that email to activate.',
              icon: PhosphorIconsDuotone.motorcycle,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(
              top: AppSizes.md,
              bottom: 96,
            ),
            itemBuilder: (_, i) => _InviteTile(invite: list[i]),
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSizes.sm),
            itemCount: list.length,
          );
        },
      ),
    );
  }
}

class _InviteTile extends StatelessWidget {
  const _InviteTile({required this.invite});
  final PartnerInvite invite;

  @override
  Widget build(BuildContext context) {
    final consumed = invite.isConsumed;
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: consumed
                  ? AppColors.catGreenLt
                  : AppColors.catGoldLt,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: Icon(
              consumed
                  ? PhosphorIconsFill.checkCircle
                  : PhosphorIconsFill.envelope,
              color:
                  consumed ? AppColors.success : AppColors.accent,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(invite.name, style: AppTextStyles.bodyBold),
                Text(
                  invite.email,
                  style: AppTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${invite.vehicle} · ${invite.vehicleNumber}',
                  style: AppTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: consumed
                      ? AppColors.catGreenLt
                      : AppColors.catGoldLt,
                  borderRadius:
                      BorderRadius.circular(AppSizes.radiusXs),
                ),
                child: Text(
                  consumed ? 'Joined' : 'Pending',
                  style: AppTextStyles.captionBold.copyWith(
                    color: consumed
                        ? AppColors.success
                        : AppColors.accentDark,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                Formatters.date(invite.createdAt),
                style: AppTextStyles.caption.copyWith(fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InviteForm extends ConsumerStatefulWidget {
  const _InviteForm();

  static Future<void> show(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _InviteForm(),
    );
    ref.invalidate(partnerInvitesProvider);
  }

  @override
  ConsumerState<_InviteForm> createState() => _InviteFormState();
}

class _InviteFormState extends ConsumerState<_InviteForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _vehicle = TextEditingController(text: 'Honda Activa');
  final _vehicleNumber = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    _phone.dispose();
    _vehicle.dispose();
    _vehicleNumber.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppSizes.radiusXl)),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSizes.pagePadding,
          AppSizes.md,
          AppSizes.pagePadding,
          AppSizes.lg,
        ),
        child: SafeArea(
          top: false,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusPill),
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.lg),
                Text('Invite a delivery partner',
                    style: AppTextStyles.heading1),
                const SizedBox(height: 4),
                Text(
                  'Driver signs up with this email to activate their account.',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: AppSizes.lg),
                _Field(
                  label: 'Email',
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? 'Valid email required' : null,
                ),
                _Field(
                  label: 'Full name',
                  controller: _name,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                _Field(
                  label: 'Phone',
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  validator: (v) =>
                      (v == null || v.trim().length < 8) ? 'Valid phone required' : null,
                ),
                _Field(
                  label: 'Vehicle',
                  controller: _vehicle,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                _Field(
                  label: 'Vehicle number',
                  controller: _vehicleNumber,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _error!,
                    style: AppTextStyles.captionBold
                        .copyWith(color: AppColors.primary),
                  ),
                ],
                const SizedBox(height: AppSizes.lg),
                SizedBox(
                  height: AppSizes.buttonHeight,
                  child: FilledButton(
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusSm),
                      ),
                    ),
                    child: Text(
                      _busy ? 'Inviting…' : 'Send invite',
                      style: AppTextStyles.buttonLabel
                          .copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await supabase.from('partner_invites').insert({
        'email': _email.text.trim().toLowerCase(),
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'vehicle': _vehicle.text.trim(),
        'vehicle_number': _vehicleNumber.text.trim(),
      });
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Invite sent. ${_email.text.trim()} can now sign up as a delivery partner.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not send invite: $e';
        _busy = false;
      });
    }
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.validator,
  });
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.captionBold
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surfaceAlt,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSizes.md,
                vertical: AppSizes.md,
              ),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppSizes.radiusMd),
                borderSide:
                    const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppSizes.radiusMd),
                borderSide:
                    const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppSizes.radiusMd),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
