import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/restaurant.dart';
import 'menu_providers.dart';

// ---------------------------------------------------------------------------
// Event types — shown as round icon carousel on home.
// Tapping one will pre-fill sensible defaults in the event-details flow later.
// ---------------------------------------------------------------------------
class EventType {
  const EventType({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.defaultGuestCount,
    required this.defaultSession,
  });

  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final int defaultGuestCount;
  final String defaultSession;
}

final eventTypesProvider = Provider<List<EventType>>((ref) => const [
      EventType(
        id: 'wedding',
        label: 'Wedding',
        icon: PhosphorIconsDuotone.heart,
        color: AppColors.primary,
        defaultGuestCount: 250,
        defaultSession: 'Dinner',
      ),
      EventType(
        id: 'birthday',
        label: 'Birthday',
        icon: PhosphorIconsDuotone.cake,
        color: Color(0xFFD4A574),
        defaultGuestCount: 40,
        defaultSession: 'Lunch',
      ),
      EventType(
        id: 'engagement',
        label: 'Engagement',
        icon: PhosphorIconsDuotone.sparkle,
        color: Color(0xFFB23A5E),
        defaultGuestCount: 150,
        defaultSession: 'Dinner',
      ),
      EventType(
        id: 'corporate',
        label: 'Corporate',
        icon: PhosphorIconsDuotone.briefcase,
        color: Color(0xFF4A6B8A),
        defaultGuestCount: 80,
        defaultSession: 'Lunch',
      ),
      EventType(
        id: 'festival',
        label: 'Festival',
        icon: PhosphorIconsDuotone.confetti,
        color: Color(0xFFD99A3E),
        defaultGuestCount: 120,
        defaultSession: 'Dinner',
      ),
      EventType(
        id: 'house',
        label: 'House Party',
        icon: PhosphorIconsDuotone.house,
        color: Color(0xFF4A7C59),
        defaultGuestCount: 25,
        defaultSession: 'Dinner',
      ),
      EventType(
        id: 'anniversary',
        label: 'Anniversary',
        icon: PhosphorIconsDuotone.champagne,
        color: Color(0xFF8B1E3F),
        defaultGuestCount: 60,
        defaultSession: 'Dinner',
      ),
    ]);

final selectedEventTypeProvider = StateProvider<String?>((ref) => null);

// ---------------------------------------------------------------------------
// Cuisine filters — horizontal pill row
// ---------------------------------------------------------------------------
class Cuisine {
  const Cuisine(this.id, this.label, this.emoji);
  final String id;
  final String label;
  final String emoji;
}

final cuisinesProvider = Provider<List<Cuisine>>((ref) => const [
      Cuisine('north-indian', 'North Indian', '🍛'),
      Cuisine('mughlai', 'Mughlai', '🥘'),
      Cuisine('south-indian', 'South Indian', '🍲'),
      Cuisine('continental', 'Continental', '🍝'),
      Cuisine('chinese', 'Chinese', '🥡'),
      Cuisine('desserts', 'Desserts', '🍰'),
      Cuisine('street', 'Street Food', '🥟'),
    ]);

final selectedCuisineProvider = StateProvider<String?>((ref) => null);

// ---------------------------------------------------------------------------
// Featured banners (carousel)
// ---------------------------------------------------------------------------
class HomeBanner {
  const HomeBanner({
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.imageUrl,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final String ctaLabel;
  final String imageUrl;
  final Color accent;
}

final bannersProvider = Provider<List<HomeBanner>>((ref) => const [
      HomeBanner(
        title: 'Wedding-season specials',
        subtitle: 'Curated menus starting from ₹650 / plate',
        ctaLabel: 'Explore',
        imageUrl:
            'https://images.unsplash.com/photo-1519225421980-715cb0215aed?w=900&q=80&auto=format&fit=crop',
        accent: Color(0xFF8B1E3F),
      ),
      HomeBanner(
        title: 'First booking · 10% off',
        subtitle: 'Use code DAWAT10 at checkout',
        ctaLabel: 'Plan event',
        imageUrl:
            'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=900&q=80&auto=format&fit=crop',
        accent: Color(0xFFD4A574),
      ),
      HomeBanner(
        title: 'Corporate catering',
        subtitle: 'Hassle-free bulk orders for office events',
        ctaLabel: 'Learn more',
        imageUrl:
            'https://images.unsplash.com/photo-1555244162-803834f70033?w=900&q=80&auto=format&fit=crop',
        accent: Color(0xFF4A6B8A),
      ),
    ]);

// ---------------------------------------------------------------------------
// Popular restaurants — for now, just the active set sorted by name.
// When we add a `popularity_score` column, change the repo order.
// ---------------------------------------------------------------------------
final popularRestaurantsProvider =
    Provider<AsyncValue<List<Restaurant>>>((ref) {
  return ref.watch(restaurantsProvider);
});

// ---------------------------------------------------------------------------
// Home search — the sticky search bar's query
// ---------------------------------------------------------------------------
final homeSearchProvider = StateProvider<String>((ref) => '');
