import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_paywall_copy.dart';
import 'package:voicememory_mobile/billing/value_moment_paywall.dart';
import 'package:voicememory_mobile/features/paywall_alignment/paywall_alignment_copy.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';

void main() {
  test('paywall headline sells full timeline continuity', () {
    expect(
      ConsumerUiCopy.paywallHeadline,
      PaywallAlignmentCopy.headline,
    );
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
    expect(
      ConsumerUiCopy.paywallSubhead,
      PaywallAlignmentCopy.body,
    );
  });

  test('paywall benefits include aligned timeline bullets', () {
    expect(
      ConsumerUiCopy.paywallBullets,
      contains('Longer proof trail'),
    );
    expect(
      ConsumerUiCopy.paywallBullets,
      contains('What returned over time'),
    );
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
