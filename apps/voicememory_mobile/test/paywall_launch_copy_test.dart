import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_paywall_copy.dart';
import 'package:voicememory_mobile/billing/value_moment_paywall.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';

void main() {
  test('paywall headline sells pattern memory', () {
    expect(
      ConsumerUiCopy.paywallHeadline,
      'Keep your pattern memory growing',
    );
    expect(
      ArchivePaywallVariantConfig.headline(ArchivePaywallVariant.b),
      ConsumerUiCopy.paywallHeadline,
    );
    expect(ValueMomentPaywallLogic.copyHeadline, ConsumerUiCopy.paywallHeadline);
  });

  test('paywall subhead mentions weeks and months', () {
    expect(
      ConsumerUiCopy.paywallSubhead,
      contains('weeks and months'),
    );
  });

  test('paywall benefits include launch bullets', () {
    expect(ConsumerUiCopy.paywallBullets, contains('Full pattern memory'));
    expect(ConsumerUiCopy.paywallBullets, contains('Key moments by day'));
    expect(ConsumerUiCopy.paywallBullets, contains('Pattern map over time'));
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
