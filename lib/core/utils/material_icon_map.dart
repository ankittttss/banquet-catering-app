import 'package:flutter/material.dart';

/// Maps Material icon name strings (as stored in `event_categories.icon_name`
/// and `collections.icon_name`) to Flutter's built-in [Icons] constants.
/// Falls back to [Icons.local_activity] for unknown names so the UI never
/// shows a missing-icon blank.
IconData materialIconByName(String name) {
  switch (name) {
    // Event categories
    case 'cake':
      return Icons.cake_rounded;
    case 'favorite':
      return Icons.favorite_rounded;
    case 'business_center':
      return Icons.business_center_rounded;
    case 'house':
      return Icons.house_rounded;
    case 'groups':
      return Icons.groups_rounded;
    case 'auto_awesome':
      return Icons.auto_awesome_rounded;
    case 'diamond':
      return Icons.diamond_rounded;
    case 'celebration':
      return Icons.celebration_rounded;

    // Collections
    case 'set_meal':
      return Icons.set_meal_rounded;
    case 'rice_bowl':
      return Icons.rice_bowl_rounded;
    case 'card_giftcard':
      return Icons.card_giftcard_rounded;
    case 'local_fire_department':
      return Icons.local_fire_department_rounded;

    // Misc
    case 'restaurant':
      return Icons.restaurant_rounded;
    case 'star':
      return Icons.star_rounded;
    default:
      return Icons.local_activity_rounded;
  }
}
