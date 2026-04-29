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
import 'app_card.dart';
import 'app_scaffold.dart';

/// Shared landing-page shell used by every operator role (banquet, restaurant,
/// manager, service-boy) until their full flows ship. Keeps sign-out wired and
/// surfaces the role's next-step tiles.
class RoleLandingScaffold extends ConsumerWidget {
  const RoleLandingScaffold({
    super.key,
    required this.title,
    required this.tagline,
    required this.tiles,
  });

  final String title;
  final String tagline;
  final List<RoleLandingTile> tiles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      appBar: AppBar(
        title: Text(title),
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
          Text(title, style: AppTextStyles.display),
          const SizedBox(height: AppSizes.xs),
          Text(tagline, style: AppTextStyles.bodyMuted),
          const SizedBox(height: AppSizes.xl),
          for (final tile in tiles) ...[
            _Tile(tile: tile),
            const SizedBox(height: AppSizes.md),
          ],
        ]
            .animate(interval: 60.ms)
            .fadeIn(duration: 300.ms)
            .slideY(begin: 0.06, end: 0),
      ),
    );
  }
}

class RoleLandingTile {
  const RoleLandingTile({
    required this.label,
    required this.desc,
    required this.icon,
    this.onTap,
    this.comingSoon = false,
  });

  final String label;
  final String desc;
  final IconData icon;
  final VoidCallback? onTap;
  final bool comingSoon;
}

class _Tile extends StatelessWidget {
  const _Tile({required this.tile});
  final RoleLandingTile tile;

  @override
  Widget build(BuildContext context) {
    final disabled = tile.comingSoon || tile.onTap == null;
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: AppCard(
        onTap: disabled
            ? () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Coming in a later phase'),
                  ),
                );
              }
            : tile.onTap,
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              child: Icon(tile.icon,
                  color: AppColors.primary, size: 30),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tile.label, style: AppTextStyles.heading2),
                  const SizedBox(height: 2),
                  Text(tile.desc, style: AppTextStyles.caption),
                ],
              ),
            ),
            if (tile.comingSoon)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('SOON',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    )),
              )
            else
              const Icon(PhosphorIconsBold.caretRight,
                  color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
