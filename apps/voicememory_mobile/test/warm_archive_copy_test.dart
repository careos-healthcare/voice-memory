import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/design/warm_archive_copy.dart';
import 'package:voicememory_mobile/features/living_archive/living_archive_copy.dart';
import 'package:voicememory_mobile/features/living_archive/living_archive_models.dart';

void main() {
  test('confidence shift uses reflective phrasing not percent deltas', () {
    expect(
      WarmArchiveCopy.confidenceShiftPhrase(prior: 73, current: 55),
      'The archive is less certain about this than before.',
    );
    expect(
      WarmArchiveCopy.confidenceShiftPhrase(prior: 55, current: 73),
      'The archive feels more certain about this than before.',
    );
    expect(
      LivingArchiveCopy.confidenceChangeHeadline(61, 73),
      WarmArchiveCopy.confidenceShiftPhrase(prior: 61, current: 73),
    );
  });

  test('theme frequency uses returning language', () {
    expect(
      WarmArchiveCopy.themeReturningMoreOften('work'),
      "You've been returning to work more often.",
    );
    expect(
      WarmArchiveCopy.themeReturningLessOften('approval'),
      "You've been returning to approval less often.",
    );
  });

  test('what changed line prefers displayText', () {
    const line = WhatChangedTodayLine(
      label: 'Confidence',
      before: '70%',
      after: '52%',
      displayText: 'The archive is less certain about this than before.',
    );
    expect(
      WarmArchiveCopy.formatWhatChangedLine(line),
      'The archive is less certain about this than before.',
    );
  });

  test('archive changed mind section title', () {
    expect(
      LivingArchiveCopy.sectionLabelFor(
        priority: MostImportantInsightPriority.archiveWasWrong,
        isArchiveWasWrong: true,
      ),
      WarmArchiveCopy.archiveChangedMindSectionTitle,
    );
  });
}
