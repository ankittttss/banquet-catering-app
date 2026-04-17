import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/order.dart';
import '../../../shared/presentation/order_status_presentation.dart';
import '../../../shared/providers/auth_providers.dart';
import '../../../shared/providers/repositories_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/user_bottom_nav.dart';

final myOrdersStreamProvider =
    StreamProvider.autoDispose<List<OrderSummary>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const Stream.empty();
  return ref.read(orderRepositoryProvider).streamMyOrders(userId);
});

final _viewModeProvider =
    StateProvider<_ViewMode>((ref) => _ViewMode.list);

enum _ViewMode { list, calendar }

class MyEventsScreen extends ConsumerWidget {
  const MyEventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(myOrdersStreamProvider);
    final mode = ref.watch(_viewModeProvider);

    return AppScaffold(
      appBar: AppBar(
        title: const Text('My Events'),
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSizes.md),
            child: _ViewToggle(mode: mode),
          ),
        ],
      ),
      body: orders.when(
        loading: () => _SkeletonList(),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              title: 'No events yet',
              message: 'Your first booking will show up here.',
              icon: PhosphorIconsDuotone.calendarPlus,
              actionLabel: 'Plan your first event',
              onAction: () => context.go(AppRoutes.eventDetails),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.invalidate(myOrdersStreamProvider),
            child: mode == _ViewMode.list
                ? ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSizes.md),
                    itemBuilder: (_, i) {
                      final o = list[i];
                      return _OrderCard(order: o)
                          .animate(delay: (i * 60).ms)
                          .fadeIn(duration: 320.ms)
                          .slideY(begin: 0.06, end: 0);
                    },
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSizes.md),
                    itemCount: list.length,
                  )
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: _CalendarView(orders: list),
                  ),
          );
        },
      ),
      bottomBar: const UserBottomNav(active: UserNavTab.events),
    );
  }
}

class _ViewToggle extends ConsumerWidget {
  const _ViewToggle({required this.mode});
  final _ViewMode mode;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      ),
      child: Row(
        children: [
          _toggle(
            icon: PhosphorIconsBold.listBullets,
            selected: mode == _ViewMode.list,
            onTap: () => ref.read(_viewModeProvider.notifier).state =
                _ViewMode.list,
          ),
          _toggle(
            icon: PhosphorIconsBold.calendar,
            selected: mode == _ViewMode.calendar,
            onTap: () => ref.read(_viewModeProvider.notifier).state =
                _ViewMode.calendar,
          ),
        ],
      ),
    );
  }

  Widget _toggle(
      {required IconData icon,
      required bool selected,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: AppSizes.xs,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSizes.radiusPill),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Icon(icon,
            size: 16,
            color: selected ? AppColors.primary : AppColors.textSecondary),
      ),
    );
  }
}

class _CalendarView extends StatefulWidget {
  const _CalendarView({required this.orders});
  final List<OrderSummary> orders;

  @override
  State<_CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<_CalendarView> {
  late DateTime _cursor;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _cursor = DateTime(now.year, now.month);
  }

  String _monthLabel(DateTime d) {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${names[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(_cursor.year, _cursor.month);
    final firstWeekday = DateTime(_cursor.year, _cursor.month, 1).weekday; // 1=Mon
    final leadingBlanks = firstWeekday - 1;
    final today = DateTime.now();

    final byDay = <int, List<OrderSummary>>{};
    for (final o in widget.orders) {
      if (o.eventDate == null) continue;
      if (o.eventDate!.year != _cursor.year ||
          o.eventDate!.month != _cursor.month) continue;
      byDay.putIfAbsent(o.eventDate!.day, () => []).add(o);
    }

    return Padding(
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(PhosphorIconsBold.caretLeft),
                onPressed: () => setState(() => _cursor =
                    DateTime(_cursor.year, _cursor.month - 1)),
              ),
              Expanded(
                child: Center(
                  child: Text(_monthLabel(_cursor),
                      style: AppTextStyles.heading2),
                ),
              ),
              IconButton(
                icon: const Icon(PhosphorIconsBold.caretRight),
                onPressed: () => setState(() => _cursor =
                    DateTime(_cursor.year, _cursor.month + 1)),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          Row(
            children: [
              for (final d in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Center(
                    child: Text(d, style: AppTextStyles.captionBold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSizes.xs),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: leadingBlanks + daysInMonth,
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemBuilder: (_, i) {
              if (i < leadingBlanks) return const SizedBox();
              final day = i - leadingBlanks + 1;
              final events = byDay[day] ?? const [];
              final isToday = today.year == _cursor.year &&
                  today.month == _cursor.month &&
                  today.day == day;

              return GestureDetector(
                onTap: events.isEmpty
                    ? null
                    : () => context
                        .push(AppRoutes.orderDetailFor(events.first.id)),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: events.isNotEmpty
                        ? AppColors.primarySoft
                        : Colors.transparent,
                    borderRadius:
                        BorderRadius.circular(AppSizes.radiusSm),
                    border: isToday
                        ? Border.all(color: AppColors.primary, width: 1.5)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: AppTextStyles.bodyBold.copyWith(
                          color: events.isNotEmpty
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                      if (events.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: AppSizes.lg),
          if (byDay.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSizes.xl),
              child: Text('No events this month',
                  style: AppTextStyles.bodyMuted),
            ),
        ],
      ),
    );
  }
}

class _SkeletonList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      loading: true,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
        itemBuilder: (_, __) => Container(
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          ),
        ),
        separatorBuilder: (_, __) =>
            const SizedBox(height: AppSizes.md),
        itemCount: 4,
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});
  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push(AppRoutes.orderDetailFor(order.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                order.eventDate == null
                    ? 'Date TBD'
                    : Formatters.date(order.eventDate!),
                style: AppTextStyles.heading2
                    .copyWith(color: AppColors.primary),
              ),
              const Spacer(),
              StatusBadge(
                label: order.orderStatus.label,
                tone: order.orderStatus.tone,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          Row(
            children: [
              const Icon(PhosphorIconsBold.users,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: AppSizes.xs),
              Text('${order.guestCount ?? "—"} guests',
                  style: AppTextStyles.caption),
              const SizedBox(width: AppSizes.md),
              const Icon(PhosphorIconsBold.receipt,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: AppSizes.xs),
              Text(Formatters.currency(order.total),
                  style: AppTextStyles.captionBold),
            ],
          ),
          if (order.location != null) ...[
            const SizedBox(height: AppSizes.xs),
            Row(
              children: [
                const Icon(PhosphorIconsBold.mapPin,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: AppSizes.xs),
                Expanded(
                  child: Text(
                    order.location!,
                    style: AppTextStyles.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
