import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/charges_config.dart';
import '../../../shared/providers/charges_providers.dart';
import '../../../shared/providers/repositories_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/primary_button.dart';

class AdminChargesScreen extends ConsumerStatefulWidget {
  const AdminChargesScreen({super.key});

  @override
  ConsumerState<AdminChargesScreen> createState() =>
      _AdminChargesScreenState();
}

class _AdminChargesScreenState
    extends ConsumerState<AdminChargesScreen> {
  late TextEditingController _banquet;
  late TextEditingController _buffet;
  late TextEditingController _service;
  late TextEditingController _water;
  late TextEditingController _platform;
  late TextEditingController _gst;

  bool _saving = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _banquet = TextEditingController();
    _buffet = TextEditingController();
    _service = TextEditingController();
    _water = TextEditingController();
    _platform = TextEditingController();
    _gst = TextEditingController();
  }

  void _hydrate(ChargesConfig c) {
    if (_initialized) return;
    _banquet.text = c.banquetCharge.toStringAsFixed(0);
    _buffet.text = c.buffetSetup.toStringAsFixed(0);
    _service.text = c.serviceBoyCost.toStringAsFixed(0);
    _water.text = c.waterBottleCost.toStringAsFixed(0);
    _platform.text = c.platformFee.toStringAsFixed(0);
    _gst.text = c.gstPercent.toStringAsFixed(1);
    _initialized = true;
  }

  @override
  void dispose() {
    _banquet.dispose();
    _buffet.dispose();
    _service.dispose();
    _water.dispose();
    _platform.dispose();
    _gst.dispose();
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
      );
      await ref.read(chargesRepositoryProvider).update(cfg);
      ref.invalidate(chargesConfigProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Charges updated')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = ref.watch(chargesConfigProvider);

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Charges'),
        leading: IconButton(
          icon: const Icon(PhosphorIconsBold.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: cfg.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorView(
            error: e,
            onRetry: () => ref.invalidate(chargesConfigProvider)),
        data: (c) {
          _hydrate(c);
          return ListView(
            children: [
              const SizedBox(height: AppSizes.sm),
              Text(
                'Applied to every checkout',
                style: AppTextStyles.bodyMuted,
              ),
              const SizedBox(height: AppSizes.lg),
              AppCard(
                child: Column(
                  children: [
                    _ChargeRow(label: 'Banquet charge', controller: _banquet),
                    _ChargeRow(label: 'Buffet setup', controller: _buffet),
                    _ChargeRow(
                        label: 'Service boys', controller: _service),
                    _ChargeRow(label: 'Water bottles', controller: _water),
                    _ChargeRow(
                        label: 'Platform fee', controller: _platform),
                    _ChargeRow(
                      label: 'GST %',
                      controller: _gst,
                      suffix: '%',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.xl),
              PrimaryButton(
                label: 'Save changes',
                icon: PhosphorIconsBold.checkCircle,
                loading: _saving,
                onPressed: _save,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ChargeRow extends StatelessWidget {
  const _ChargeRow({
    required this.label,
    required this.controller,
    this.suffix,
  });
  final String label;
  final TextEditingController controller;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.body)),
          SizedBox(
            width: 140,
            child: TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: InputDecoration(
                prefixText: suffix == null ? '\u20B9 ' : null,
                suffixText: suffix,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.sm,
                  vertical: AppSizes.sm,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
