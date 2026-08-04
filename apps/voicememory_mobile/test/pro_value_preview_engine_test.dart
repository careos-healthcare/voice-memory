import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/paywall_trigger_model.dart';
import 'package:voicememory_mobile/billing/pro_value_preview_engine.dart';
import 'package:voicememory_mobile/billing/pro_value_preview_model.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';

PaywallTriggerContext _context(PaywallTrigger trigger) => PaywallTriggerContext(
  trigger: trigger,
  sourceRoute: '/test',
  previewTitle: '',
  previewBody: '',
  ctaLabel: '',
);

void main() {
  test('memoryLimit preview copy', () {
    final preview = buildProValuePreview(_context(PaywallTrigger.fullHistory));
    expect(preview.type, ProValuePreviewType.memoryLimit);
    expect(preview.title, 'Your pattern memory is growing');
    expect(
      preview.body,
      'Free shows the first useful proof. Pro keeps the longer trail.',
    );
    expect(preview.previewBullets, contains('Keep older moments'));
    expect(preview.ctaLabel, ConsumerUiCopy.unlockFullMemoryCta);
  });

  test('keyMomentSearch preview uses memory-limit copy', () {
    final preview = buildProValuePreview(
      _context(PaywallTrigger.keyMomentsLimit),
    );
    expect(preview.type, ProValuePreviewType.keyMomentSearch);
    expect(preview.title, 'Your pattern memory is growing');
    expect(preview.previewBullets, contains('Search all your moments'));
  });

  test('patternMap preview copy', () {
    final preview = buildProValuePreview(
      _context(PaywallTrigger.patternMapFull),
    );
    expect(preview.type, ProValuePreviewType.patternMap);
    expect(preview.title, 'See more of your pattern map');
    expect(preview.body, contains('what repeats'));
    expect(preview.previewBullets, contains('Usually starts before'));
    expect(preview.previewBullets, contains('Next useful check'));
  });

  test('archiveTimeline preview copy', () {
    final preview = buildProValuePreview(
      _context(PaywallTrigger.archiveTimelineFull),
    );
    expect(preview.type, ProValuePreviewType.archiveTimeline);
    expect(preview.title, 'See your archive timeline');
    expect(preview.previewBullets, contains('First seen'));
    expect(preview.previewBullets, contains('Changed recently'));
  });

  test('archiveMemory preview copy', () {
    final preview = buildProValuePreview(
      _context(PaywallTrigger.archiveMemoryFull),
    );
    expect(preview.type, ProValuePreviewType.archiveMemory);
    expect(preview.title, 'See more of what keeps returning');
    expect(preview.previewBullets, contains('What repeats'));
    expect(preview.previewBullets, contains('What to check next'));
  });

  test('monthlyReview preview copy', () {
    final preview = buildProValuePreview(
      _context(PaywallTrigger.monthlyReview),
    );
    expect(preview.type, ProValuePreviewType.monthlyReview);
    expect(preview.title, 'Review your month');
    expect(preview.previewBullets, contains('Repeated patterns'));
    expect(preview.previewBullets, contains('Next check'));
  });

  test('privateExport preview copy', () {
    final preview = buildProValuePreview(
      _context(PaywallTrigger.privateExport),
    );
    expect(preview.type, ProValuePreviewType.privateExport);
    expect(preview.title, 'Export your private recap');
    expect(
      preview.body,
      'Free shows the first useful proof. Pro keeps the longer trail.',
    );
    expect(preview.previewBullets, contains('Pattern summary'));
    expect(preview.previewBullets, contains('Key moments'));
  });
}
