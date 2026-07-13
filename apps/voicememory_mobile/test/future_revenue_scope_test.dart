import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/acquisition/audience_wedge_habit_copy.dart';
import 'package:voicememory_mobile/features/acquisition/audience_wedge_model.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/future_revenue_scope/future_revenue_scope_copy.dart';
import 'package:voicememory_mobile/features/v1_visible_surface_reducer/v1_visible_surface_reducer_copy.dart';

void main() {
  group('FutureRevenueScopeCopy', () {
    test('lists deferred revenue directions', () {
      expect(FutureRevenueScopeCopy.futureDirections, contains('reports'));
      expect(FutureRevenueScopeCopy.futureDirections, contains('exports'));
      expect(FutureRevenueScopeCopy.futureDirections, contains('referrals'));
      expect(FutureRevenueScopeCopy.futureDirections, contains('safe sharing'));
      expect(FutureRevenueScopeCopy.futureDirections, contains('annual plan'));
      expect(FutureRevenueScopeCopy.futureDirections, contains('premium tiers'));
      expect(FutureRevenueScopeCopy.futureDirections, contains('b2b'));
      expect(
        FutureRevenueScopeCopy.futureDirections,
        contains('ranking / importance surfaces'),
      );
    });

    test('V1 growth loop stays blocked', () {
      expect(
        FutureRevenueScopeCopy.v1GrowthLoopLine.toLowerCase(),
        contains('not a v1 growth loop'),
      );
    });

    test('copy passes advice guard', () {
      for (final line in FutureRevenueScopeCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(line), isTrue, reason: line);
      }
    });
  });

  group('V1 reducer future scope alignment', () {
    test('hidden line names future revenue directions', () {
      final hidden = V1VisibleSurfaceReducerCopy.hiddenLine.toLowerCase();
      expect(hidden, contains('reports'));
      expect(hidden, contains('exports'));
      expect(hidden, contains('referrals'));
      expect(hidden, contains('safe sharing'));
      expect(hidden, contains('annual plan'));
      expect(hidden, contains('premium tiers'));
      expect(hidden, contains('b2b'));
    });
  });

  group('Audience wedge habit copy', () {
    test('teaches save-a-repeat habit', () {
      expect(
        AudienceWedgeHabitCopy.saveLine,
        contains('save one real moment here'),
      );
      expect(AudienceWedgeHabitCopy.notesLine, contains('Notes store it'));
      expect(
        AudienceWedgeHabitCopy.chatLine,
        contains('ChatGPT can help you talk it through'),
      );
    });

    test('notSureYet falls back to broad repeat prompt', () {
      expect(
        AudienceWedge.notSureYet.firstPrompt,
        AudienceWedgeHabitCopy.broadRepeatFallbackPrompt,
      );
    });

    test('prove wedge prompt teaches habit save', () {
      expect(
        AudienceWedge.doingMoreToFeelEnough.firstPrompt,
        contains('save one real moment here'),
      );
    });
  });

  group('Future revenue scope doc', () {
    test('doc exists and references proof trail', () {
      final doc = File('docs/FUTURE_REVENUE_SCOPE.md').readAsStringSync();
      expect(doc.toLowerCase(), contains('longer proof trail'));
      expect(doc.toLowerCase(), contains('testflight'));
    });
  });
}
