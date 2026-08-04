import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_paywall_copy.dart';
import 'package:voicememory_mobile/billing/paywall_trigger_model.dart';
import 'package:voicememory_mobile/billing/pro_value_preview_engine.dart';
import 'package:voicememory_mobile/billing/pro_value_preview_model.dart';
import 'package:voicememory_mobile/billing/value_moment_paywall.dart';
import 'package:voicememory_mobile/features/paywall_alignment/paywall_alignment_copy.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';

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
    expect(ConsumerUiCopy.paywallBullets, PaywallAlignmentCopy.benefitBullets);
    expect(ConsumerUiCopy.paywallBullets, contains('Ongoing comparisons'));
    expect(ConsumerUiCopy.paywallBullets, contains('Deeper archive analysis'));
    expect(ConsumerUiCopy.paywallBullets.length, 3);
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
