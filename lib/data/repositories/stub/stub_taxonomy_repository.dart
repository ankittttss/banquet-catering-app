import '../../models/collection.dart';
import '../../models/event_category.dart';
import '../../models/restaurant_offer.dart';
import '../../models/trending_search.dart';
import '../taxonomy_repository.dart';

/// In-memory taxonomy for UI dev when Supabase isn't configured.
/// Mirrors the seed in `supabase/phase1_feast.sql` + `phase2_feast.sql`.
class StubTaxonomyRepository implements TaxonomyRepository {
  @override
  Future<List<EventCategory>> fetchEventCategories() async => _categories;

  @override
  Future<List<Collection>> fetchCollections() async => _collections;

  @override
  Future<List<RestaurantOffer>> fetchOffersFor(String restaurantId) async =>
      _offers
          .map((o) => RestaurantOffer(
                id: '${o.id}-$restaurantId',
                restaurantId: restaurantId,
                title: o.title,
                subtitle: o.subtitle,
                code: o.code,
                accentHex: o.accentHex,
                bgHex: o.bgHex,
                sortOrder: o.sortOrder,
              ))
          .toList(growable: false);

  @override
  Future<List<TrendingSearch>> fetchTrendingSearches() async => _trending;

  static const _categories = [
    EventCategory(
      id: 'ec1',
      slug: 'birthday',
      name: 'Birthday',
      emoji: '🎂',
      iconName: 'cake',
      bgHex: '#FFF1F2',
      iconHex: '#E23744',
      sortOrder: 1,
      defaultGuestCount: 30,
    ),
    EventCategory(
      id: 'ec2',
      slug: 'wedding',
      name: 'Wedding',
      emoji: '💖',
      iconName: 'favorite',
      bgHex: '#FCE8F0',
      iconHex: '#D63384',
      sortOrder: 2,
      defaultGuestCount: 250,
    ),
    EventCategory(
      id: 'ec3',
      slug: 'corporate',
      name: 'Corporate',
      emoji: '🏢',
      iconName: 'business_center',
      bgHex: '#EBF4FF',
      iconHex: '#2B6CB0',
      sortOrder: 3,
      defaultGuestCount: 80,
      defaultSession: 'Lunch',
    ),
    EventCategory(
      id: 'ec4',
      slug: 'house',
      name: 'House Party',
      emoji: '🏠',
      iconName: 'house',
      bgHex: '#FFF8E7',
      iconHex: '#E5A100',
      sortOrder: 4,
      defaultGuestCount: 25,
    ),
    EventCategory(
      id: 'ec5',
      slug: 'kitty',
      name: 'Kitty Party',
      emoji: '🎉',
      iconName: 'groups',
      bgHex: '#F3E8FF',
      iconHex: '#9B59B6',
      sortOrder: 5,
      defaultGuestCount: 20,
      defaultSession: 'Lunch',
    ),
    EventCategory(
      id: 'ec6',
      slug: 'festival',
      name: 'Festival',
      emoji: '🪔',
      iconName: 'auto_awesome',
      bgHex: '#FFF1F2',
      iconHex: '#E23744',
      sortOrder: 6,
      defaultGuestCount: 120,
    ),
    EventCategory(
      id: 'ec7',
      slug: 'anniversary',
      name: 'Anniversary',
      emoji: '💍',
      iconName: 'diamond',
      bgHex: '#EAFAF1',
      iconHex: '#1BA672',
      sortOrder: 7,
      defaultGuestCount: 60,
    ),
    EventCategory(
      id: 'ec8',
      slug: 'gettogether',
      name: 'Get-together',
      emoji: '🎊',
      iconName: 'celebration',
      bgHex: '#FFF8E7',
      iconHex: '#E5A100',
      sortOrder: 8,
      defaultGuestCount: 40,
    ),
  ];

  static const _collections = [
    Collection(
      id: 'col1',
      slug: 'platters',
      name: 'Party Platters',
      subtitle: '28 places',
      emoji: '🍽️',
      iconName: 'set_meal',
      bgHex: '#FFF1F2',
      iconHex: '#E23744',
      sortOrder: 1,
    ),
    Collection(
      id: 'col2',
      slug: 'biryani',
      name: 'Bulk Biryani',
      subtitle: '15 places',
      emoji: '🍚',
      iconName: 'rice_bowl',
      bgHex: '#FFF8E7',
      iconHex: '#E5A100',
      sortOrder: 2,
    ),
    Collection(
      id: 'col3',
      slug: 'sweets',
      name: 'Sweet Boxes',
      subtitle: '22 places',
      emoji: '🍬',
      iconName: 'card_giftcard',
      bgHex: '#F3E8FF',
      iconHex: '#9B59B6',
      sortOrder: 3,
    ),
    Collection(
      id: 'col4',
      slug: 'live',
      name: 'Live Counters',
      subtitle: '12 places',
      emoji: '🔥',
      iconName: 'local_fire_department',
      bgHex: '#EAFAF1',
      iconHex: '#1BA672',
      sortOrder: 4,
    ),
  ];

  /// Template offers — each is cloned per-restaurant by fetchOffersFor.
  static const _offers = [
    RestaurantOffer(
      id: 'offer1',
      restaurantId: '',
      title: '50% OFF up to ₹100',
      subtitle: 'Use code FEAST50 · Above ₹299',
      code: 'FEAST50',
      accentHex: '#2B6CB0',
      bgHex: '#EBF4FF',
      sortOrder: 1,
    ),
    RestaurantOffer(
      id: 'offer2',
      restaurantId: '',
      title: 'Free delivery on 50+ plates',
      subtitle: 'No code needed · Auto-applied',
      accentHex: '#1BA672',
      bgHex: '#EAFAF1',
      sortOrder: 2,
    ),
  ];

  static const _trending = [
    TrendingSearch(id: 't1', label: 'Biryani', emoji: '🍛', sortOrder: 1),
    TrendingSearch(
        id: 't2', label: 'Birthday Cakes', emoji: '🎂', sortOrder: 2),
    TrendingSearch(id: 't3', label: 'Veg Platters', emoji: '🥗', sortOrder: 3),
    TrendingSearch(id: 't4', label: 'North Indian', emoji: '🍲', sortOrder: 4),
    TrendingSearch(id: 't5', label: 'Dessert Boxes', emoji: '🍰', sortOrder: 5),
    TrendingSearch(id: 't6', label: 'South Indian', emoji: '🥥', sortOrder: 6),
    TrendingSearch(
        id: 't7', label: 'Pizza for Groups', emoji: '🍕', sortOrder: 7),
    TrendingSearch(id: 't8', label: 'Cupcakes', emoji: '🧁', sortOrder: 8),
  ];
}
