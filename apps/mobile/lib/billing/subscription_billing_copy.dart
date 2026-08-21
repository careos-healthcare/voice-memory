/// Self-serve billing copy — cancellation-first, no support maze.
abstract final class SubscriptionBillingCopy {
  SubscriptionBillingCopy._();

  static const title = 'Subscription & billing';

  static const currentPlanTitle = 'Current plan';
  static const proPlanLabel = 'ArchiveMe Pro';
  static const freePlanLabel = 'Free';
  static const proPlanBody =
      'Full historical comparisons, weekly archive reviews, and the complete evidence trail across your archive.';
  static const freePlanBody =
      'Record moments and keep the evidence trail on your recent entries. Upgrade for Tier 2 historical analysis.';

  static const pricingTitle = 'Pro pricing';
  static const pricingBody =
      r'Monthly plans are typically $7–$9/month depending on region. Apple or Google shows the exact price before you confirm.';

  static const manageTitle = 'Manage subscription';
  static const manageBody =
      'Update payment, switch plans, or cancel anytime in your App Store or Google Play subscription settings — no email required.';
  static const manageCta = 'Open subscription settings';
  static const cancelTitle = 'Cancel anytime';
  static const cancelBody =
      'Cancellation takes effect at the end of your current billing period. You keep Pro access until then, and your saved moments stay on this device.';
  static const cancelStepsTitle = 'How to cancel';
  static const cancelStepsIos = [
    'Open Settings on your iPhone',
    'Tap your Apple ID → Subscriptions',
    'Select ArchiveMe Pro → Cancel Subscription',
  ];
  static const cancelStepsAndroid = [
    'Open Google Play Store',
    'Tap Profile → Payments & subscriptions → Subscriptions',
    'Select ArchiveMe Pro → Cancel subscription',
  ];

  static const restoreTitle = 'Restore purchases';
  static const restoreBody =
      'Already subscribed on this Apple ID or Google account? Restore to re-link Pro on this device.';
  static const restoreCta = 'Restore purchases';

  static const upgradeTitle = 'Upgrade to Pro';
  static const upgradeCta = 'See Pro plans';

  static const unavailableBody =
      'Purchases are not configured on this build. You can keep using ArchiveMe on the free tier.';

  static const trustSectionTitle = 'Trust & transparency';
  static const evidenceGuaranteeTitle = 'The Evidence Guarantee';
  static const evidenceGuaranteeBody =
      'Your trust mechanism and citation trails are never paywalled.';

  static const managementSectionTitle = 'Management & support';
  static const cancelSubscriptionTitle = 'Cancel subscription';
  static const cancelSubscriptionBody =
      'Manage or cancel your plan anytime with zero dark patterns.';
  static const billingSupportTitle = 'Human billing support';
  static const billingSupportBody =
      'Guaranteed human response path for any billing disputes.';
  static const billingSupportEmail = 'support@archiveme.app';

  static const proPlanActiveSubtitle = 'ArchiveMe Pro Active';
  static const freePlanCappedSubtitle = 'Free Tier (Evidence Capped)';
  static const proChipLabel = 'PRO';
  static const freeChipLabel = 'FREE';

  static const appleSubscriptionsUrl =
      'https://apps.apple.com/account/subscriptions';
  static const googleSubscriptionsUrl =
      'https://play.google.com/store/account/subscriptions';
}