import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_paywall_copy.dart';
import 'package:voicememory_mobile/billing/value_moment_paywall.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';

void main() {
  test('paywall headline sells archive continuity', () {
    expect(
      ConsumerUiCopy.paywallHeadline,
      'Keep your archive useful over time.',
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

  test('paywall subhead sells deeper history over time', () {
    expect(
      ConsumerUiCopy.paywallSubhead,
      contains('deeper history and saved evidence'),
    );
  });

  test('paywall benefits include continuity bullets', () {
    expect(
      ConsumerUiCopy.paywallBullets,
      contains('See more of what keeps returning'),
    );
    expect(
      ConsumerUiCopy.paywallBullets,
      contains('Keep deeper history and saved evidence'),
    );
    expect(
      ConsumerUiCopy.paywallBullets,
      contains('Review what changed over time'),
    );
    expect(ConsumerUiCopy.paywallBullets, contains('Archive timeline'));
    expect(ArchivePaywallCopy.keyValueBullets, ConsumerUiCopy.paywallBullets);
  });

  test('paywall CTAs match launch copy', () {
    expect(ConsumerUiCopy.paywallPrimaryCta, 'Continue with ArchiveMe Pro');
    expect(ConsumerUiCopy.paywallSecondaryCta, 'Not now');
    expect(ValueMomentPaywallLogic.ctaLabel, ConsumerUiCopy.paywallPrimaryCta);
    expect(
      ValueMomentPaywallLogic.secondaryLabel,
      ConsumerUiCopy.paywallSecondaryCta,
    );
  });
}
