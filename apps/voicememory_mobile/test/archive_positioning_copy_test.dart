import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';

const _positioningConstants = [
  'archivePositioningHeadline',
  'archivePositioningSubhead',
  'archiveMemoryPromise',
  'archiveLoopPromise',
  'archiveNotChatLine',
  'archivePatternOverTimeLine',
  'archiveMomentsMatterLine',
];

const _positioningLines = [
  ConsumerUiCopy.archivePositioningHeadline,
  ConsumerUiCopy.archivePositioningSubhead,
  ConsumerUiCopy.archiveMemoryPromise,
  ConsumerUiCopy.archiveLoopPromise,
  ConsumerUiCopy.archiveNotChatLine,
  ConsumerUiCopy.archivePatternOverTimeLine,
  ConsumerUiCopy.archiveMomentsMatterLine,
  ConsumerUiCopy.archiveClearerEachCheckLine,
];

/// Surfaces where approved ArchiveMe positioning should appear.
const _positioningSurfaces = <String, String>{
  'lib/product/consumer_ui_copy.dart': 'archivePositioningHeadline',
  'lib/onboarding/onboarding_pages.dart': 'onboardingPositioningHeadline',
  'lib/screens/onboarding_screen.dart': 'onboardingFinalCta',
  'lib/widgets/patterns/patterns_empty_view.dart': 'patternsEarlyStateBody',
  'lib/widgets/patterns/first_loop_state_card.dart': 'patternsEarlyStateBody',
  'lib/widgets/patterns/archive_memory_summary_card.dart':
      'positioningBasedOnMoments',
  'lib/screens/key_moments_screen.dart': 'archiveMomentsMatterLine',
  'lib/widgets/patterns/pattern_map_card.dart': 'positioningClearerEachCheck',
};

/// Major insight cards that should expose at least one concrete next action.
const _insightCardActions = <String, List<String>>{
  'lib/widgets/patterns/archive_memory_summary_card.dart': [
    'Use this check',
    'Open pattern map',
    'Find related moments',
  ],
  'lib/widgets/patterns/pattern_map_card.dart': ['Use this check'],
  'lib/screens/key_moment_detail_screen.dart': [
    'Use this check',
    'recordNextMomentCta',
  ],
  'lib/widgets/record/check_in_completed_card.dart': [
    'makeResultMoreUsefulCta',
    'checkInGoDeeperCta',
  ],
  'lib/widgets/record/result_next_check_card.dart': [
    'resultNextCheckUseTomorrowCta',
  ],
  'lib/widgets/patterns/weekly_pattern_recap_card.dart': [
    'recordNextMomentCta',
  ],
  'lib/widgets/patterns/monthly_pattern_review_card.dart': [
    'Use next month',
  ],
};

void main() {
  test('competitive positioning constants are defined', () {
    final source =
        File('lib/product/consumer_ui_copy.dart').readAsStringSync();
    for (final name in _positioningConstants) {
      expect(source, contains(name), reason: 'Missing $name');
    }
    for (final line in _positioningLines) {
      expect(line.trim(), isNotEmpty);
    }
  });

  test('onboarding uses archive memory framing', () {
    final pages = File('lib/onboarding/onboarding_pages.dart').readAsStringSync();
    expect(pages, contains('onboardingPositioningHeadline'));
    expect(pages, contains('onboardingPositioningBody'));
    expect(pages, isNot(contains('Rosebud')));
    expect(pages, isNot(contains(RegExp(r'\bintelligence\b', caseSensitive: false))));
  });

  test('patterns early state uses record-moments framing', () {
    expect(
      ConsumerUiCopy.patternsEarlyStateBody,
      contains('Record short moments'),
    );
    final emptyView =
        File('lib/widgets/patterns/patterns_empty_view.dart').readAsStringSync();
    expect(
      emptyView,
      anyOf(contains('patternsEarlyStateBody'), contains('patternsEmptyPageTitle')),
    );
  });

  test('paywall copy avoids therapy and companion language', () {
    for (final path in [
      'lib/billing/archive_paywall_copy.dart',
      'lib/billing/value_moment_paywall.dart',
      'lib/product/consumer_ui_copy.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source.toLowerCase(), isNot(contains('rosebud')));
      expect(source.toLowerCase(), isNot(contains('therapy')));
      expect(source.toLowerCase(), isNot(contains('companion')));
      expect(source.toLowerCase(), isNot(contains('chatgpt')));
    }
  });

  for (final entry in _positioningSurfaces.entries) {
    test('${entry.key} references ${entry.value}', () {
      final source = File(entry.key).readAsStringSync();
      expect(source, contains(entry.value));
    });
  }

  for (final entry in _insightCardActions.entries) {
    test('${entry.key} exposes a concrete next action', () {
      final source = File(entry.key).readAsStringSync();
      final hasAction = entry.value.any((token) => source.contains(token));
      expect(hasAction, isTrue, reason: 'Expected one of: ${entry.value}');
    });
  }
}
