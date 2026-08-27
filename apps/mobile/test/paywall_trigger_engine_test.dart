import 'package:archiveme_mobile/billing/archive_pro_feature_map.dart';
import 'package:archiveme_mobile/billing/paywall_trigger_engine.dart';
import 'package:archiveme_mobile/billing/paywall_trigger_model.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Pro user gets no trigger', () {
    expect(
      buildPaywallTrigger(
        feature: ArchiveFeature.patternMap,
        isPro: true,
        firstLoopClosed: true,
        momentCount: 12,
        magicMomentsCount: 4,
      ),
      isNull,
    );
  });

  test('no paywall before first loop closed', () {
    expect(
      buildPaywallTrigger(
        feature: ArchiveFeature.patternMap,
        isPro: false,
        firstLoopClosed: false,
        momentCount: 12,
        magicMomentsCount: 4,
      ),
      isNull,
    );
  });

  test('no paywall before three magic moments', () {
    expect(
      buildPaywallTrigger(
        feature: ArchiveFeature.patternMap,
        isPro: false,
        firstLoopClosed: true,
        magicMomentsCount: 2,
      ),
      isNull,
    );
  });

  test('key moments triggers after 7 moments', () {
    expect(
      buildPaywallTrigger(
        feature: ArchiveFeature.keyMomentsSearch,
        isPro: false,
        firstLoopClosed: true,
        momentCount: 7,
        magicMomentsCount: 3,
      ),
      isNull,
    );
    final trigger = buildPaywallTrigger(
      feature: ArchiveFeature.keyMomentsSearch,
      isPro: false,
      firstLoopClosed: true,
      momentCount: 8,
      magicMomentsCount: 3,
    );
    expect(trigger?.trigger, PaywallTrigger.keyMomentsLimit);
    expect(trigger?.previewTitle, 'Your pattern memory is growing');
    expect(trigger?.previewBody, contains('first 7 key moments'));
    expect(trigger?.ctaLabel, ConsumerUiCopy.unlockFullMemoryCta);
  });

  test('full history triggers after 7 moments', () {
    final trigger = buildPaywallTrigger(
      feature: ArchiveFeature.fullHistory,
      isPro: false,
      firstLoopClosed: true,
      momentCount: 10,
      magicMomentsCount: 3,
    );
    expect(trigger?.trigger, PaywallTrigger.fullHistory);
  });

  test('pattern map full triggers when loop closed', () {
    final trigger = buildPaywallTrigger(
      feature: ArchiveFeature.patternMap,
      isPro: false,
      firstLoopClosed: true,
      magicMomentsCount: 3,
    );
    expect(trigger?.trigger, PaywallTrigger.patternMapFull);
    expect(trigger?.previewTitle, 'See more of your pattern map');
  });

  test('archive timeline is not Pro-gated — never triggers a paywall', () {
    // Timeline is a core capability, not a Pro upsell (only history depth is).
    final trigger = buildPaywallTrigger(
      feature: ArchiveFeature.archiveTimeline,
      isPro: false,
      firstLoopClosed: true,
      magicMomentsCount: 3,
    );
    expect(trigger, isNull);
  });

  test('monthly review is Pro; private export and weekly review are free', () {
    expect(
      buildPaywallTrigger(
        feature: ArchiveFeature.monthlyReview,
        isPro: false,
        firstLoopClosed: true,
        magicMomentsCount: 3,
      )?.trigger,
      PaywallTrigger.monthlyReview,
    );
    // Private recap export is free forever — it must never open a paywall.
    expect(
      buildPaywallTrigger(
        feature: ArchiveFeature.privateRecapExport,
        isPro: false,
        firstLoopClosed: true,
        magicMomentsCount: 3,
      ),
      isNull,
    );
    // Weekly review is ungated too (split off from the monthly-review trigger).
    expect(
      buildPaywallTrigger(
        feature: ArchiveFeature.tier2WeeklyReview,
        isPro: false,
        firstLoopClosed: true,
        magicMomentsCount: 3,
      ),
      isNull,
    );
  });
}