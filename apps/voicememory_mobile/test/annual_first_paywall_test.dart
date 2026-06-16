import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_paywall_plans.dart';

void main() {
  test('annual appears before monthly when both present', () {
    final plans = orderedPaywallPlans(hasAnnual: true, hasMonthly: true);
    expect(plans.first, PaywallPlanKind.annual);
    expect(plans.last, PaywallPlanKind.monthly);
  });

  test('monthly only when annual missing', () {
    final plans = orderedPaywallPlans(hasAnnual: false, hasMonthly: true);
    expect(plans, [PaywallPlanKind.monthly]);
  });

  test('empty when no packages', () {
    final plans = orderedPaywallPlans(hasAnnual: false, hasMonthly: false);
    expect(plans, isEmpty);
  });

  test('annual label says best for long-term memory', () {
    expect(ArchivePaywallPlanCopy.annualLabel, 'Best for long-term memory');
    expect(ArchivePaywallPlanCopy.annualHelper, contains('weeks and months'));
  });

  test('monthly label and helper match launch copy', () {
    expect(ArchivePaywallPlanCopy.monthlyLabel, 'Monthly');
    expect(
      ArchivePaywallPlanCopy.monthlyHelper,
      'Keep ArchiveMe Pro month to month.',
    );
  });
}
