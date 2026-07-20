import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:banquet_catering_app/data/models/user_address.dart';
import 'package:banquet_catering_app/shared/providers/address_providers.dart';
import 'package:banquet_catering_app/shared/providers/event_providers.dart';
import 'package:banquet_catering_app/shared/providers/search_results_providers.dart';

/// customerCoordsProvider is THE location rule for every customer flow
/// (home feed, search distances, detail/cart serviceability, checkout).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const home = UserAddress(
    id: 'a1',
    userId: 'u1',
    label: AddressLabel.home,
    fullAddress: '12 Rose Villa, Delhi',
    latitude: 28.61,
    longitude: 77.21,
  );

  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer(
      overrides: [activeAddressProvider.overrideWith((_) => home)],
    );
  });

  tearDown(() => container.dispose());

  test('event coordinates win over the saved address', () {
    container.read(eventDraftProvider.notifier).setEventLocation(
          address: 'Grand Palace, Hyderabad',
          latitude: 17.44,
          longitude: 78.35,
        );
    final c = container.read(customerCoordsProvider);
    expect(c.lat, 17.44);
    expect(c.lng, 78.35);
  });

  test('planning WITHOUT coords never falls back to home (the core rule)', () {
    container
        .read(eventDraftProvider.notifier)
        .setEventLocation(address: 'Community Hall, Hyderabad');
    final c = container.read(customerCoordsProvider);
    expect(c.lat, isNull); // NOT Delhi's 28.61
    expect(c.lng, isNull);
  });

  test('not planning → the saved home address coordinates', () {
    final c = container.read(customerCoordsProvider);
    expect(c.lat, 28.61);
    expect(c.lng, 77.21);
  });
}
