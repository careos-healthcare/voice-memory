import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/capacity_loop/before_yes_copy.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_cost_copy.dart';
import 'package:voicememory_mobile/features/capacity_loop/low_effort_yes_capture_copy.dart';
import 'package:voicememory_mobile/product/acquisition_start_copy.dart';
import 'package:voicememory_mobile/product/archive_positioning_copy.dart';
import 'package:voicememory_mobile/product/loop_acquisition_copy.dart';
import 'package:voicememory_mobile/product/loop_mode_copy.dart';
import 'package:voicememory_mobile/security/privacy_copy_policy.dart';

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
    test('umbrella headline says private mind map of what keeps repeating', () {
      expect(
        ArchivePositioningCopy.umbrellaHeadline,
        'A private mind map of what keeps repeating.',
      );
    });

    test('product body says patterns, changes, next things to watch', () {
      expect(
        ArchivePositioningCopy.umbrellaBody.toLowerCase(),
        allOf(
          contains('patterns'),
          contains('changes'),
          contains('next things to watch'),
        ),
      );
    });

    test('capacity path remains available', () {
      expect(
        ArchivePositioningCopy.capacityPathHeadline,
        'Saying yes when you have no capacity',
      );
      expect(
        ArchivePositioningCopy.capacityWedgeHeadline,
        'Catch the yes before it costs you.',
      );
    });

    test('copy supports before, after, and later yes capture', () {
      expect(ArchivePositioningCopy.yesCaptureModeLabels, [
        'Before yes',
        'After yes',
        'Later cost',
      ]);
      expect(ArchivePositioningCopy.yesCaptureModeBodies, [
        'I am about to say yes',
        'I just said yes',
        'That yes cost me something',
      ]);
      expect(
        ArchivePositioningCopy.yesCaptureModesIntro.toLowerCase(),
        allOf(contains('before'), contains('after'), contains('later')),
      );
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
        AcquisitionStartCopy.startGenericCta,
        ArchivePositioningCopy.genericCta,
      );
    });

    test('generic surfaces do not make the app only about yes', () {
      final generic = [
        AcquisitionStartCopy.genericTitle,
        AcquisitionStartCopy.genericBody,
      ].join('\n').toLowerCase();
      expect(generic, isNot(contains('catch the yes')));
      expect(generic, contains('mind map'));
    });

    test('capacity surfaces still include Catch the yes before it costs you', () {
      expect(
        AcquisitionStartCopy.capacityTitle,
        ArchivePositioningCopy.capacityWedgeHeadline,
      );
      expect(
        LoopAcquisitionCopy.capacityYes.headline,
        ArchivePositioningCopy.capacityWedgeHeadline,
      );
      expect(
        LoopModeCopy.capacityHandoffTitle,
        ArchivePositioningCopy.capacityWedgeHeadline,
      );
    });

    test('capacity start includes first-path context line', () {
      expect(
        AcquisitionStartCopy.capacityPathContext,
        ArchivePositioningCopy.capacityPathContext,
      );
      expect(
        AcquisitionStartCopy.capacityPathContext.toLowerCase(),
        contains('first path'),
      );
    });
  });

  group('Capture mode wiring', () {
    test('before yes flow uses positioning labels', () {
      expect(BeforeYesCopy.title, ArchivePositioningCopy.beforeYesCaptureLabel);
      expect(
        BeforeYesCopy.body,
        contains(ArchivePositioningCopy.beforeYesCaptureBody),
      );
    });

    test('quick yes capture uses positioning label', () {
      expect(
        LowEffortYesCaptureCopy.title,
        ArchivePositioningCopy.quickYesMoment,
      );
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
        final snippets = _positiveCopySnippets(path);
        _expectNoBannedCopy(snippets);
        if (path.endsWith('.md')) {
          for (final snippet in snippets) {
            expect(snippet.toLowerCase(), isNot(contains('digital mind map')));
          }
        }
      });
    }
  });

  group('Legacy consumer positioning surfaces', () {
    test('competitive positioning constants remain in consumer_ui_copy', () {
      final source =
          File('lib/product/consumer_ui_copy.dart').readAsStringSync();
      expect(source, contains('archivePositioningHeadline'));
    });
  });
}

List<String> _positiveCopySnippets(String path) {
  final source = File(path).readAsStringSync();
  return [
    ArchivePositioningCopy.umbrellaHeadline,
    ArchivePositioningCopy.umbrellaBody,
    ArchivePositioningCopy.capacityWedgeHeadline,
    ArchivePositioningCopy.capacityPathContext,
    ArchivePositioningCopy.yesCaptureModesIntro,
    ArchivePositioningCopy.capacityPathBody,
    ArchivePositioningCopy.beforeYesCaptureLabel,
    ArchivePositioningCopy.afterYesCaptureLabel,
    ArchivePositioningCopy.laterCostCaptureLabel,
  ].where((line) => source.contains(line)).toList();
}
