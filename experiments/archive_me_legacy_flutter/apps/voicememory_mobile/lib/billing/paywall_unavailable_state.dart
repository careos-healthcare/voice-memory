/// Button labels and rules when subscription plans are unavailable.
abstract final class PaywallUnavailableState {
  PaywallUnavailableState._();

  static const tryAgainLabel = 'Try again';
  static const continueWithoutProLabel = 'Continue without Pro';
  static const doneLabel = 'Done';

  static bool purchasesUnavailable({
    required bool billingReady,
    required bool hasPackages,
  }) => !billingReady || !hasPackages;

  static String primaryDismissLabel({required bool hideBenefits}) =>
      hideBenefits ? continueWithoutProLabel : doneLabel;
}
