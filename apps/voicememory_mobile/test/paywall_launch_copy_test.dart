import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_paywall_copy.dart';
import 'package:voicememory_mobile/billing/value_moment_paywall.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';

void main() {
  test('paywall headline sells testing the loop', () {
    expect(
      ConsumerUiCopy.paywallHeadline,
      'Keep testing the loop ArchiveMe found.',
    );
    expect(
      ArchivePaywallVariantConfig.headline(ArchivePaywallVariant.b),
      ConsumerUiCopy.paywallHeadline,
    );
    expect(ValueMomentPaywallLogic.copyHeadline, ConsumerUiCopy.paywallHeadline);
  });

  test('paywall subhead sells tracking the loop across moments', () {
    expect(
      ConsumerUiCopy.paywallSubhead,
      contains('track the same loop across more moments'),
    );
  });

  test('paywall benefits include launch bullets', () {
    expect(
      ConsumerUiCopy.paywallBullets,
      contains('Track the loop across more moments'),
    );
    expect(
      ConsumerUiCopy.paywallBullets,
      contains('See what confirms or challenges it'),
    );
    expect(
      ConsumerUiCopy.paywallBullets,
      contains('Review what changed over time'),
    );
    expect(ConsumerUiCopy.paywallBullets, contains('Archive timeline'));
    expect(
      ArchivePaywallCopy.keyValueBullets,
      ConsumerUiCopy.paywallBullets,
    );
  });

  test('paywall CTAs match launch copy', () {
    expect(
      ConsumerUiCopy.paywallPrimaryCta,
      'Continue with ArchiveMe Pro',
    );
    expect(ConsumerUiCopy.paywallSecondaryCta, 'Not now');
    expect(ValueMomentPaywallLogic.ctaLabel, ConsumerUiCopy.paywallPrimaryCta);
    expect(
      ValueMomentPaywallLogic.secondaryLabel,
      ConsumerUiCopy.paywallSecondaryCta,
    );
  });
}
