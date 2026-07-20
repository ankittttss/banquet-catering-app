import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/supabase/supabase_client.dart' as sb;
import '../../../data/models/restaurant.dart';
import '../../../shared/providers/admin_restaurant_providers.dart';
import '../../../shared/providers/banquet_providers.dart';
import '../../../shared/providers/repositories_providers.dart';
import '../widgets/admin_ui.dart';

/// Onboarding pipeline counts per lifecycle state — four cheap count-only
/// queries (pageSize 1) instead of downloading the whole catalog.
final _kitchenCountsProvider =
    FutureProvider.autoDispose<Map<RestaurantStatus, int>>((ref) async {
  final repo = ref.read(adminRestaurantRepositoryProvider);
  final pages = await Future.wait([
    for (final s in RestaurantStatus.values)
      repo.fetchPage(status: s, pageSize: 1),
  ]);
  return {
    for (var i = 0; i < RestaurantStatus.values.length; i++)
      RestaurantStatus.values[i]: pages[i].total,
  };
});

/// Deliberately minimal admin console: onboard/manage kitchens, banquet
/// venues and the charges config — nothing else. Redesigned to the imported
/// indigo "Dawat Admin Console" identity; data stays 100% live.
class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(_kitchenCountsProvider);
    final venues = ref.watch(adminVenuesProvider).valueOrNull;

    return AdminScaffold(
      active: AdminNav.overview,
      child: RefreshIndicator(
        color: AdminColors.indigo,
        onRefresh: () async {
          ref.invalidate(_kitchenCountsProvider);
          ref.invalidate(adminRestaurantListProvider);
          ref.invalidate(adminVenuesProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            _Header(counts: counts),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AdminButton(
                    label: 'Onboard kitchen',
                    size: 'lg',
                    expand: true,
                    elevated: true,
                    leading: PhosphorIconsBold.plus,
                    onPressed: () => context.push(AppRoutes.adminRestaurantNew),
                  ),
                  const SizedBox(height: 22),
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 10),
                    child: AdminOverline('Manage'),
                  ),
                  _NavCard(
                    icon: PhosphorIconsDuotone.storefront,
                    iconColor: AdminColors.indigo,
                    title: 'Kitchens',
                    subtitle: counts.when(
                      loading: () => 'Counting…',
                      error: (_, __) => 'Open the catalog',
                      data: (c) => '${_fmt(_total(c))} in catalog',
                    ),
                    onTap: () => context.push(AppRoutes.adminRestaurants),
                  ),
                  const SizedBox(height: 10),
                  _NavCard(
                    icon: PhosphorIconsDuotone.mapPin,
                    iconColor: const Color(0xFF2B6CB0),
                    title: 'Banquet venues',
                    subtitle: venues == null
                        ? 'Onboard halls & keep locations pinned'
                        : '${venues.where((v) => v.isActive).length} active · ${venues.length} total',
                    onTap: () => context.push(AppRoutes.adminVenues),
                  ),
                  const SizedBox(height: 10),
                  _NavCard(
                    icon: PhosphorIconsDuotone.receipt,
                    iconColor: AdminColors.susp,
                    title: 'Charges & taxes',
                    subtitle: 'Applied to every checkout',
                    onTap: () => context.push(AppRoutes.adminCharges),
                  ),
                  const SizedBox(height: 20),
                  _SignOutButton(),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static int _total(Map<RestaurantStatus, int> c) =>
      c.values.fold(0, (a, b) => a + b);

  static String _fmt(int n) {
    // Indian grouping (12,34,567) for the catalog count.
    final s = n.toString();
    if (s.length <= 3) return s;
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final groups = <String>[];
    while (rest.length > 2) {
      groups.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) groups.insert(0, rest);
    return '${groups.join(',')},$last3';
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.counts});
  final AsyncValue<Map<RestaurantStatus, int>> counts;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-0.6, -1),
          end: Alignment(0.6, 1),
          colors: [AdminColors.ink, AdminColors.indigo700],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      AdminOverline('Admin console',
                          color: AdminColors.indigoA),
                      SizedBox(height: 4),
                      Text('Dawat operations',
                          style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                              height: 1.15,
                              color: Colors.white)),
                    ],
                  ),
                ),
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(PhosphorIconsBold.user,
                      size: 20, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _PipelineCard(counts: counts),
          ],
        ),
      ),
    );
  }
}

class _PipelineCard extends StatelessWidget {
  const _PipelineCard({required this.counts});
  final AsyncValue<Map<RestaurantStatus, int>> counts;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => context.push(AppRoutes.adminRestaurants),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Kitchens pipeline',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                  Text(
                    counts.maybeWhen(
                      data: (c) =>
                          '${AdminHomeScreen._fmt(AdminHomeScreen._total(c))} total',
                      orElse: () => '',
                    ),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AdminColors.indigoA),
                  ),
                  const SizedBox(width: 3),
                  const Icon(PhosphorIconsBold.caretRight,
                      size: 14, color: AdminColors.indigoA),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final s in RestaurantStatus.values) ...[
                    Expanded(child: _StatTile(status: s, counts: counts)),
                    if (s != RestaurantStatus.values.last)
                      const SizedBox(width: 8),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.status, required this.counts});
  final RestaurantStatus status;
  final AsyncValue<Map<RestaurantStatus, int>> counts;

  @override
  Widget build(BuildContext context) {
    final style = adminStatusStyle(status);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          counts.when(
            loading: () => const SizedBox(
              height: 24,
              child: Center(child: AdminSkeleton(width: 22, height: 16)),
            ),
            error: (_, __) => Text('—',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: style.fg)),
            data: (c) => Text('${c[status] ?? 0}',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: style.fg)),
          ),
          const SizedBox(height: 2),
          Text(style.label,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AdminColors.tx2)),
        ],
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AdminColors.indigo050,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AdminText.h2),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: AdminText.cap,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const Icon(PhosphorIconsBold.caretRight,
              size: 20, color: AdminColors.tx3),
        ],
      ),
    );
  }
}

class _SignOutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AdminButton(
      label: 'Sign out',
      variant: AdminBtn.ghost,
      expand: true,
      onPressed: () async {
        HapticFeedback.mediumImpact();
        if (AppConfig.hasSupabase) {
          try {
            await sb.auth.signOut();
          } catch (_) {
            // best effort — still route to login
          }
        }
        if (context.mounted) context.go(AppRoutes.login);
      },
    );
  }
}
