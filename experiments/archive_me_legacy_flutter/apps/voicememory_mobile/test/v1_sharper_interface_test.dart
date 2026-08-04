import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/demo/sample_archive_copy.dart';
import 'package:voicememory_mobile/features/onboarding/first_proof_journey_copy.dart';
import 'package:voicememory_mobile/features/release_candidate/v1_revenue_focus_policy.dart';
import 'package:voicememory_mobile/features/v1_interface/archive_secondary_nav_gates.dart';
import 'package:voicememory_mobile/features/v1_interface/future_wedge_routes_copy.dart';
import 'package:voicememory_mobile/features/v1_interface/progressive_evidence_state_copy.dart';
import 'package:voicememory_mobile/features/v1_interface/v1_core_product_sentence.dart';
import 'package:voicememory_mobile/features/v1_interface/v1_expansion_gate_copy.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/product/archive_me_v1_product_contract.dart';
import 'package:voicememory_mobile/record/record_screen_framing_copy.dart';

void main() {
  group('Auditable personal change contract', () {
    test('promises exact evidence, early value, and user correction', () {
      expect(
        ArchiveMeV1ProductContract.promise,
        'See what changed. Check the exact words and dates behind it. '
        'Correct anything ArchiveMe gets wrong.',
      );
      expect(
        ArchiveMeV1ProductContract.defensibleProductLine,
        contains('Auditable personal change'),
      );
      expect(
        ArchiveMeV1ProductContract.defensibleProductLine,
        contains('correction controls'),
      );
      expect(
        ArchiveMeV1ProductContract.earlyValuePromise,
        'One moment gives ArchiveMe an observation. Returning gives it '
        'something real to compare.',
      );
      expect(
        ArchiveMeV1ProductContract.coreCapabilities,
        contains(ArchiveMeV1Capability.interpretationCorrection),
      );
    });
  });

  group('V1 core product sentence', () {
    test('matches required V1 sentence', () {
      expect(V1CoreProductSentence.line, contains('Record one real moment'));
      expect(
        V1CoreProductSentence.line,
        contains('Return when it happens again'),
      );
      expect(
        V1CoreProductSentence.line,
        contains('Pro keeps the longer trail'),
      );
      expect(V1RevenueFocusPolicy.firstUserJourney, V1CoreProductSentence.line);
    });
  });

  group('Record first-use copy', () {
    test('primary promise matches spec', () {
      expect(RecordFirstUsePromptCopy.title, 'Save one real moment.');
      expect(
        RecordFirstUsePromptCopy.body,
        ProgressiveEvidenceStateCopy.zeroBody,
      );
      expect(
        RecordScreenFramingCopy.emptyArchiveBody,
        contains('returned, changed, faded, or corrected'),
      );
    });

    test('demo entry label is clearly sample only', () {
      expect(RecordScreenFramingCopy.seeExampleLink, 'See an example');
      expect(RecordScreenFramingCopy.seeExampleFirstLink, 'See an example');
      expect(SampleArchiveCopy.emptyStateTitle, 'See an example first');
      expect(
        SampleArchiveCopy.emptyStateSubtitle.toLowerCase(),
        contains('example'),
      );
      expect(SampleArchiveCopy.emptyStateSubtitle, contains('Day 1'));
      expect(SampleArchiveCopy.emptyStateSubtitle, contains('Day 3'));
    });
  });

  group('First-proof journey strip', () {
    test('strip copy avoids streak homework framing', () {
      final blob = FirstProofJourneyCopy.allVisibleStrings()
          .join(' ')
          .toLowerCase();
      expect(
        FirstProofJourneyCopy.strip,
        '1 Save → 2 Compare → 3 First thread',
      );
      expect(blob, isNot(contains('streak')));
      expect(blob, isNot(contains('daily')));
      expect(blob, isNot(contains('must record')));
      expect(blob, contains('one moment starts the archive'));
    });
  });

  group('Progressive evidence states', () {
    test('states follow entry count thresholds', () {
      expect(
        ProgressiveEvidenceStateCopy.titleForCount(0),
        contains('Record one'),
      );
      expect(
        ProgressiveEvidenceStateCopy.titleForCount(1),
        contains('started'),
      );
      expect(
        ProgressiveEvidenceStateCopy.titleForCount(2),
        contains('compare'),
      );
      expect(ProgressiveEvidenceStateCopy.titleForCount(3), contains('thread'));
    });

    test('archive secondary links gated until 5 entries', () {
      expect(
        ArchiveSecondaryNavGates.showSecondaryLinks(entryCount: 4),
        isFalse,
      );
      expect(
        ArchiveSecondaryNavGates.showSecondaryLinks(entryCount: 5),
        isTrue,
      );
      expect(
        ArchiveSecondaryNavGates.showRicherDiscoverSections(entryCount: 20),
        isFalse,
      );
      expect(
        ArchiveSecondaryNavGates.showRicherDiscoverSections(entryCount: 21),
        isTrue,
      );
    });
  });

  group('V1 nav label', () {
    test('bottom nav archive tab label is Archive not Patterns', () {
      expect(ConsumerUiCopy.patternsTabLabel, 'Archive');
    });

    test(
      'secondary archive links exist for merged discover/timeline/search',
      () {
        expect(ConsumerUiCopy.archiveDiscoverPatternsLink, 'See all patterns');
        expect(ConsumerUiCopy.archiveTimelineLink, 'Timeline');
        expect(ConsumerUiCopy.archiveSearchLink, 'Find saved moments');
      },
    );
  });

  group('Expansion and wedge gates', () {
    test('expansion gates doc contains core V1 sentence and gated ideas', () {
      final doc = File(
        V1ExpansionGateCopy.expansionGatesDocPath,
      ).readAsStringSync();
      expect(doc, contains(V1ExpansionGateCopy.expansionBlockedLine));
      expect(doc, contains(V1CoreProductSentence.line));
      for (final surface in V1ExpansionGateCopy.blockedExpansionIdeas) {
        expect(doc.toLowerCase(), contains(surface.toLowerCase()));
      }
    });

    test('future wedge routes doc lists gated routes only', () {
      final doc = File('docs/FUTURE_WEDGE_ROUTES.md').readAsStringSync();
      for (final route in FutureWedgeRoutesCopy.futureRoutes) {
        expect(doc, contains(route));
      }
      expect(doc, contains('/start/prove-enough'));
      expect(doc, contains('/start/capacity-yes'));
    });
  });
}
