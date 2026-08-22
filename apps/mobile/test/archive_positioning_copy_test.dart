import 'dart:io';

import 'package:archiveme_mobile/features/capacity_loop/before_yes_copy.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_cost_copy.dart';
import 'package:archiveme_mobile/features/capacity_loop/low_effort_yes_capture_copy.dart';
import 'package:archiveme_mobile/features/demo/sample_archive_copy.dart';
import 'package:archiveme_mobile/product/acquisition_start_copy.dart';
import 'package:archiveme_mobile/product/archive_positioning_copy.dart';
import 'package:archiveme_mobile/security/privacy_copy_policy.dart';
import 'package:flutter_test/flutter_test.dart';

const _bannedPhrases = [
  'therapy',
  'diagnosis',
  'medical',
  'treatment',
  'mental health score',
  'wellbeing score',
  'clinical score',
  'life score',
  'archiveme knows',
  '100% secure',
  'military grade',
  'unhackable',
  'anonymous',
  'everything stays on device',
  'fully encrypted archive',
  'fake stats',
  'testimonial',
  'digital mind map',
];

const _privateSnippet = 'felt pressure at work before saying yes';

void _expectNoBannedCopy(Iterable<String> visible) {
  for (final text in visible) {
    final lower = text.toLowerCase();
    for (final phrase in _bannedPhrases) {
      if (phrase == 'therapy' && lower.contains('not therapy')) continue;
      expect(
        lower,
        isNot(contains(phrase)),
        reason: 'must not contain "$phrase" in "$text"',
      );
    }
    expect(lower, isNot(contains(_privateSnippet)));
    for (final reason in PrivacyCopyPolicy.violationsInLiteral(text)) {
      fail('privacy violation in "$text": $reason');
    }
  }
}

void main() {
  group('ArchivePositioningCopy constants', () {
    test('umbrella headline matches landing alignment v1', () {
      expect(
        ArchivePositioningCopy.umbrellaHeadline,
        'When it repeats, save it',
      );
      expect(
        ArchivePositioningCopy.umbrellaShort,
        'No daily journal. No streak. No dashboard to maintain.',
      );
    });

    test('product body describes public promise', () {
      expect(
        ArchivePositioningCopy.umbrellaBody.toLowerCase(),
        allOf(
          contains('save one real moment'),
          contains('compares it later'),
          contains('not a diary'),
        ),
      );
    });

    test('first guided path says saying yes when you have no capacity', () {
      expect(
        ArchivePositioningCopy.firstPathIntro.toLowerCase(),
        contains('saying yes when you have no capacity'),
      );
    });

    test('capacity wedge still says Catch the yes before it costs you', () {
      expect(
        ArchivePositioningCopy.wedgeHeadline,
        'Catch the yes before it costs you.',
      );
    });

    test('before, after, and later copy exists', () {
      expect(ArchivePositioningCopy.yesCaptureTimingLabels, [
        'Before',
        'After',
        'Later',
      ]);
      expect(ArchivePositioningCopy.yesCaptureTimingBodies, [
        'I am about to say yes.',
        'I just said yes.',
        'That yes cost me something.',
      ]);
    });
  });

  group('Public vs capacity surfaces', () {
    test('generic surfaces use umbrella positioning', () {
      expect(
        AcquisitionStartCopy.genericTitle,
        ArchivePositioningCopy.umbrellaHeadline,
      );
      expect(
        AcquisitionStartCopy.genericBody,
        ArchivePositioningCopy.umbrellaBody,
      );
      expect(
        AcquisitionStartCopy.genericFirstPathLine,
        ArchivePositioningCopy.firstPathIntro,
      );
    });

    test('public surfaces do not imply the app is only about saying yes', () {
      final generic = [
        AcquisitionStartCopy.genericTitle,
        AcquisitionStartCopy.genericBody,
      ].join('\n').toLowerCase();
      expect(generic, isNot(contains('catch the yes')));
      expect(generic, contains('when it repeats'));
    });

    test('capacity start uses simpler fallback headline', () {
      expect(
        AcquisitionStartCopy.capacityTitle,
        ArchivePositioningCopy.firstUseTitle,
      );
      expect(
        AcquisitionStartCopy.capacityTitle,
        contains('When it repeats, save it'),
      );
      expect(
        ArchivePositioningCopy.wedgeHeadline,
        'Catch the yes before it costs you.',
      );
    });

    test(
      'capacity surfaces do not require opening app before every decision',
      () {
        expect(
          AcquisitionStartCopy.capacityTimingFlex.toLowerCase(),
          isNot(contains('before every decision')),
        );
        expect(
          AcquisitionStartCopy.capacityTimingFlex.toLowerCase(),
          allOf(contains('before'), contains('after'), contains('later')),
        );
      },
    );

    test('capacity start includes timing flex line', () {
      expect(
        AcquisitionStartCopy.capacityTimingFlex,
        ArchivePositioningCopy.firstUseTimingMicro,
      );
    });
  });

  group('Capture mode wiring', () {
    test('before yes flow uses positioning labels', () {
      expect(BeforeYesCopy.title, ArchivePositioningCopy.beforeLabel);
      expect(BeforeYesCopy.body, contains(ArchivePositioningCopy.beforeBody));
    });

    test('quick yes capture includes timing flexibility copy', () {
      expect(
        LowEffortYesCaptureCopy.corePromise,
        ArchivePositioningCopy.quickCaptureTimingFlex,
      );
      expect(
        LowEffortYesCaptureCopy.body,
        contains(ArchivePositioningCopy.quickCaptureTimingFlex),
      );
      expect(LowEffortYesCaptureCopy.timingIds(), hasLength(3));
    });

    test('later cost flow remains available', () {
      expect(
        CapacityCostCopy.cardTitle.toLowerCase(),
        contains('cost you later'),
      );
    });
  });

  group('Positioning copy guardrails', () {
    test('all positioning constants pass banned phrase scan', () {
      _expectNoBannedCopy(ArchivePositioningCopy.allVisibleStrings());
    });

    for (final path in ArchivePositioningCopy.publicSurfacePaths) {
      test('$path avoids banned positioning language', () {
        expect(File(path).existsSync(), isTrue, reason: 'missing $path');
        final snippets = _visibleStringsForSurface(path);
        expect(
          snippets,
          isNotEmpty,
          reason: 'expected positioning snippets in $path',
        );
        _expectNoBannedCopy(snippets);
      });
    }
  });

  group('Legacy consumer positioning surfaces', () {
    test('competitive positioning constants remain in consumer_ui_copy', () {
      final source = File(
        'lib/product/consumer_ui_copy.dart',
      ).readAsStringSync();
      expect(source, contains('archivePositioningHeadline'));
    });
  });
}

List<String> _visibleStringsForSurface(String path) {
  switch (path) {
    case 'lib/product/archive_positioning_copy.dart':
      return ArchivePositioningCopy.allVisibleStrings();
    case 'lib/product/acquisition_start_copy.dart':
      return [
        ...AcquisitionStartCopy.capacityVisibleStrings(),
        AcquisitionStartCopy.genericTitle,
        AcquisitionStartCopy.genericBody,
        AcquisitionStartCopy.genericFirstPathLine,
      ];
    case 'lib/screens/about_screen.dart':
      return [
        ArchivePositioningCopy.umbrellaHeadline,
        ArchivePositioningCopy.umbrellaBody,
        ArchivePositioningCopy.firstPathIntro,
      ];
    case '../../packages/archiveme_research/lib/screens/loop_start_screen.dart':
      return AcquisitionStartCopy.capacityVisibleStrings();
    case 'lib/features/demo/sample_archive_copy.dart':
      return [
        SampleArchiveCopy.emptyStateSubtitle,
        SampleArchiveCopy.emptyStateTitle,
      ];
    default:
      return _positiveDocSnippets(path);
  }
}

List<String> _positiveDocSnippets(String path) {
  final source = File(path).readAsStringSync();
  final positiveSection = source.split('## Do not include').first;
  return [
    ArchivePositioningCopy.umbrellaHeadline,
    ArchivePositioningCopy.umbrellaShort,
    ArchivePositioningCopy.umbrellaBody,
    ArchivePositioningCopy.firstPathIntro,
    ArchivePositioningCopy.wedgeHeadline,
    ArchivePositioningCopy.capacityPathContext,
    ArchivePositioningCopy.capacityTimingFlex,
    ArchivePositioningCopy.yesCaptureModesIntro,
    ArchivePositioningCopy.beforeBody,
    ArchivePositioningCopy.afterBody,
    ArchivePositioningCopy.laterBody,
    ArchivePositioningCopy.mapLine,
  ].where(positiveSection.contains).toList();
}