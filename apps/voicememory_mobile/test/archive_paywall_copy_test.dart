import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_paywall_copy.dart';
import 'package:voicememory_mobile/billing/paywall_trigger_model.dart';
import 'package:voicememory_mobile/billing/pro_value_preview_engine.dart';
import 'package:voicememory_mobile/billing/pro_value_preview_model.dart';
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
      contains('Export/private reports when available'),
    );
    expect(ConsumerUiCopy.paywallBullets.length, 5);
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

  test('pro value preview uses consumer continuity CTA', () {
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
