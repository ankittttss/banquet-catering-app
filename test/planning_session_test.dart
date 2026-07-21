import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:banquet_catering_app/data/models/cart_item.dart';
import 'package:banquet_catering_app/data/models/event_draft.dart';
import 'package:banquet_catering_app/data/models/menu_item.dart';
import 'package:banquet_catering_app/data/models/private_property.dart';
import 'package:banquet_catering_app/data/models/restaurant.dart';
import 'package:banquet_catering_app/data/models/user_address.dart';
import 'package:banquet_catering_app/data/models/venue_type.dart';
import 'package:banquet_catering_app/data/repositories/menu_repository.dart';
import 'package:banquet_catering_app/features/user/location_change.dart';
import 'package:banquet_catering_app/features/user/planning_session.dart';
import 'package:banquet_catering_app/shared/providers/address_providers.dart';
import 'package:banquet_catering_app/shared/providers/cart_providers.dart';
import 'package:banquet_catering_app/shared/providers/event_providers.dart';
import 'package:banquet_catering_app/shared/providers/search_results_providers.dart';

// Hyderabad candidate; NEAR is ~1.5 km (in range); FAR is Delhi ~1250 km.
const _hydLat = 17.44, _hydLng = 78.35;
const _nearLat = 17.45, _nearLng = 78.36;
const _farLat = 28.61, _farLng = 77.21;

MenuItem _item(String id, String restaurantId, {String? name}) => MenuItem(
      id: id,
      restaurantId: restaurantId,
      categoryId: 'c1',
      name: name ?? 'Dish $id',
      price: 100,
    );

Restaurant _rest(String id, {double? lat, double? lng}) =>
    Restaurant(id: id, name: 'Kitchen $id', latitude: lat, longitude: lng);

/// Minimal MenuRepository fake — only the three lookups the impact check uses.
class _FakeMenuRepo implements MenuRepository {
  _FakeMenuRepo({
    this.rows = const [],
    this.inactive = const {},
    this.unavailable = const {},
    this.fail = false,
  });

  final List<Restaurant> rows;
  final Set<String> inactive;
  final Set<String> unavailable;
  final bool fail;
  int restaurantCalls = 0;

  @override
  Future<List<Restaurant>> fetchRestaurantsByIds(Set<String> ids) async {
    restaurantCalls++;
    if (fail) throw Exception('network down');
    return rows.where((r) => ids.contains(r.id)).toList();
  }

  @override
  Future<Set<String>> fetchInactiveRestaurantIds(Set<String> ids) async {
    if (fail) throw Exception('network down');
    return inactive.intersection(ids);
  }

  @override
  Future<Set<String>> fetchUnavailableItemIds(Set<String> ids) async {
    if (fail) throw Exception('network down');
    return unavailable.intersection(ids);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

LocationImpact _impact({
  required List<CartItem> cart,
  Map<String, Restaurant> restaurants = const {},
  Set<String> inactive = const {},
  Set<String> unavailable = const {},
  bool venueWillClear = false,
  bool propertyWillClear = false,
}) =>
    computeLocationImpact(
      latitude: _hydLat,
      longitude: _hydLng,
      cart: cart,
      cartRestaurants: restaurants,
      inactiveRestaurantIds: inactive,
      unavailableItemIds: unavailable,
      venueWillClear: venueWillClear,
      propertyWillClear: propertyWillClear,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocationCandidate rejects unusable pins', () {
    test('accepts a real pinned address', () {
      final c = LocationCandidate.tryCreate(
        address: 'HITEC City',
        latitude: _hydLat,
        longitude: _hydLng,
      );
      expect(c, isNotNull);
      expect(c!.latitude, _hydLat);
    });

    test('rejects null, (0,0), out-of-bounds and NaN coordinates', () {
      LocationCandidate? make(double? lat, double? lng) =>
          LocationCandidate.tryCreate(
            address: 'Somewhere',
            latitude: lat,
            longitude: lng,
          );
      expect(make(null, null), isNull);
      expect(make(_hydLat, null), isNull);
      expect(make(0, 0), isNull); // null-island sentinel
      expect(make(95, 10), isNull); // latitude out of range
      expect(make(10, 200), isNull); // longitude out of range
      expect(make(double.nan, 10), isNull);
    });

    test('rejects a blank address even with coordinates', () {
      expect(
        LocationCandidate.tryCreate(
          address: '   ',
          latitude: _hydLat,
          longitude: _hydLng,
        ),
        isNull,
      );
    });
  });

  group('computeLocationImpact', () {
    test('removes out-of-range lines and keeps in-range', () {
      final cart = [
        CartItem(item: _item('i1', 'near', name: 'Paneer Tikka')),
        CartItem(item: _item('i2', 'far', name: 'Dal Makhani')),
      ];
      final impact = _impact(
        cart: cart,
        restaurants: {
          'near': _rest('near', lat: _nearLat, lng: _nearLng),
          'far': _rest('far', lat: _farLat, lng: _farLng),
        },
      );

      expect(impact.removedSignatures, [cart[1].signature]);
      expect(impact.keptLineCount, 1);
      expect(impact.removed.single.reason, CartLineRemovalReason.outOfRange);
    });

    test(
        'REMOVES coordinate-less restaurants — serviceability cannot be '
        'confirmed for a pinned event location', () {
      final cart = [CartItem(item: _item('i1', 'noCoords'))];
      final impact = _impact(
        cart: cart,
        restaurants: {'noCoords': _rest('noCoords')}, // no pin
      );
      expect(impact.removedLineCount, 1);
      expect(impact.keptLineCount, 0);
      expect(
        impact.removed.single.reason,
        CartLineRemovalReason.unverifiableDistance,
      );
    });

    test('removes a restaurant that could not be resolved at all', () {
      final cart = [CartItem(item: _item('i1', 'ghost'))];
      final impact = _impact(cart: cart, restaurants: const {});
      expect(
        impact.removed.single.reason,
        CartLineRemovalReason.restaurantInactive,
      );
    });

    test('removes lines whose restaurant is inactive, even if in range', () {
      final cart = [CartItem(item: _item('i1', 'near'))];
      final impact = _impact(
        cart: cart,
        restaurants: {'near': _rest('near', lat: _nearLat, lng: _nearLng)},
        inactive: {'near'},
      );
      expect(
        impact.removed.single.reason,
        CartLineRemovalReason.restaurantInactive,
      );
    });

    test('removes lines whose DISH is unavailable, even if in range', () {
      final cart = [CartItem(item: _item('i1', 'near'))];
      final impact = _impact(
        cart: cart,
        restaurants: {'near': _rest('near', lat: _nearLat, lng: _nearLng)},
        unavailable: {'i1'},
      );
      expect(
        impact.removed.single.reason,
        CartLineRemovalReason.itemUnavailable,
      );
    });

    test('reports exact dish details, and qty reads as PER GUEST', () {
      final cart = [
        CartItem(item: _item('i2', 'far', name: 'Dal Makhani'), qty: 3),
      ];
      final impact = _impact(
        cart: cart,
        restaurants: {'far': _rest('far', lat: _farLat, lng: _farLng)},
      );
      final removed = impact.removed.single;
      expect(removed.dishName, 'Dal Makhani');
      expect(removed.restaurantName, 'Kitchen far');
      expect(removed.qty, 3);
      expect(removed.label, contains('Dal Makhani'));
      expect(removed.label, contains('Kitchen far'));
      // Portions per guest — never "3 × items".
      expect(removed.label, contains('3 per guest'));
      expect(removed.label, isNot(contains('3 ×')));
    });

    test('two customised lines of the SAME dish are distinguishable', () {
      final cart = [
        CartItem(
          item: _item('i1', 'far', name: 'Paneer Tikka'),
          portion: Portion.large,
          spice: SpiceLevel.spicy,
        ),
        CartItem(
          item: _item('i1', 'far', name: 'Paneer Tikka'),
          notes: 'no onion',
        ),
      ];
      final impact = _impact(
        cart: cart,
        restaurants: {'far': _rest('far', lat: _farLat, lng: _farLng)},
      );

      expect(impact.removed, hasLength(2));
      final labels = impact.removed.map((r) => r.label).toList();
      // Same dish + kitchen, but the customisation tells them apart.
      expect(labels[0], isNot(labels[1]));
      expect(labels[0], contains('Large'));
      expect(labels[0], contains('Spicy'));
      expect(labels[1], contains('no onion'));
      // A default line carries no noisy "(Regular · Medium)" suffix.
      expect(impact.removed[1].variant, '“no onion”');
      // Each line is removed by its own signature.
      expect(
        impact.removedSignatures.toSet(),
        {cart[0].signature, cart[1].signature},
      );
    });

    test('a suspended restaurant row is removed', () {
      final cart = [CartItem(item: _item('i1', 'r1'))];
      final impact = _impact(
        cart: cart,
        restaurants: {
          'r1': Restaurant(
            id: 'r1',
            name: 'Kitchen r1',
            latitude: _nearLat,
            longitude: _nearLng,
            status: RestaurantStatus.suspended,
          ),
        },
      );
      expect(
        impact.removed.single.reason,
        CartLineRemovalReason.restaurantInactive,
      );
    });
  });

  group('planning_session actions', () {
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
    });
    tearDown(() => container.dispose());

    EventDraftController draftCtrl() =>
        container.read(eventDraftProvider.notifier);
    CartController cartCtrl() => container.read(cartProvider.notifier);

    const candidate = LocationCandidate(
      address: 'HITEC City',
      latitude: _hydLat,
      longitude: _hydLng,
    );

    test(
        'checkEventLocationChange folds in inactive restaurants AND '
        'unavailable dishes, mutating nothing', () async {
      draftCtrl().setBanquetVenue(
        venueId: 'v1',
        venueName: 'Grand Palace',
        latitude: 17.40,
        longitude: 78.40,
      );
      cartCtrl().add(_item('i1', 'near')); // in range, fine
      cartCtrl().add(_item('i2', 'dead')); // restaurant inactive
      cartCtrl().add(_item('i3', 'near')); // dish unavailable

      final draftBefore = container.read(eventDraftProvider).toJson();
      final cartBefore =
          container.read(cartProvider).map((l) => l.signature).toList();

      final impact = await checkEventLocationChange(
        candidate: candidate,
        draft: container.read(eventDraftProvider),
        cart: container.read(cartProvider),
        repository: _FakeMenuRepo(
          rows: [
            _rest('near', lat: _nearLat, lng: _nearLng),
            _rest('dead', lat: _nearLat, lng: _nearLng),
          ],
          inactive: {'dead'},
          unavailable: {'i3'},
        ),
      );

      expect(impact.venueWillClear, isTrue);
      expect(impact.removedLineCount, 2);
      expect(
        impact.removed.map((r) => r.reason).toSet(),
        {
          CartLineRemovalReason.restaurantInactive,
          CartLineRemovalReason.itemUnavailable,
        },
      );
      expect(impact.keptLineCount, 1);

      // Zero mutation before confirmation.
      expect(container.read(eventDraftProvider).toJson(), draftBefore);
      expect(
        container.read(cartProvider).map((l) => l.signature).toList(),
        cartBefore,
      );
    });

    test('a failed lookup rethrows and mutates nothing', () async {
      cartCtrl().add(_item('i1', 'near'));
      final cartBefore =
          container.read(cartProvider).map((l) => l.signature).toList();

      await expectLater(
        checkEventLocationChange(
          candidate: candidate,
          draft: container.read(eventDraftProvider),
          cart: container.read(cartProvider),
          repository: _FakeMenuRepo(fail: true),
        ),
        throwsA(isA<Exception>()),
      );
      expect(
        container.read(cartProvider).map((l) => l.signature).toList(),
        cartBefore,
      );
    });

    test(
        'applyEventLocationChange removes only invalid lines, sets the '
        'location and clears the venue', () async {
      draftCtrl().setBanquetVenue(
        venueId: 'v1',
        venueName: 'Grand Palace',
        latitude: 17.40,
        longitude: 78.40,
      );
      cartCtrl().add(_item('i1', 'near'));
      cartCtrl().add(_item('i2', 'far'));
      final nearSig = container.read(cartProvider).first.signature;

      final impact = await checkEventLocationChange(
        candidate: candidate,
        draft: container.read(eventDraftProvider),
        cart: container.read(cartProvider),
        repository: _FakeMenuRepo(rows: [
          _rest('near', lat: _nearLat, lng: _nearLng),
          _rest('far', lat: _farLat, lng: _farLng),
        ]),
      );

      applyEventLocationChange(
        draftController: draftCtrl(),
        cartController: cartCtrl(),
        candidate: candidate,
        impact: impact,
      );

      final draft = container.read(eventDraftProvider);
      expect(draft.location, 'HITEC City');
      expect(draft.eventLatitude, _hydLat);
      expect(draft.banquetVenueId, isNull);
      expect(
        container.read(cartProvider).map((l) => l.signature).toList(),
        [nearSig],
      );
    });

    test('checkBanquetVenueImpact REJECTS a venue with no usable pin',
        () async {
      cartCtrl().add(_item('i1', 'near'));
      await expectLater(
        checkBanquetVenueImpact(
          venueLatitude: null,
          venueLongitude: null,
          cart: container.read(cartProvider),
          repository: _FakeMenuRepo(),
        ),
        throwsA(isA<UnlocatableCandidate>()),
      );
      // …and (0,0) is treated as no pin, not as a real location.
      await expectLater(
        checkBanquetVenueImpact(
          venueLatitude: 0,
          venueLongitude: 0,
          cart: container.read(cartProvider),
          repository: _FakeMenuRepo(),
        ),
        throwsA(isA<UnlocatableCandidate>()),
      );
    });

    test(
        'applyBanquetVenueChange refuses an unpinnable venue and changes '
        'nothing', () {
      cartCtrl().add(_item('i1', 'near'));
      final cartBefore =
          container.read(cartProvider).map((l) => l.signature).toList();

      expect(
        () => applyBanquetVenueChange(
          draftController: draftCtrl(),
          cartController: cartCtrl(),
          venueId: 'v9',
          venueName: 'Unpinned Hall',
          latitude: null,
          longitude: null,
          impact: LocationImpact.none,
        ),
        throwsA(isA<UnlocatableCandidate>()),
      );
      expect(container.read(eventDraftProvider).banquetVenueId, isNull);
      expect(
        container.read(cartProvider).map((l) => l.signature).toList(),
        cartBefore,
      );
    });

    test(
        'applyBanquetVenueChange makes a pinned venue the event location and '
        'removes unreachable lines', () async {
      cartCtrl().add(_item('i1', 'far'));
      final impact = await checkBanquetVenueImpact(
        venueLatitude: _hydLat,
        venueLongitude: _hydLng,
        cart: container.read(cartProvider),
        repository:
            _FakeMenuRepo(rows: [_rest('far', lat: _farLat, lng: _farLng)]),
      );
      applyBanquetVenueChange(
        draftController: draftCtrl(),
        cartController: cartCtrl(),
        venueId: 'v9',
        venueName: 'Sunrise Hall',
        address: 'Banjara Hills',
        latitude: _hydLat,
        longitude: _hydLng,
        capacity: 500,
        impact: impact,
      );
      final draft = container.read(eventDraftProvider);
      expect(draft.banquetVenueId, 'v9');
      expect(draft.eventLatitude, _hydLat);
      expect(container.read(cartProvider), isEmpty);
    });

    test('an empty cart needs no lookups', () async {
      final repo = _FakeMenuRepo();
      final impact = await checkBanquetVenueImpact(
        venueLatitude: _hydLat,
        venueLongitude: _hydLng,
        cart: const [],
        repository: repo,
      );
      expect(impact.hasConsequences, isFalse);
      expect(repo.restaurantCalls, 0);
    });

    test('clearPlanningSession resets the draft and empties the cart', () {
      draftCtrl().setEventName('Wedding');
      draftCtrl().setBanquetVenue(venueId: 'v1', venueName: 'Grand Palace');
      cartCtrl().add(_item('i1', 'near'));

      clearPlanningSession(
        draftController: draftCtrl(),
        cartController: cartCtrl(),
      );

      expect(container.read(eventDraftProvider).toJson(),
          const EventDraft().toJson());
      expect(container.read(cartProvider), isEmpty);
    });

    test(
        'applied coordinates win over the saved home address (no home '
        'fallback while planning)', () {
      final withHome = ProviderContainer(
        overrides: [
          activeAddressProvider.overrideWith((_) => const UserAddress(
                id: 'a1',
                userId: 'u1',
                label: AddressLabel.home,
                fullAddress: '12 Rose Villa, Delhi',
                latitude: 28.61,
                longitude: 77.21,
              )),
        ],
      );
      addTearDown(withHome.dispose);

      applyEventLocationChange(
        draftController: withHome.read(eventDraftProvider.notifier),
        cartController: withHome.read(cartProvider.notifier),
        candidate: candidate,
        impact: LocationImpact.none,
      );
      final coords = withHome.read(customerCoordsProvider);
      expect(coords.lat, _hydLat); // event coords, NOT Delhi home
      expect(coords.lng, _hydLng);
    });
  });

  group('eventLocationChangeClearsProperty', () {
    test('true when the private property has address details', () {
      const draft = EventDraft(
        venueType: VenueType.privateProperty,
        propertyDraft: PrivatePropertyDraft(addressLine1: 'Sunset Farm'),
      );
      expect(eventLocationChangeClearsProperty(draft), isTrue);
    });

    test('false when there is no property or no address details', () {
      expect(eventLocationChangeClearsProperty(const EventDraft()), isFalse);
      expect(
        eventLocationChangeClearsProperty(
          const EventDraft(propertyDraft: PrivatePropertyDraft()),
        ),
        isFalse,
      );
    });
  });
}
