import '../product/consumer_ui_copy.dart';
import 'paywall_trigger_model.dart';
import 'pro_value_preview_model.dart';

/// Builds trigger-specific Pro value preview copy.
ProValuePreview buildProValuePreview(PaywallTriggerContext context) {
  final type = _typeForTrigger(context.trigger);
  final copy = _copyForType(type);
  return ProValuePreview(
    type: type,
    title: copy.title,
    body: copy.body,
    previewBullets: copy.bullets,
    ctaLabel: ConsumerUiCopy.unlockFullMemoryCta,
    trigger: context.trigger.name,
  );
}

ProValuePreviewType _typeForTrigger(PaywallTrigger trigger) => switch (trigger) {
      PaywallTrigger.keyMomentsLimit => ProValuePreviewType.keyMomentSearch,
      PaywallTrigger.fullHistory => ProValuePreviewType.memoryLimit,
      PaywallTrigger.patternMapFull => ProValuePreviewType.patternMap,
      PaywallTrigger.archiveTimelineFull => ProValuePreviewType.archiveTimeline,
      PaywallTrigger.archiveMemoryFull => ProValuePreviewType.archiveMemory,
      PaywallTrigger.monthlyReview => ProValuePreviewType.monthlyReview,
      PaywallTrigger.privateExport => ProValuePreviewType.privateExport,
    };

({String title, String body, List<String> bullets}) _copyForType(
  ProValuePreviewType type,
) =>
    switch (type) {
      ProValuePreviewType.memoryLimit ||
      ProValuePreviewType.keyMomentSearch =>
        (
          title: 'Your pattern memory is growing',
          body:
              'Free keeps your first 7 key moments. Pro keeps the full memory across weeks and months.',
          bullets: const [
            'Keep older moments',
            'Search all your moments',
            'See patterns across months',
          ],
        ),
      ProValuePreviewType.patternMap => (
          title: 'Unlock your full pattern map',
          body: 'See what repeats, what helps, and what to check next.',
          bullets: const [
            'Usually starts before',
            'Feels lighter when',
            'Next useful check',
          ],
        ),
      ProValuePreviewType.archiveTimeline => (
          title: 'Unlock your archive timeline',
          body: 'See how this pattern changed over time.',
          bullets: const [
            'First seen',
            'Showed up again',
            'Changed recently',
          ],
        ),
      ProValuePreviewType.archiveMemory => (
          title: 'Unlock what ArchiveMe remembers',
          body: 'See the fuller picture as your archive grows.',
          bullets: const [
            'What repeats',
            'What helps',
            'What to check next',
          ],
        ),
      ProValuePreviewType.monthlyReview => (
          title: 'Review your month',
          body: 'See what kept showing up across this month.',
          bullets: const [
            'Repeated patterns',
            'Key moments',
            'Next check',
          ],
        ),
      ProValuePreviewType.privateExport => (
          title: 'Export your private recap',
          body: 'Keep a copy of your pattern memory.',
          bullets: const [
            'Pattern summary',
            'Key moments',
            'Next check',
          ],
        ),
    };
