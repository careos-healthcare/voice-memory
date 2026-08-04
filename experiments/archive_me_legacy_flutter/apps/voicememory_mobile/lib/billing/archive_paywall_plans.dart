/// Paid plan identifiers for ArchiveMe Pro paywall ordering.
enum PaywallPlanKind { annual, monthly }

/// Consumer-facing labels for subscription plans — annual first.
abstract class ArchivePaywallPlanCopy {
  ArchivePaywallPlanCopy._();

  static const String annualLabel = 'Best for long-term memory';
  static const String annualHelper =
      'Save your full pattern history across weeks and months.';
  static const String monthlyLabel = 'Monthly';
  static const String monthlyHelper = 'Keep ArchiveMe Pro month to month.';
}

/// Returns plan kinds in display order: annual before monthly.
List<PaywallPlanKind> orderedPaywallPlans({
  required bool hasAnnual,
  required bool hasMonthly,
}) {
  final plans = <PaywallPlanKind>[];
  if (hasAnnual) plans.add(PaywallPlanKind.annual);
  if (hasMonthly) plans.add(PaywallPlanKind.monthly);
  return plans;
}
