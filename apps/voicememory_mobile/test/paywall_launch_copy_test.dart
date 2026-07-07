import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_paywall_copy.dart';
import 'package:voicememory_mobile/billing/value_moment_paywall.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';

void main() {
  test('paywall headline sells longer story continuity', () {
    expect(
      ConsumerUiCopy.paywallHeadline,
      'Keep the longer story.',
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

  test('paywall subhead compares moments over time', () {
    expect(
      ConsumerUiCopy.paywallSubhead,
      'ArchiveMe is most useful when it can compare moments over time.',
    );
  });

  test('paywall benefits include longer story bullets', () {
    expect(
      ConsumerUiCopy.paywallBullets,
      contains('Longer archive history'),
    );
    expect(
      ConsumerUiCopy.paywallBullets,
      contains('Private monthly reports'),
    );
    expect(
      ConsumerUiCopy.paywallBullets.join(' ').toLowerCase(),
      contains('returned, changed, softened, helped, or went quiet'),
    );
    expect(
      ConsumerUiCopy.paywallBullets,
      contains('Built around preserving your archive over time'),
    );
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
