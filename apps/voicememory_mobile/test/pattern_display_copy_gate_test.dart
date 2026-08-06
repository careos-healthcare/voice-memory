import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_belief_thread_model.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_evidence_heuristics.dart';
import 'package:voicememory_mobile/features/patterns/pattern_display_cache_cleanup.dart';
import 'package:voicememory_mobile/features/patterns/pattern_display_copy_gate.dart';
import 'package:voicememory_mobile/features/retention/second_session_signal_model.dart';
import 'package:voicememory_mobile/features/tomorrow_return/active_pattern_thread_model.dart';
import 'package:voicememory_mobile/features/tomorrow_return/watch_for_model.dart';
import 'package:voicememory_mobile/services/app_services.dart';

void main() {
  group('PatternDisplayCopyGate final sentences', () {
    test('hero rejects bad oh wow sentence', () {
      final result = PatternDisplayCopyGate.check(
        PatternDisplayField.hero,
        'The pressure seems to return around follow a heavy should.',
      );
      expect(result.approved, isFalse);
      expect(result.copy, PatternDisplayCopyGate.heroFallback);
    });

    test('current belief rejects bad sentence', () {
      final result = PatternDisplayCopyGate.check(
        PatternDisplayField.currentBelief,
        'You may do more when follow a heavy should.',
      );
      expect(result.approved, isFalse);
      expect(result.copy, PatternDisplayCopyGate.currentBeliefFallback);
    });

    test('what to test rejects bad sentence', () {
      final result = PatternDisplayCopyGate.check(
        PatternDisplayField.whatToTest,
        'Record another ordinary moment and notice whether follow a heavy should shows up again.',
      );
      expect(result.approved, isFalse);
      expect(result.copy, PatternDisplayCopyGate.whatToTestFallback);
    });

    test('rejects legacy template sentences', () {
      expect(
        PatternDisplayCopyGate.check(
          PatternDisplayField.currentBelief,
          'You may do more when pressure to make this work shows up again.',
        ).approved,
        isFalse,
      );
      expect(
        PatternDisplayCopyGate.check(
          PatternDisplayField.hero,
          'The pressure seems to return around feeling behind.',
        ).approved,
        isFalse,
      );
      expect(
        PatternDisplayCopyGate.check(
          PatternDisplayField.currentBelief,
          'You may do more when pressure from what you feel you should do.',
        ).approved,
        isFalse,
      );
    });

    test('approves PatternHumanCopy pressure observation', () {
      expect(
        PatternDisplayCopyGate.check(
          PatternDisplayField.currentBelief,
          'When pressure builds, you seem to push yourself to keep going — even when part of you does not want to.',
        ).approved,
        isTrue,
      );
    });

    test('rejects test to see fragments', () {
      expect(
        PatternDisplayCopyGate.check(
          PatternDisplayField.hero,
          'The pressure seems to return around is test to see.',
        ).approved,
        isFalse,
      );
      expect(
        PatternDisplayCopyGate.check(
          PatternDisplayField.whatToTest,
          'Record another ordinary moment and notice whether test to see if shows up again.',
        ).approved,
        isFalse,
      );
    });

    test('containsBlockedCopy detects malformed fragments', () {
      expect(
        PatternDisplayCopyGate.containsBlockedCopy(
          'The pressure seems to return around follow a heavy should.',
        ),
        isTrue,
      );
      expect(
        PatternDisplayCopyGate.containsBlockedCopy(
          'The pressure seems to return around feeling behind.',
        ),
        isTrue,
      );
    });
  });

  group('PatternDisplayCopyGate second session', () {
    test('sanitizeSecondSessionComparison replaces bad fields', () {
      final sanitized = PatternDisplayCopyGate.sanitizeSecondSessionComparison(
        const SecondSessionComparison(
          hasEnoughData: true,
          title: 'Possible repeat',
          body: 'Something may be repeating.',
          whatRepeated: 'You may do more when follow a heavy should.',
          whatToTestNext:
              'Record another ordinary moment and notice whether follow a heavy should shows up again.',
          possibleRepeat: true,
        ),
      );

      expect(sanitized.whatRepeated, PatternDisplayCopyGate.evidenceFallback);
      expect(
        sanitized.whatToTestNext,
        PatternDisplayCopyGate.whatToTestFallback,
      );
      expect(sanitized.whatRepeated, isNot(contains('follow a heavy should')));
    });
  });

  group('PatternDisplayCopyGate block fallback', () {
    test('replaces whole intelligence block when hero fails', () {
      final bundle = PatternDisplayCopyGate.sanitizeIntelligence(
        belief: const ArchiveBeliefThread(
          hasEnoughData: true,
          suggestionId: 'belief',
          currentBelief: 'You may do more when follow a heavy should.',
          evidenceLine: '3 entries point toward this.',
          whatChanged:
              'Your latest moment may sit differently from the one before it.',
          whatToTest:
              'Record another ordinary moment and notice whether follow a heavy should shows up again.',
          timeline: [],
        ),
        ohWow: const ArchiveOhWowMoment(
          hasMoment: true,
          kind: ArchiveOhWowKind.returned,
          title: 'Something came back.',
          body: 'The pressure seems to return around follow a heavy should.',
          suggestionId: 'oh_wow_returned',
        ),
        weekly: WeeklyWhatChangedReview.insufficient,
      );

      expect(bundle.usedBlockFallback, isTrue);
      expect(bundle.ohWow.body, PatternDisplayCopyGate.heroFallback);
      expect(
        bundle.belief.currentBelief,
        PatternDisplayCopyGate.currentBeliefFallback,
      );
      expect(
        bundle.belief.whatToTest,
        PatternDisplayCopyGate.whatToTestFallback,
      );
      expect(
        bundle.belief.currentBelief,
        isNot(contains('follow a heavy should')),
      );
    });
  });

  group('PatternDisplayCopyGate cached thread', () {
    test('ignores cached bad belief text', () {
      final thread = ActivePatternThread(
        id: 't1',
        title: 'You may do more when follow a heavy should.',
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 2),
        watchForText: 'whether follow a heavy should shows up again',
        chips: const [],
        status: ActivePatternThreadStatus.active,
        daysActive: 2,
        lastResult: WatchForResult.unclear,
        nextPrompt:
            'Record another ordinary moment and notice whether follow a heavy should shows up again.',
      );

      expect(PatternDisplayCopyGate.sanitizeActiveThread(thread), isNull);
    });

    test('keeps cached natural thread text', () {
      final thread = ActivePatternThread(
        id: 't2',
        title: 'You may be noticing pressure to make this work.',
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 2),
        watchForText: 'whether pressure to make this work shows up again',
        chips: const [],
        status: ActivePatternThreadStatus.active,
        daysActive: 2,
        lastResult: WatchForResult.unclear,
        nextPrompt:
            'Record another ordinary moment and notice what keeps repeating.',
      );

      expect(PatternDisplayCopyGate.sanitizeActiveThread(thread), isNotNull);
    });
  });

  group('PatternDisplayCacheCleanup', () {
    setUp(() async {
      final dir = Directory.systemTemp.createTempSync('vm_pattern_cache_');
      await AppServices.resetForTest(
        journalPath: '${dir.path}/journal.json',
        prefsPath: '${dir.path}/prefs.json',
        skipRevenueCat: true,
      );
      await PatternDisplayCacheCleanup.resetForTest();
    });

    test(
      'clears cached bad active pattern thread from MobilePrefsStore',
      () async {
        final prefs = AppServices.instance.prefs;
        await prefs.writeMap('activePatternThreadCurrent', {
          'id': 'bad-thread',
          'title': 'You may do more when follow a heavy should.',
          'createdAt': DateTime(2026, 6, 1).toIso8601String(),
          'updatedAt': DateTime(2026, 6, 2).toIso8601String(),
          'watchForText': 'whether follow a heavy should shows up again',
          'chips': <String>[],
          'status': 'active',
          'daysActive': 2,
          'lastResult': 'unclear',
          'nextPrompt':
              'Record another ordinary moment and notice whether follow a heavy should shows up again.',
        });

        await PatternDisplayCacheCleanup.runOnceIfNeeded();

        final cleared = await prefs.readMap('activePatternThreadCurrent');
        expect(cleared == null || cleared.isEmpty, isTrue);
      },
    );
  });
}
