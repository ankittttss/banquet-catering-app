import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/chef.dart';

/// Catalogue of chefs who can take a free site recce. Stubbed for the
/// design-fidelity build; will be backed by a real chefs table later.
final chefsProvider = Provider<List<Chef>>((ref) {
  return const [
    Chef(
      id: 'vikrant_joshi',
      name: 'Chef Vikrant Joshi',
      rating: 4.9,
      headline: '14 yrs · ex-Taj · 320 events',
      tags: ['Wedding', 'Mughlai', 'Live counters'],
    ),
    Chef(
      id: 'reema_iyer',
      name: 'Chef Reema Iyer',
      rating: 4.8,
      headline: '9 yrs · Pure veg specialist · 184 events',
      tags: ['Pure veg', 'South Indian', 'Intimate'],
    ),
  ];
});

/// Five upcoming recce days starting three days from today. The seed is
/// deterministic against today's date so reload doesn't shuffle slots
/// under the user during a single session.
final recceDaysProvider = Provider<List<RecceDay>>((ref) {
  final today = DateTime.now();
  final start = DateTime(today.year, today.month, today.day)
      .add(const Duration(days: 3));
  // Quasi-random but stable per day-of-month so we can show "Full" and
  // booked-slot states without a backend.
  int seed(int dayOfMonth) =>
      (dayOfMonth * 2654435761) & 0x7fffffff;
  RecceDay buildDay(DateTime d) {
    final s = seed(d.day);
    final available = [2, 4, 0, 3, 5][s % 5];
    final allSlots = const ['10:00 AM', '11:30 AM', '1:00 PM', '3:30 PM', '5:00 PM'];
    final pickedCount = (s % 4) + 2; // 2-5 slots offered
    final slotsForDay = allSlots.take(pickedCount).toList();
    // Some slots are marked booked (strike-through in UI) to mirror
    // the design state. Slot at index 1 is booked on the seeded "Sat".
    final bookedIndex = (s ~/ 7) % slotsForDay.length;
    return RecceDay(
      date: d,
      slotsAvailable: available,
      slots: [
        for (var i = 0; i < slotsForDay.length; i++)
          RecceSlot(
            label: slotsForDay[i],
            hour: _parseHour(slotsForDay[i]),
            minute: _parseMinute(slotsForDay[i]),
            isBooked: i == bookedIndex && available > 0,
          ),
      ],
    );
  }
  return List.generate(5, (i) => buildDay(start.add(Duration(days: i))));
});

int _parseHour(String label) {
  // "10:00 AM" → 10 ; "1:00 PM" → 13 ; "12:00 PM" → 12 ; "12:00 AM" → 0
  final parts = label.split(' ');
  final hm = parts[0].split(':');
  var h = int.parse(hm[0]);
  final isPM = parts[1] == 'PM';
  if (h == 12) h = 0;
  if (isPM) h += 12;
  return h;
}

int _parseMinute(String label) {
  final parts = label.split(' ');
  final hm = parts[0].split(':');
  return int.parse(hm[1]);
}
