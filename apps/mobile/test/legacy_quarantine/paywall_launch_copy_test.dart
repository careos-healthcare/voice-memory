import 'package:archiveme_mobile/billing/archive_paywall_copy.dart';
import 'package:archiveme_mobile/billing/value_moment_paywall.dart';
import 'package:archiveme_mobile/features/paywall_alignment/paywall_alignment_copy.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('paywall headline sells full timeline continuity', () {
    expect(ConsumerUiCopy.paywallHeadline, PaywallAlignmentCopy.headline);
    expect(
      ArchivePaywallVariantConfig.headline(ArchivePaywallVariant.b),
      ConsumerUiCopy.paywallHeadline,
    );
    expect(
      ValueMomentPaywallLogic.copyHeadline,
      ConsumerUiCopy.paywallHeadline,
    );
  });

  test('paywall subhead sells timeline value', () {
    expect(ConsumerUiCopy.paywallSubhead, PaywallAlignmentCopy.body);
  });

  test('paywall benefits include aligned timeline bullets', () {
    expect(ConsumerUiCopy.paywallBullets, contains('Longer evidence history'));
    expect(ConsumerUiCopy.paywallBullets, contains('Timeline views over time'));
    expect(ArchivePaywallCopy.keyValueBullets, ConsumerUiCopy.paywallBullets);
  });

  test('paywall CTAs match launch copy', () {
    expect(ConsumerUiCopy.paywallPrimaryCta, 'Keep the longer trail');
    expect(ConsumerUiCopy.paywallSecondaryCta, 'Not now');
    expect(ValueMomentPaywallLogic.ctaLabel, ConsumerUiCopy.paywallPrimaryCta);
    expect(
      ValueMomentPaywallLogic.secondaryLabel,
      ConsumerUiCopy.paywallSecondaryCta,
    );
  });
}