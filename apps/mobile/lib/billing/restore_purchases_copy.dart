import 'package:archiveme_mobile/product/consumer_ui_copy.dart';

/// App Store–safe restore purchase messaging.
abstract final class RestorePurchasesCopy {
  static const String restorePurchases = ConsumerUiCopy.restorePurchases;

  static const purchaseRestored = 'Purchase restored. Pro is active.';

  static const noActivePurchase =
      'No previous Pro purchase was found on this Apple ID.';

  static const restoreError =
      'We could not check purchases right now. Please try again.';

  /// Restore-specific — never the new-purchase "plans unavailable" copy.
  static const String billingUnavailable = restoreError;

  static const restoreScreenTitle = 'Restore purchases';

  static const restoreScreenBody =
      'Restore a subscription you already bought on this Apple or Google account.';

  static const restoreScreenSuccess =
      'Your subscription is active again on this device.';

  static const restoreScreenNoPurchase =
      'Restore finished — no active subscription found.';
}