import '../product/consumer_ui_copy.dart';

/// App Store–safe restore purchase messaging.
abstract final class RestorePurchasesCopy {
  static const restorePurchases = ConsumerUiCopy.restorePurchases;

  static const purchaseRestored = 'Purchase restored';

  static const noActivePurchase =
      'No active purchase was found for this Apple ID.';

  static const restoreError =
      'We could not check purchases right now. Please try again.';

  static const billingUnavailable = ConsumerUiCopy.plansUnavailable;

  static const restoreScreenTitle = 'Restore purchases';

  static const restoreScreenBody =
      'Restore a subscription you already bought on this Apple or Google account.';

  static const restoreScreenSuccess =
      'Your subscription is active again on this device.';

  static const restoreScreenNoPurchase =
      'Restore finished — no active subscription found.';
}
