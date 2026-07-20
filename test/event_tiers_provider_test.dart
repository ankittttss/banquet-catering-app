import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:banquet_catering_app/data/models/event_tier.dart';
import 'package:banquet_catering_app/data/repositories/event_tier_repository.dart';
import 'package:banquet_catering_app/data/repositories/stub/stub_event_tier_repository.dart';
import 'package:banquet_catering_app/data/models/restaurant.dart';
import 'package:banquet_catering_app/shared/providers/event_tier_providers.dart';
import 'package:banquet_catering_app/shared/providers/repositories_providers.dart';

class _ThrowingTierRepo implements EventTierRepository {
  @override
  Future<List<EventTier>> fetchTiers() async =>
      throw Exception('supabase down');

  @override
  Future<List<Restaurant>> restaurantsForTier({
    required String tierId,
    double? latitude,
    double? longitude,
    double radiusKm = 10,
  }) async =>
      const [];
}

void main() {
  test(
      'a real repository error surfaces as AsyncError — NO silent fallback '
      'to non-UUID tiers (which the live database rejects)', () async {
    final container = ProviderContainer(
      overrides: [
        eventTierRepositoryProvider.overrideWithValue(_ThrowingTierRepo()),
      ],
    );
    addTearDown(container.dispose);
    await expectLater(
      container.read(eventTiersProvider.future),
      throwsA(isA<Exception>()),
    );
  });

  test('stub repository (offline dev) still provides the fallback tiers',
      () async {
    final container = ProviderContainer(
      overrides: [
        eventTierRepositoryProvider
            .overrideWithValue(StubEventTierRepository()),
      ],
    );
    addTearDown(container.dispose);
    final tiers = await container.read(eventTiersProvider.future);
    expect(tiers, isNotEmpty);
    expect(tiers.map((t) => t.code), contains('budget'));
    // Stub ids are UUID-SHAPED sentinels so they pass the shared cascade's
    // structural tier check, exactly like real database ids.
    expect(
      tiers.map((t) => t.id),
      contains('11111111-1111-4111-8111-111111111111'),
    );
  });

  group('resolveSelectedTier — persisted drafts with invalid tier ids', () {
    const active = [
      EventTier(
        id: '00000000-0000-0000-0000-000000000001',
        code: 'standard',
        label: 'Standard',
        description: 'x',
        perGuestMin: 250,
        perGuestMax: 400,
        sortOrder: 1,
      ),
      EventTier(
        id: '00000000-0000-0000-0000-000000000002',
        code: 'premium',
        label: 'Premium',
        description: 'x',
        perGuestMin: 400,
        perGuestMax: 700,
        sortOrder: 2,
      ),
    ];

    test('legacy fallback ids are treated as MISSING, not valid', () {
      for (final legacy in ['budget', 'standard', 'premium']) {
        expect(resolveSelectedTier(active, legacy), isNull,
            reason: 'legacy id "$legacy" must not resolve');
      }
    });

    test('a deactivated/deleted UUID is treated as missing', () {
      expect(
        resolveSelectedTier(active, '99999999-9999-9999-9999-999999999999'),
        isNull,
      );
    });

    test('a valid active id resolves to its tier', () {
      expect(
        resolveSelectedTier(active, active.first.id)?.code,
        'standard',
      );
    });

    test('null selection stays null (picker auto-selects the first)', () {
      expect(resolveSelectedTier(active, null), isNull);
    });
  });
}
