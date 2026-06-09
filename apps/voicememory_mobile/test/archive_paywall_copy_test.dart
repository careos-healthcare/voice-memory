import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_paywall_copy.dart';
import 'package:voicememory_mobile/billing/paywall_trigger_model.dart';
import 'package:voicememory_mobile/billing/pro_value_preview_engine.dart';
import 'package:voicememory_mobile/billing/pro_value_preview_model.dart';
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
      'ArchiveMe works best when it can track the same loop across more moments.',
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
    expect(ConsumerUiCopy.paywallBullets, contains('Monthly review'));
    expect(ConsumerUiCopy.paywallBullets.length, 5);
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
    expect(
      buildProValuePreview(
        PaywallTriggerContext(
          trigger: PaywallTrigger.fullHistory,
          sourceRoute: '/test',
          previewTitle: '',
          previewBody: '',
          ctaLabel: '',
        ),
      ).ctaLabel,
      ConsumerUiCopy.unlockFullMemoryCta,
    );
  });

  test('pro value preview uses consumer unlock CTA', () {
    final preview = buildProValuePreview(
      PaywallTriggerContext(
        trigger: PaywallTrigger.patternMapFull,
        sourceRoute: '/pattern-map',
        previewTitle: '',
        previewBody: '',
        ctaLabel: '',
      ),
    );
    expect(preview.type, ProValuePreviewType.patternMap);
    expect(preview.ctaLabel, ConsumerUiCopy.unlockFullMemoryCta);
  });
}
