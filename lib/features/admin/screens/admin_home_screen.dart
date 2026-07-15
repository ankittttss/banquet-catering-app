import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/supabase/supabase_client.dart' as sb;
import '../../../core/utils/formatters.dart';
import '../../../data/models/order.dart';
import '../../../data/models/restaurant.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/models/user_role.dart';
import '../../../shared/presentation/order_status_presentation.dart';
import '../../../shared/providers/menu_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/status_badge.dart';
import 'admin_orders_screen.dart' show adminOrdersProvider;

// Deep-indigo chrome so the admin console never gets confused with the
// customer or operator apps.
const _indigoDeep = Color(0xFF1E1B4B);
const _indigo = Color(0xFF4338CA);
const _indigoMid = Color(0xFF3730A3);

enum _Tab {
  overview('Overview', PhosphorIconsBold.house),
  bookings('Bookings', PhosphorIconsBold.calendarBlank),
  kitchens('Kitchens', PhosphorIconsBold.fire),
  team('Team', PhosphorIconsBold.usersThree),
  payouts('Payouts', PhosphorIconsBold.ticket);

  const _Tab(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Real team roster for the admin console — profiles grouped by role. Requires
/// the admin to have read access to `profiles` (see phase33 RLS). Falls back to
/// an empty list without Supabase configured.
final _adminTeamProvider =
    FutureProvider.autoDispose<List<UserProfile>>((ref) async {
  if (!AppConfig.hasSupabase) return const [];
  final rows = await sb.supabase
      .from('profiles')
      .select()
      .inFilter('role', ['manager', 'service_boy', 'banquet', 'restaurant'])
      .order('role')
      .order('name');
  return rows.map<UserProfile>(UserProfile.fromMap).toList(growable: false);
});

(Color, Color) _tint(String name) => switch (name) {
      'blue' => (AppColors.catBlueLt, AppColors.catBlue),
      'red' => (AppColors.catRedLt, AppColors.catRed),
      'green' => (AppColors.catGreenLt, AppColors.catGreen),
      'gold' => (AppColors.catGoldLt, AppColors.catGold),
      'purple' => (AppColors.catPurpleLt, AppColors.catPurple),
      _ => (AppColors.catBlueLt, AppColors.catBlue),
    };

bool _isToday(DateTime? d) {
  if (d == null) return false;
  final n = DateTime.now();
  return d.year == n.year && d.month == n.month && d.day == n.day;
}

String _initials(String? name) {
  final n = (name ?? '').trim();
  if (n.isEmpty) return '?';
  final parts = n.split(RegExp(r'\s+'));
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return (parts[0].characters.first + parts[1].characters.first).toUpperCase();
}

class AdminHomeScreen extends ConsumerStatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  ConsumerState<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends ConsumerState<AdminHomeScreen> {
  _Tab _tab = _Tab.overview;

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(adminOrdersProvider);
    final orders = ordersAsync.valueOrNull ?? const <OrderSummary>[];
    final restaurants =
        ref.watch(restaurantsProvider).valueOrNull ?? const <Restaurant>[];
    final menuItems = ref.watch(adminMenuItemsProvider).valueOrNull ?? const [];

    // GMV this month + change vs last month, from real orders.
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1);
    var monthGmv = 0.0;
    var lastMonthGmv = 0.0;
    for (final o in orders) {
      if (o.orderStatus == OrderStatus.cancelled) continue;
      final d = o.createdAt;
      if (d.year == now.year && d.month == now.month) {
        monthGmv += o.total;
      } else if (d.year == lastMonth.year && d.month == lastMonth.month) {
        lastMonthGmv += o.total;
      }
    }
    final deltaPct = lastMonthGmv > 0
        ? (monthGmv - lastMonthGmv) / lastMonthGmv * 100
        : null;
    final liveToday = orders.where((o) => _isToday(o.eventDate)).toList();

    return AppScaffold(
      padded: false,
      backgroundColor: AppColors.surfaceWarm,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
              gmv: monthGmv, deltaPct: deltaPct, liveToday: liveToday.length),
          _TabBar(active: _tab, onChanged: (t) => setState(() => _tab = t)),
          Expanded(
            child: ordersAsync.isLoading && orders.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    color: _indigo,
                    onRefresh: () async {
                      ref.invalidate(adminOrdersProvider);
                      ref.invalidate(restaurantsProvider);
                      ref.invalidate(adminMenuItemsProvider);
                      ref.invalidate(_adminTeamProvider);
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        AppSizes.lg,
                        AppSizes.md,
                        AppSizes.lg,
                        AppSizes.xl,
                      ),
                      child: switch (_tab) {
                        _Tab.overview => _Overview(
                            orders: orders,
                            restaurants: restaurants,
                            menuItems: menuItems.length,
                            availableItems:
                                menuItems.where((m) => m.isAvailable).length,
                            liveToday: liveToday,
                            onGoTab: (t) => setState(() => _tab = t),
                          ),
                        _Tab.bookings => _BookingsTab(orders: orders),
                        _Tab.kitchens => _KitchensTab(
                            restaurants: restaurants, orders: orders),
                        _Tab.team => const _TeamTab(),
                        _Tab.payouts => const _PayoutsTab(),
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Header ─────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.gmv,
    required this.deltaPct,
    required this.liveToday,
  });
  final double gmv;
  final double? deltaPct;
  final int liveToday;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.md,
        AppSizes.pagePadding,
        AppSizes.md,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-0.7, -1),
          end: Alignment(0.7, 1),
          colors: [_indigoDeep, _indigo],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ADMIN CONSOLE',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.captionBold.copyWith(
                        color: Colors.white.withValues(alpha: 0.6),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Operations',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          AppTextStyles.displaySm.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Mumbai region · all systems live',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              _CircleIconButton(
                icon: PhosphorIconsBold.bell,
                badge: true,
                onTap: () => context.push(AppRoutes.notifications),
              ),
              const SizedBox(width: AppSizes.sm),
              const _AdminMenuButton(),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: _HeroKpi(
                    label: 'GMV this month',
                    value: '₹${(gmv / 100000).toStringAsFixed(1)}L',
                    trailing: deltaPct == null
                        ? Text(
                            'this month',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                deltaPct! >= 0
                                    ? PhosphorIconsBold.caretUp
                                    : PhosphorIconsBold.caretDown,
                                size: 12,
                                color: deltaPct! >= 0
                                    ? const Color(0xFF6EE7B7)
                                    : const Color(0xFFFCA5A5),
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  '${deltaPct!.abs().toStringAsFixed(0)}% vs last mo',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.caption.copyWith(
                                    color: deltaPct! >= 0
                                        ? const Color(0xFF6EE7B7)
                                        : const Color(0xFFFCA5A5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  flex: 2,
                  child: _HeroKpi(
                    label: 'Live today',
                    value: '$liveToday',
                    trailing: Text(
                      'events running',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroKpi extends StatelessWidget {
  const _HeroKpi({
    required this.label,
    required this.value,
    required this.trailing,
  });
  final String label;
  final String value;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption
                .copyWith(color: Colors.white.withValues(alpha: 0.65)),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          trailing,
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.badge = false,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Material(
        color: Colors.white.withValues(alpha: 0.14),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              if (badge)
                Positioned(
                  top: 8,
                  right: 9,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBBF24),
                      shape: BoxShape.circle,
                      border: Border.all(color: _indigoMid, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Overflow menu that keeps every existing admin tool reachable from the new
/// console (full orders manager, menu editor, charges, partners, sign out).
class _AdminMenuButton extends ConsumerWidget {
  const _AdminMenuButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Material(
        color: Colors.white.withValues(alpha: 0.14),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: PopupMenuButton<String>(
          icon: const Icon(PhosphorIconsBold.dotsThreeVertical,
              size: 18, color: Colors.white),
          onSelected: (v) async {
            switch (v) {
              case 'orders':
                context.push(AppRoutes.adminOrders);
              case 'menu':
                context.push(AppRoutes.adminMenu);
              case 'charges':
                context.push(AppRoutes.adminCharges);
              case 'partners':
                context.push(AppRoutes.adminPartners);
              case 'signout':
                if (AppConfig.hasSupabase) await sb.auth.signOut();
                if (context.mounted) context.go(AppRoutes.login);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'orders', child: Text('Full orders manager')),
            PopupMenuItem(value: 'menu', child: Text('Menu & items')),
            PopupMenuItem(value: 'charges', child: Text('Charges config')),
            PopupMenuItem(value: 'partners', child: Text('Delivery partners')),
            PopupMenuDivider(),
            PopupMenuItem(value: 'signout', child: Text('Sign out')),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Tab bar ─────────────────────────

class _TabBar extends StatelessWidget {
  const _TabBar({required this.active, required this.onChanged});
  final _Tab active;
  final ValueChanged<_Tab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceWarm,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
        child: Row(
          children: [for (final t in _Tab.values) _tabButton(t)],
        ),
      ),
    );
  }

  Widget _tabButton(_Tab t) {
    final on = t == active;
    final color = on ? _indigo : AppColors.textSecondary;
    return InkWell(
      onTap: () => onChanged(t),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: on ? _indigo : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(t.icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              t.label,
              style: AppTextStyles.buttonLabel.copyWith(
                fontSize: 14,
                color: color,
                fontWeight: on ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Overview ─────────────────────────

class _Overview extends StatelessWidget {
  const _Overview({
    required this.orders,
    required this.restaurants,
    required this.menuItems,
    required this.availableItems,
    required this.liveToday,
    required this.onGoTab,
  });

  final List<OrderSummary> orders;
  final List<Restaurant> restaurants;
  final int menuItems;
  final int availableItems;
  final List<OrderSummary> liveToday;
  final ValueChanged<_Tab> onGoTab;

  @override
  Widget build(BuildContext context) {
    final rated = restaurants.where((r) => r.rating != null).toList();
    final avg = rated.isEmpty
        ? null
        : rated.fold<double>(0, (s, r) => s + r.rating!) / rated.length;

    final stats = [
      _StatData('${orders.length}', 'Total bookings', 'all time', 'blue',
          PhosphorIconsBold.calendarBlank),
      _StatData('${restaurants.length}', 'Active kitchens', 'listed', 'red',
          PhosphorIconsBold.fire),
      _StatData('$menuItems', 'Menu items', '$availableItems available',
          'green', PhosphorIconsBold.forkKnife),
      _StatData(avg == null ? '—' : '${avg.toStringAsFixed(1)}★', 'Avg rating',
          '${rated.length} rated', 'gold', PhosphorIconsBold.star),
    ];

    // Alerts derived from real state.
    final pending =
        orders.where((o) => o.orderStatus == OrderStatus.placed).length;
    final inactive = restaurants.where((r) => !r.isActive).length;
    final hidden = menuItems - availableItems;
    final alerts = <Widget>[
      if (pending > 0)
        _AlertRow(
          kind: 'warning',
          icon: PhosphorIconsBold.clock,
          title:
              '$pending booking${pending == 1 ? '' : 's'} awaiting confirmation',
          sub: 'Review and confirm in Bookings',
          onTap: () => onGoTab(_Tab.bookings),
        ),
      if (inactive > 0)
        _AlertRow(
          kind: 'error',
          icon: PhosphorIconsBold.warning,
          title: '$inactive kitchen${inactive == 1 ? '' : 's'} under review',
          sub: 'Not visible to customers',
          onTap: () => onGoTab(_Tab.kitchens),
        ),
      if (hidden > 0)
        _AlertRow(
          kind: 'info',
          icon: PhosphorIconsBold.eyeSlash,
          title: '$hidden menu item${hidden == 1 ? '' : 's'} hidden',
          sub: 'Unavailable to customers · open the menu editor',
          onTap: () => context.push(AppRoutes.adminMenu),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _StatCard(data: stats[0])),
              const SizedBox(width: AppSizes.sm + 2),
              Expanded(child: _StatCard(data: stats[1])),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.sm + 2),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _StatCard(data: stats[2])),
              const SizedBox(width: AppSizes.sm + 2),
              Expanded(child: _StatCard(data: stats[3])),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.lg),
        Text('NEEDS YOUR ATTENTION', style: AppTextStyles.overline),
        const SizedBox(height: AppSizes.sm),
        if (alerts.isEmpty)
          _card(
            child: Row(
              children: [
                const Icon(PhosphorIconsBold.checkCircle,
                    size: 20, color: AppColors.success),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: Text('All clear — nothing needs attention.',
                      style: AppTextStyles.bodyMuted),
                ),
              ],
            ),
          )
        else
          for (var i = 0; i < alerts.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSizes.sm),
            alerts[i],
          ],
        const SizedBox(height: AppSizes.lg),
        Row(
          children: [
            Text('LIVE TODAY', style: AppTextStyles.overline),
            const Spacer(),
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text('Real-time',
                style: AppTextStyles.captionBold
                    .copyWith(color: AppColors.success, letterSpacing: 0)),
          ],
        ),
        const SizedBox(height: AppSizes.sm),
        if (liveToday.isEmpty)
          _card(
            child: Center(
              child: Text('No events scheduled for today.',
                  style: AppTextStyles.bodyMuted),
            ),
          )
        else
          for (final o in liveToday) ...[
            _LiveEventTile(order: o),
            const SizedBox(height: AppSizes.sm),
          ],
      ],
    );
  }

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(AppSizes.md + 2),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      );
}

class _StatData {
  const _StatData(this.value, this.label, this.detail, this.tint, this.icon);
  final String value;
  final String label;
  final String detail;
  final String tint;
  final IconData icon;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});
  final _StatData data;

  @override
  Widget build(BuildContext context) {
    final (soft, strong) = _tint(data.tint);
    return Container(
      padding: const EdgeInsets.all(AppSizes.md + 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: soft,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(data.icon, size: 17, color: strong),
          ),
          const SizedBox(height: AppSizes.sm),
          Text(
            data.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.displaySm,
          ),
          const SizedBox(height: 2),
          Text(
            data.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyBold.copyWith(fontSize: 12),
          ),
          Text(
            data.detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({
    required this.kind,
    required this.icon,
    required this.title,
    required this.sub,
    required this.onTap,
  });
  final String kind;
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (kind) {
      'error' => (AppColors.catRedLt, AppColors.error),
      'warning' => (AppColors.accentSoft, AppColors.accentDark),
      _ => (AppColors.catBlueLt, AppColors.info),
    };
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(AppSizes.md + 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
                child: Icon(icon, size: 18, color: fg),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyBold),
                    const SizedBox(height: 2),
                    Text(sub,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              const Icon(PhosphorIconsBold.caretRight,
                  size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveEventTile extends StatelessWidget {
  const _LiveEventTile({required this.order});
  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    final step = order.orderStatus.stepIndex; // 0..4, -1 cancelled
    final progress = step < 0 ? 0 : step;
    const total = 4;
    final done = progress >= total;
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            child: const Text('🎪', style: TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.eventName?.trim().isNotEmpty == true
                      ? order.eventName!
                      : 'Event',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyBold,
                ),
                const SizedBox(height: 2),
                Text(
                  '${order.guestCount ?? "—"} guests · ${order.orderStatus.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress / total,
                    minHeight: 4,
                    backgroundColor: AppColors.divider,
                    valueColor: AlwaysStoppedAnimation(
                      done ? AppColors.success : _indigo,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Formatters.currency(order.total),
                maxLines: 1,
                style: AppTextStyles.captionBold
                    .copyWith(color: AppColors.success, letterSpacing: 0),
              ),
              const SizedBox(height: 2),
              Text('$progress/$total',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Bookings ─────────────────────────

class _BookingsTab extends StatefulWidget {
  const _BookingsTab({required this.orders});
  final List<OrderSummary> orders;

  @override
  State<_BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<_BookingsTab> {
  final _ctrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _idLabel(OrderSummary o) {
    final id = o.eventId.length >= 6
        ? o.eventId.substring(0, 6).toUpperCase()
        : o.eventId.toUpperCase();
    return '#EVT-$id';
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase();
    final filtered = widget.orders.where((o) {
      if (q.isEmpty) return true;
      final hay =
          '${o.eventName ?? ''} ${o.eventId} ${o.location ?? ''}'.toLowerCase();
      return hay.contains(q);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(PhosphorIconsBold.magnifyingGlass,
                  size: 18, color: AppColors.textMuted),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  onChanged: (v) => setState(() => _q = v),
                  decoration: const InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: 'Search bookings, IDs, venues…',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.sm),
        Text('${filtered.length} bookings',
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: AppSizes.sm),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSizes.xl),
            child: Center(
              child: Text('No bookings match "$_q"',
                  style: AppTextStyles.bodyMuted),
            ),
          )
        else
          for (final o in filtered) ...[
            _BookingTile(order: o, idLabel: _idLabel(o)),
            const SizedBox(height: AppSizes.sm),
          ],
      ],
    );
  }
}

class _BookingTile extends StatelessWidget {
  const _BookingTile({required this.order, required this.idLabel});
  final OrderSummary order;
  final String idLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md + 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.eventName?.trim().isNotEmpty == true
                          ? order.eventName!
                          : 'Event',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyBold,
                    ),
                    const SizedBox(height: 2),
                    Text(idLabel,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textMuted,
                          fontFamily: 'monospace',
                        )),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              StatusBadge(
                label: order.orderStatus.label,
                tone: order.orderStatus.tone,
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSizes.sm),
            child: _DashedRule(),
          ),
          Row(
            children: [
              const Icon(PhosphorIconsBold.calendarBlank,
                  size: 13, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  order.eventDate == null
                      ? 'Date TBD'
                      : Formatters.date(order.eventDate!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(width: AppSizes.md),
              const Icon(PhosphorIconsBold.usersThree,
                  size: 13, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text('${order.guestCount ?? "—"}',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(width: AppSizes.sm),
              const Spacer(),
              Text(
                Formatters.currency(order.total),
                maxLines: 1,
                style: AppTextStyles.bodyBold.copyWith(color: _indigo),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Kitchens ─────────────────────────

class _KitchensTab extends StatelessWidget {
  const _KitchensTab({required this.restaurants, required this.orders});
  final List<Restaurant> restaurants;
  final List<OrderSummary> orders;

  @override
  Widget build(BuildContext context) {
    final byRestaurant = <String, List<OrderSummary>>{};
    for (final o in orders) {
      final rid = o.restaurantId;
      if (rid != null) byRestaurant.putIfAbsent(rid, () => []).add(o);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _IndigoButton(
                icon: PhosphorIconsBold.plus,
                label: 'Onboard kitchen',
                onTap: () => _soon(context, 'Kitchen onboarding'),
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            _OutlineIconButton(
              icon: PhosphorIconsBold.slidersHorizontal,
              onTap: () => context.push(AppRoutes.adminMenu),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.md),
        if (restaurants.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSizes.xl),
            child: Center(
              child: Text('No kitchens listed yet.',
                  style: AppTextStyles.bodyMuted),
            ),
          )
        else
          for (final r in restaurants) ...[
            _KitchenTile(
              restaurant: r,
              events: (byRestaurant[r.id] ?? const []).length,
              gmv: (byRestaurant[r.id] ?? const [])
                  .fold<double>(0, (s, o) => s + o.total),
            ),
            const SizedBox(height: AppSizes.sm),
          ],
      ],
    );
  }
}

class _KitchenTile extends StatelessWidget {
  const _KitchenTile({
    required this.restaurant,
    required this.events,
    required this.gmv,
  });
  final Restaurant restaurant;
  final int events;
  final double gmv;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md + 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.fromHex(restaurant.heroBgHex,
                  fallback: AppColors.surfaceAlt),
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            child: Text(restaurant.heroEmoji ?? '🍽️',
                style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(restaurant.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyBold),
                    ),
                    if (!restaurant.isActive) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accentSoft,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('REVIEW',
                            style: AppTextStyles.captionBold.copyWith(
                                color: AppColors.accentDark, fontSize: 9)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$events events'
                  '${restaurant.rating != null ? ' · ⭐ ${restaurant.rating}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 4),
                Text('GMV ₹${(gmv / 100000).toStringAsFixed(1)}L',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          const Icon(PhosphorIconsBold.caretRight,
              size: 18, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

// ───────────────────────── Team (real roster) ─────────────────────────

class _TeamTab extends ConsumerWidget {
  const _TeamTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_adminTeamProvider);
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: AppSizes.xxl),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _PlaceholderNote('Couldn\'t load team: $e'),
      data: (people) {
        final managers =
            people.where((p) => p.role == UserRole.manager).toList();
        final crew =
            people.where((p) => p.role == UserRole.serviceBoy).toList();
        final banquet =
            people.where((p) => p.role == UserRole.banquet).toList();
        final vendors =
            people.where((p) => p.role == UserRole.restaurant).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (people.isEmpty)
              const _PlaceholderNote(
                'No team members visible. If you expect managers/crew here, '
                'the admin needs read access to profiles (run phase33 RLS).',
              ),
            _IndigoButton(
              icon: PhosphorIconsBold.plus,
              label: 'Add team member',
              onTap: () => _soon(context, 'Team management'),
            ),
            const SizedBox(height: AppSizes.lg),
            _RoleGroup(
              title: 'Event managers',
              tint: 'gold',
              icon: PhosphorIconsBold.diamond,
              people: managers,
            ),
            const SizedBox(height: AppSizes.md),
            _RoleGroup(
              title: 'Service crew',
              tint: 'green',
              icon: PhosphorIconsBold.usersThree,
              people: crew,
            ),
            if (banquet.isNotEmpty) ...[
              const SizedBox(height: AppSizes.md),
              _RoleGroup(
                title: 'Banquet operators',
                tint: 'blue',
                icon: PhosphorIconsBold.storefront,
                people: banquet,
              ),
            ],
            if (vendors.isNotEmpty) ...[
              const SizedBox(height: AppSizes.md),
              _RoleGroup(
                title: 'Restaurant partners',
                tint: 'red',
                icon: PhosphorIconsBold.fire,
                people: vendors,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _RoleGroup extends StatelessWidget {
  const _RoleGroup({
    required this.title,
    required this.tint,
    required this.icon,
    required this.people,
  });
  final String title;
  final String tint;
  final IconData icon;
  final List<UserProfile> people;

  @override
  Widget build(BuildContext context) {
    final (soft, strong) = _tint(tint);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: soft,
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: Icon(icon, size: 16, color: strong),
            ),
            const SizedBox(width: AppSizes.sm),
            Expanded(
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.heading2),
            ),
            const SizedBox(width: AppSizes.sm),
            Text('${people.length}',
                style: AppTextStyles.captionBold.copyWith(
                    color: AppColors.textSecondary, letterSpacing: 0)),
          ],
        ),
        const SizedBox(height: AppSizes.sm),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: people.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(AppSizes.md),
                  child: Text('None yet',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textMuted)),
                )
              : Column(
                  children: [
                    for (var i = 0; i < people.length; i++)
                      Container(
                        decoration: BoxDecoration(
                          border: i == 0
                              ? null
                              : const Border(
                                  top: BorderSide(color: AppColors.divider)),
                        ),
                        child: _PersonRow(person: people[i], tint: tint),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.person, required this.tint});
  final UserProfile person;
  final String tint;

  @override
  Widget build(BuildContext context) {
    final (soft, strong) = _tint(tint);
    final subtitle = person.phone?.trim().isNotEmpty == true
        ? person.phone!
        : (person.email?.trim().isNotEmpty == true
            ? person.email!
            : person.role.label);
    return Padding(
      padding: const EdgeInsets.all(AppSizes.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: soft,
              shape: BoxShape.circle,
            ),
            child: Text(
              _initials(person.name),
              style: AppTextStyles.bodyBold.copyWith(color: strong),
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person.name?.trim().isNotEmpty == true
                      ? person.name!
                      : 'Unnamed',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyBold,
                ),
                const SizedBox(height: 2),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Payouts (illustrative) ─────────────────────────

class _PayoutsTab extends StatelessWidget {
  const _PayoutsTab();

  @override
  Widget build(BuildContext context) {
    const pending = [
      _Payout('Royal Banquet Kitchen', 'PO-4471', 68000, 'Due today', 'gold'),
      _Payout('Spice Route Catering', 'PO-4468', 42000, 'Due today', 'red'),
      _Payout('Annapurna Bhog', 'PO-4465', 31000, 'Due in 2 days', 'green'),
      _Payout(
          'Setup crew · batch #18', 'PO-4460', 24500, 'Due in 2 days', 'blue'),
    ];
    final total = pending.fold<int>(0, (s, p) => s + p.amt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PlaceholderNote(
          'Payouts are illustrative — no settlement backend yet.',
        ),
        const SizedBox(height: AppSizes.md),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(AppSizes.md + 2),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFB45309), Color(0xFFF59E0B)],
                    ),
                    borderRadius:
                        BorderRadius.all(Radius.circular(AppSizes.radiusMd)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Pending payouts',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                              color: Colors.white.withValues(alpha: 0.85))),
                      const SizedBox(height: 2),
                      Text('₹${(total / 1000).toStringAsFixed(1)}k',
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                      const SizedBox(height: 2),
                      Text('${pending.length} vendors',
                          style: AppTextStyles.caption.copyWith(
                              color: Colors.white.withValues(alpha: 0.85))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(AppSizes.md + 2),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Settled this month',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textMuted)),
                      const SizedBox(height: 2),
                      Text('₹8.4L',
                          style: AppTextStyles.displaySm
                              .copyWith(color: AppColors.success)),
                      const SizedBox(height: 2),
                      Text('142 payouts',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.md),
        _IndigoButton(
          icon: PhosphorIconsBold.check,
          label: 'Approve all due today',
          onTap: () => _soon(context, 'Payout approvals'),
        ),
        const SizedBox(height: AppSizes.lg),
        Text('AWAITING APPROVAL', style: AppTextStyles.overline),
        const SizedBox(height: AppSizes.sm),
        for (final p in pending) ...[
          _PayoutTile(payout: p),
          const SizedBox(height: AppSizes.sm),
        ],
      ],
    );
  }
}

class _Payout {
  const _Payout(this.name, this.id, this.amt, this.due, this.tint);
  final String name;
  final String id;
  final int amt;
  final String due;
  final String tint;
}

class _PayoutTile extends StatelessWidget {
  const _PayoutTile({required this.payout});
  final _Payout payout;

  @override
  Widget build(BuildContext context) {
    final (soft, strong) = _tint(payout.tint);
    final dueToday = payout.due == 'Due today';
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: soft,
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            child: Text(
              payout.name.substring(0, 2).toUpperCase(),
              style: AppTextStyles.bodyBold.copyWith(color: strong),
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(payout.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyBold),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${payout.id} · ',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textMuted),
                      ),
                      TextSpan(
                        text: payout.due,
                        style: AppTextStyles.caption.copyWith(
                          color:
                              dueToday ? AppColors.error : AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₹${(payout.amt / 1000).toStringAsFixed(0)}k',
                  style: AppTextStyles.heading2),
              const SizedBox(height: 4),
              Material(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                child: InkWell(
                  onTap: () => _soon(context, 'Payout approvals'),
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    child: Text('Approve',
                        style: AppTextStyles.captionBold
                            .copyWith(color: Colors.white, letterSpacing: 0)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Shared bits ─────────────────────────

class _IndigoButton extends StatelessWidget {
  const _IndigoButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _indigo,
      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.buttonLabel
                        .copyWith(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlineIconButton extends StatelessWidget {
  const _OutlineIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        child: Container(
          width: 48,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 18, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _PlaceholderNote extends StatelessWidget {
  const _PlaceholderNote(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        border: Border.all(color: AppColors.catGoldLt),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(PhosphorIconsBold.info,
              size: 16, color: AppColors.accentDark),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(text,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.accentDark)),
          ),
        ],
      ),
    );
  }
}

class _DashedRule extends StatelessWidget {
  const _DashedRule();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 1,
      child: CustomPaint(painter: _DashedRulePainter()),
    );
  }
}

class _DashedRulePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const dash = 4.0, gap = 4.0;
    final paint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0.5), Offset(x + dash, 0.5), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRulePainter oldDelegate) => false;
}

void _soon(BuildContext context, String what) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('$what is coming soon'),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
