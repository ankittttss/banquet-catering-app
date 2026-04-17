import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../data/models/user_address.dart';

/// UI-side mapping for [AddressLabel] — icon used in lists, pickers, cards.
extension AddressLabelPresentation on AddressLabel {
  IconData get icon => switch (this) {
        AddressLabel.home => PhosphorIconsDuotone.house,
        AddressLabel.work => PhosphorIconsDuotone.briefcase,
        AddressLabel.other => PhosphorIconsDuotone.mapPin,
      };
}
