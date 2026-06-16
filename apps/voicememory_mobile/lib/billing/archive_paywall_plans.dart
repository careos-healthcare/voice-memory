import 'package:purchases_flutter/purchases_flutter.dart';

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

bool packageListHasAnnual(List<Package> packages) =>
    packages.any((p) => p.packageType == PackageType.annual);

bool packageListHasMonthly(List<Package> packages) =>
    packages.any((p) => p.packageType == PackageType.monthly);

/// Sorts RevenueCat packages with annual/yearly before monthly when present.
List<Package> sortPackagesAnnualFirst(List<Package> packages) {
  final annual = <Package>[];
  final monthly = <Package>[];
  final other = <Package>[];
  for (final p in packages) {
    switch (p.packageType) {
      case PackageType.annual:
        annual.add(p);
      case PackageType.monthly:
        monthly.add(p);
      default:
        other.add(p);
    }
  }
  return [...annual, ...monthly, ...other];
}
