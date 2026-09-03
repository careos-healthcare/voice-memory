/// User-facing subscription messaging — no SDK keys or internal billing terms.
library;

import 'package:archiveme_mobile/product/consumer_ui_copy.dart';

class SubscriptionCopy {
  SubscriptionCopy._();

  // Shown for BillingUnavailableException and RevenueCat config errors — a
  // terminal "unavailable" state, not a transient load, so it must not read
  // "Loading plans…" (the old alias to ConsumerUiCopy.plansUnavailable).
  static const String temporarilyUnavailable =
      ConsumerUiCopy.paywallSetupUnavailableBody;

  static const String paywallNoOfferings =
      ConsumerUiCopy.paywallSetupUnavailableBody;
}