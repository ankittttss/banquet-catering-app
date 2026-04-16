import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/supabase/supabase_client.dart' as sb;
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_scaffold.dart';

class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Admin'),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsBold.signOut),
            tooltip: 'Sign out',
            onPressed: () async {
              if (AppConfig.hasSupabase) {
                await sb.auth.signOut();
              }
              if (context.mounted) context.go(AppRoutes.login);
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          const SizedBox(height: AppSizes.sm),
          Text('Dashboard', style: AppTextStyles.display),
          const SizedBox(height: AppSizes.xs),
          Text('Manage menu, charges, and bookings',
              style: AppTextStyles.bodyMuted),
          const SizedBox(height: AppSizes.xl),
          _AdminTile(
            label: 'Orders',
            desc: 'Review and update booking status',
            icon: PhosphorIconsDuotone.receipt,
            onTap: () => context.push(AppRoutes.adminOrders),
          ),
          const SizedBox(height: AppSizes.md),
          _AdminTile(
            label: 'Menu & restaurants',
            desc: 'Add, edit, or disable menu items',
            icon: PhosphorIconsDuotone.forkKnife,
            onTap: () => context.push(AppRoutes.adminMenu),
          ),
          const SizedBox(height: AppSizes.md),
          _AdminTile(
            label: 'Charges configuration',
            desc: 'Banquet, buffet, service, GST',
            icon: PhosphorIconsDuotone.currencyInr,
            onTap: () => context.push(AppRoutes.adminCharges),
          ),
        ]
            .animate(interval: 60.ms)
            .fadeIn(duration: 300.ms)
            .slideY(begin: 0.06, end: 0),
      ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  const _AdminTile({
    required this.label,
    required this.desc,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final String desc;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: Icon(icon, color: AppColors.primary, size: 30),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.heading2),
                const SizedBox(height: 2),
                Text(desc, style: AppTextStyles.caption),
              ],
            ),
          ),
          const Icon(PhosphorIconsBold.caretRight,
              color: AppColors.textMuted),
        ],
      ),
    );
  }
}
