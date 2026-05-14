/// Where the user has chosen to host the event.
enum VenueType {
  banquetHall('banquet_hall', 'Banquet hall'),
  privateProperty('private_property', 'Private property');

  const VenueType(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static VenueType? fromDbValue(String? v) {
    if (v == null) return null;
    for (final t in values) {
      if (t.dbValue == v) return t;
    }
    return null;
  }
}
