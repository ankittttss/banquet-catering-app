import 'package:flutter_test/flutter_test.dart';

import 'package:banquet_catering_app/features/admin/screens/admin_restaurant_wizard_screen.dart';

/// The cuisine chip picker stores its selection in the existing free-text
/// `cuisines_display` column ("North Indian · Mughlai"), so no migration is
/// needed. These helpers are the only interpreter of that format — they have
/// to round-trip cleanly and must not mangle rows typed by hand before the
/// picker existed.
void main() {
  group('splitCuisines', () {
    test('null / empty / whitespace-only yields nothing', () {
      expect(splitCuisines(null), isEmpty);
      expect(splitCuisines(''), isEmpty);
      expect(splitCuisines('   '), isEmpty);
    });

    test('splits the format the app writes', () {
      expect(
        splitCuisines('North Indian · Mughlai · Chaat'),
        ['North Indian', 'Mughlai', 'Chaat'],
      );
    });

    test('tolerates legacy comma-separated rows', () {
      expect(
        splitCuisines('North Indian, Mughlai,Chaat'),
        ['North Indian', 'Mughlai', 'Chaat'],
      );
    });

    test('trims stray whitespace and drops empty segments', () {
      expect(
        splitCuisines('  North Indian  ··  Mughlai ,, '),
        ['North Indian', 'Mughlai'],
      );
    });

    test('a single value with no separator survives intact', () {
      expect(
          splitCuisines('Hyderabadi Dum Biryani'), ['Hyderabadi Dum Biryani']);
    });
  });

  group('joinCuisines', () {
    test('writes the canonical separator', () {
      expect(
          joinCuisines(['North Indian', 'Mughlai']), 'North Indian · Mughlai');
    });

    test('empty selection clears the field', () {
      expect(joinCuisines([]), '');
    });
  });

  group('round-trip', () {
    test('split → join → split is stable and preserves order', () {
      const original = 'Punjabi · Chinese · Continental';
      final parsed = splitCuisines(original);
      expect(joinCuisines(parsed), original);
      expect(splitCuisines(joinCuisines(parsed)), parsed);
    });

    test('a legacy comma row is normalised to the canonical separator', () {
      final parsed = splitCuisines('Punjabi,Chinese');
      expect(joinCuisines(parsed), 'Punjabi · Chinese');
    });

    test('a custom cuisine outside the fixed list is preserved verbatim', () {
      final parsed = splitCuisines('North Indian · Awadhi');
      expect(parsed, ['North Indian', 'Awadhi']);
      expect(joinCuisines(parsed), 'North Indian · Awadhi');
    });
  });
}
