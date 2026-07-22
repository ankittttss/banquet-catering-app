import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../data/models/charges_config.dart';
import '../../../shared/providers/charges_providers.dart';
import '../../../shared/providers/repositories_providers.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../widgets/admin_ui.dart';

/// Global fees/taxes applied to every checkout. Redesigned to the indigo
/// admin identity; all values persist through the real charges repository.
class AdminChargesScreen extends ConsumerStatefulWidget {
  const AdminChargesScreen({super.key});

  @override
  ConsumerState<AdminChargesScreen> createState() => _AdminChargesScreenState();
}

class _RowSpec {
  const _RowSpec(this.ctrl, this.label, this.hint, {this.percent = false});
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final bool percent;
}

class _AdminChargesScreenState extends ConsumerState<AdminChargesScreen> {
  final _banquet = TextEditingController();
  final _buffet = TextEditingController();
  final _service = TextEditingController();
  final _water = TextEditingController();
  final _platform = TextEditingController();
  final _gst = TextEditingController();
  final _serviceTax = TextEditingController();

  bool _saving = false;
  bool _initialized = false;
  bool _dirty = false;

  late final List<_RowSpec> _rows = [
    _RowSpec(_banquet, 'Banquet charge', 'Flat fee for banquet-hall bookings'),
    _RowSpec(_buffet, 'Buffet setup', 'Live counters, chafing & staff setup'),
    _RowSpec(_service, 'Service boy', 'Per head, per event'),
    _RowSpec(_water, 'Water bottles', 'Per guest'),
    _RowSpec(_platform, 'Platform fee', 'Dawat handling on every order'),
    _RowSpec(_gst, 'GST', 'Goods & services tax', percent: true),
    _RowSpec(_serviceTax, 'Service tax', 'Applied on service charges',
        percent: true),
  ];

  void _hydrate(ChargesConfig c) {
    if (_initialized) return;
    _banquet.text = c.banquetCharge.toStringAsFixed(0);
    _buffet.text = c.buffetSetup.toStringAsFixed(0);
    _service.text = c.serviceBoyCost.toStringAsFixed(0);
    _water.text = c.waterBottleCost.toStringAsFixed(0);
    _platform.text = c.platformFee.toStringAsFixed(0);
    _gst.text = c.gstPercent.toStringAsFixed(1);
    _serviceTax.text = c.serviceTaxPercent.toStringAsFixed(1);
    _initialized = true;
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final cfg = ChargesConfig(
        banquetCharge: double.tryParse(_banquet.text) ?? 0,
        buffetSetup: double.tryParse(_buffet.text) ?? 0,
        serviceBoyCost: double.tryParse(_service.text) ?? 0,
        waterBottleCost: double.tryParse(_water.text) ?? 0,
        platformFee: double.tryParse(_platform.text) ?? 0,
        gstPercent: double.tryParse(_gst.text) ?? 5,
        serviceTaxPercent: double.tryParse(_serviceTax.text) ?? 5,
      );
      await ref.read(chargesRepositoryProvider).update(cfg);
      ref.invalidate(chargesConfigProvider);
      if (!mounted) return;
      setState(() => _dirty = false);
      adminToast(context, 'Charges updated for all checkouts', success: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = ref.watch(chargesConfigProvider);

    return AdminScaffold(
      active: AdminNav.charges,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminBar(title: 'Charges & taxes', onBack: () => context.pop()),
          Expanded(
            child: cfg.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AdminColors.indigo),
              ),
              error: (e, _) => AppErrorView(
                error: e,
                onRetry: () => ref.invalidate(chargesConfigProvider),
              ),
              data: (c) {
                _hydrate(c);
                return Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _InfoBanner(),
                          const SizedBox(height: 16),
                          for (final r in _rows) ...[
                            _ChargeRow(
                              spec: r,
                              onChanged: () {
                                if (!_dirty) setState(() => _dirty = true);
                              },
                            ),
                            const SizedBox(height: 10),
                          ],
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    _Footer(
                      saving: _saving,
                      enabled: _dirty && !_saving,
                      onSave: _save,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.indigo050,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(PhosphorIconsFill.info,
              size: 20, color: AdminColors.indigo),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: const TextSpan(
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                    color: AdminColors.ink2),
                children: [
                  TextSpan(text: 'These apply to '),
                  TextSpan(
                      text: 'every customer checkout',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  TextSpan(text: '. Changes take effect immediately.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChargeRow extends StatelessWidget {
  const _ChargeRow({required this.spec, required this.onChanged});
  final _RowSpec spec;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(spec.label, style: AdminText.h3),
                const SizedBox(height: 2),
                Text(spec.hint, style: AdminText.cap),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 128,
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: AdminColors.line, width: 1.5),
            ),
            child: Row(
              children: [
                if (!spec.percent)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Text('₹',
                        style: TextStyle(
                            color: AdminColors.tx3,
                            fontWeight: FontWeight.w700)),
                  ),
                Expanded(
                  child: TextField(
                    controller: spec.ctrl,
                    onChanged: (_) => onChanged(),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.right,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                    ],
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.tx,
                        fontFeatures: [FontFeature.tabularFigures()]),
                    // filled:false + no borders so the field never paints a
                    // second box inside this one (the app theme fills inputs).
                    decoration: const InputDecoration(
                      isCollapsed: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (spec.percent)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text('%',
                        style: TextStyle(
                            color: AdminColors.tx3,
                            fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer(
      {required this.saving, required this.enabled, required this.onSave});
  final bool saving;
  final bool enabled;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: AdminColors.card,
        border: Border(top: BorderSide(color: AdminColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: AdminButton(
          label: saving ? 'Saving…' : 'Save changes',
          size: 'lg',
          expand: true,
          disabled: !enabled,
          leading: saving ? null : PhosphorIconsBold.check,
          onPressed: onSave,
        ),
      ),
    );
  }
}
