/// User-facing subscription messaging — no SDK keys or internal billing terms.
library;

import '../product/consumer_ui_copy.dart';

class SubscriptionCopy {
  SubscriptionCopy._();

  static const String temporarilyUnavailable = ConsumerUiCopy.plansUnavailable;

  static const String paywallNoOfferings =
      ConsumerUiCopy.paywallSetupUnavailableBody;
}
