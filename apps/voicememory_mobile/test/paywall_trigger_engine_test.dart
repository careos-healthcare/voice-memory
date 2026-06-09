import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_pro_feature_map.dart';
import 'package:voicememory_mobile/billing/paywall_trigger_engine.dart';
import 'package:voicememory_mobile/billing/paywall_trigger_model.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';

void main() {
  test('Pro user gets no trigger', () {
    expect(
      buildPaywallTrigger(
        feature: ArchiveFeature.patternMap,
        isPro: true,
        firstLoopClosed: true,
        momentCount: 12,
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
      ),
      isNull,
    );
    final trigger = buildPaywallTrigger(
      feature: ArchiveFeature.keyMomentsSearch,
      isPro: false,
      firstLoopClosed: true,
      momentCount: 8,
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
    );
    expect(trigger?.trigger, PaywallTrigger.fullHistory);
  });

  test('pattern map full triggers when loop closed', () {
    final trigger = buildPaywallTrigger(
      feature: ArchiveFeature.patternMap,
      isPro: false,
      firstLoopClosed: true,
    );
    expect(trigger?.trigger, PaywallTrigger.patternMapFull);
    expect(trigger?.previewTitle, 'Unlock your full pattern map');
  });

  test('archive timeline full triggers when loop closed', () {
    final trigger = buildPaywallTrigger(
      feature: ArchiveFeature.archiveTimeline,
      isPro: false,
      firstLoopClosed: true,
    );
    expect(trigger?.trigger, PaywallTrigger.archiveTimelineFull);
  });

  test('monthly review and private export are Pro after loop closed', () {
    expect(
      buildPaywallTrigger(
        feature: ArchiveFeature.monthlyReview,
        isPro: false,
        firstLoopClosed: true,
      )?.trigger,
      PaywallTrigger.monthlyReview,
    );
    expect(
      buildPaywallTrigger(
        feature: ArchiveFeature.privateRecapExport,
        isPro: false,
        firstLoopClosed: true,
      )?.trigger,
      PaywallTrigger.privateExport,
    );
  });
}
