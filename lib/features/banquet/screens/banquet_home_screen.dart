import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/widgets/role_landing_scaffold.dart';

class BanquetHomeScreen extends StatelessWidget {
  const BanquetHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleLandingScaffold(
      title: 'Banquet',
      tagline: 'Incoming bookings, staffing, equipment',
      tiles: [
        RoleLandingTile(
          label: 'Incoming bookings',
          desc: 'Accept or decline event requests routed to your venues',
          icon: PhosphorIconsDuotone.calendarCheck,
          onTap: () => context.push(AppRoutes.banquetInbox),
        ),
        RoleLandingTile(
          label: 'My venues',
          desc: 'Locations, capacity, availability',
          icon: PhosphorIconsDuotone.buildings,
          onTap: () => context.push(AppRoutes.banquetVenues),
        ),
        RoleLandingTile(
          label: 'Assign managers',
          desc: 'Put a manager in charge of each confirmed event',
          icon: PhosphorIconsDuotone.userCircleGear,
          onTap: () =>
              context.push('${AppRoutes.banquetInbox}?filter=accepted'),
        ),
        RoleLandingTile(
          label: 'Equipment & inventory',
          desc: 'Water bottles, setup packages, service supplies',
          icon: PhosphorIconsDuotone.package,
          onTap: () => context.push(AppRoutes.banquetInventory),
        ),
      ],
    );
  }
}
