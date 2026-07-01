import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/early_archive/archive_proof_surface_copy.dart';
import 'package:voicememory_mobile/features/early_archive/archive_proof_surface_layout.dart';
import 'package:voicememory_mobile/features/repeat_return_check/pattern_changed_analytics.dart';
import 'package:voicememory_mobile/features/repeat_return_check/pattern_changed_copy.dart';
import 'package:voicememory_mobile/features/repeat_return_check/pattern_changed_engine.dart';
import 'package:voicememory_mobile/features/repeat_return_check/pattern_changed_gates.dart';
import 'package:voicememory_mobile/features/repeat_return_check/pattern_changed_store.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_change_proof.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_copy.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_engine.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_trend.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/widgets/record/pattern_changed_card.dart';

RepeatReturnCheckRecord _answeredRecord({
  required String entryId,
  required RepeatReturnCheckChoice choice,
  int entryCountAtCapture = 4,
}) {
  return RepeatReturnCheckRecord(
    entryId: entryId,
    choice: choice,
    entryCountAtCapture: entryCountAtCapture,
    createdAt: DateTime(2026, 6, 13),
  );
}

RepeatReturnCheckChangeProof _proofForChoice(RepeatReturnCheckChoice choice) {
  return RepeatReturnCheckChangeProof(
    title: RepeatReturnCheckCopy.changeProofTitle,
    body: RepeatReturnCheckTrendEngine.bodyForChoice(choice),
    latestChoice: choice,
  );
}

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs() : super(file: File('test/tmp/pattern_changed/unused.json'));

  final Map<String, Map<String, dynamic>> jsonMaps = {};

  @override
  Future<Map<String, dynamic>?> readJsonMap(String key) async => jsonMaps[key];

  @override
  Future<void> writeJsonMap(String key, Map<String, dynamic> value) async {
    jsonMaps[key] = value;
  }
}

void _expectNoDiagnosticLanguage(String copy) {
  final lower = copy.toLowerCase();
  expect(lower, isNot(contains('diagnosis')));
  expect(lower, isNot(contains('therapy')));
  expect(lower, isNot(contains('disorder')));
}

void _expectNoCelebrationLanguage(String copy) {
  final lower = copy.toLowerCase();
  expect(lower, isNot(contains('congrat')));
  expect(lower, isNot(contains('streak')));
  expect(lower, isNot(contains('confetti')));
  expect(lower, isNot(contains('amazing')));
}

void main() {
  setUp(() async {
    PatternChangedAnalytics.resetForTest();
    await AppServices.resetForTest(
      journalPath: '${DateTime.now().microsecondsSinceEpoch}_pattern_changed.json',
      prefsPath: '${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
    await PatternChangedStore.resetForTest();
  });

  group('PatternChangedEngine', () {
    test('hidden before change proof', () {
      expect(
        PatternChangedEngine.build(
          changeProof: null,
          records: const [],
        ),
        isNull,
      );
      expect(
        PatternChangedEngine.build(
          changeProof: _proofForChoice(RepeatReturnCheckChoice.softer),
          records: const [],
        ),
        isNull,
      );
    });

    test('visible on softer', () {
      final proof = RepeatReturnCheckEngine.changeProofForReady(
        entryCount: 4,
        viewingConfirmedRepeat: true,
        isRecording: false,
        isPostSave: false,
        records: [_answeredRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.softer)],
      );
      final result = PatternChangedEngine.build(
        changeProof: proof,
        records: [_answeredRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.softer)],
      );
      expect(result, isNotNull);
      expect(result!.type, PatternChangedType.softer);
      expect(result.title, PatternChangedCopy.softerTitle);
      expect(result.body, PatternChangedCopy.softerBody);
      expect(result.isCelebration, isTrue);
    });

    test('neutral on stronger with no celebration language', () {
      final proof = RepeatReturnCheckEngine.changeProofForReady(
        entryCount: 4,
        viewingConfirmedRepeat: true,
        isRecording: false,
        isPostSave: false,
        records: [_answeredRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.stronger)],
      );
      final result = PatternChangedEngine.build(
        changeProof: proof,
        records: [_answeredRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.stronger)],
      );
      expect(result!.type, PatternChangedType.stronger);
      expect(result.title, PatternChangedCopy.strongerTitle);
      expect(result.body, PatternChangedCopy.strongerBody);
      expect(result.isCelebration, isFalse);
      _expectNoCelebrationLanguage('${result.title} ${result.body}');
    });

    test('visible on changed when softer then same without claiming louder', () {
      final records = [
        _answeredRecord(entryId: 'e5', choice: RepeatReturnCheckChoice.same),
        _answeredRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.softer),
      ];
      final proof = RepeatReturnCheckEngine.changeProofForReady(
        entryCount: 5,
        viewingConfirmedRepeat: true,
        isRecording: false,
        isPostSave: false,
        records: records,
      );
      final result = PatternChangedEngine.build(
        changeProof: proof,
        records: records,
      );
      expect(result!.type, PatternChangedType.changed);
      expect(result.title, PatternChangedCopy.changedTitle);
      expect(result.body, PatternChangedCopy.changedBody);
    });

    test('hidden on steady same-only answer', () {
      final proof = RepeatReturnCheckEngine.changeProofForReady(
        entryCount: 4,
        viewingConfirmedRepeat: true,
        isRecording: false,
        isPostSave: false,
        records: [_answeredRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.same)],
      );
      expect(
        PatternChangedEngine.build(
          changeProof: proof,
          records: [_answeredRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.same)],
        ),
        isNull,
      );
    });
  });

  group('PatternChangedGates', () {
    test('hidden during first-three activation', () {
      final result = PatternChangedEngine.build(
        changeProof: _proofForChoice(RepeatReturnCheckChoice.softer),
        records: [_answeredRecord(entryId: 'e3', choice: RepeatReturnCheckChoice.softer)],
      );
      expect(
        PatternChangedGates.shouldShow(
          loaded: true,
          entryCount: 3,
          isReady: true,
          isRecording: false,
          isPostSave: false,
          viewingConfirmedRepeat: true,
          patternChanged: result,
          dismissed: false,
        ),
        isFalse,
      );
    });

    test('hidden while recording', () {
      final result = PatternChangedEngine.build(
        changeProof: _proofForChoice(RepeatReturnCheckChoice.softer),
        records: [_answeredRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.softer)],
      );
      expect(
        PatternChangedGates.shouldShow(
          loaded: true,
          entryCount: 4,
          isReady: true,
          isRecording: true,
          isPostSave: false,
          viewingConfirmedRepeat: true,
          patternChanged: result,
          dismissed: false,
        ),
        isFalse,
      );
    });
  });

  group('PatternChangedCopy', () {
    test('no therapy or diagnosis language', () {
      for (final copy in [
        PatternChangedCopy.softerTitle,
        PatternChangedCopy.softerBody,
        PatternChangedCopy.changedTitle,
        PatternChangedCopy.changedBody,
        PatternChangedCopy.strongerTitle,
        PatternChangedCopy.strongerBody,
        PatternChangedCopy.recordIfReturnsCta,
      ]) {
        _expectNoDiagnosticLanguage(copy);
      }
    });
  });

  group('PatternChangedCard', () {
    testWidgets('shows softer celebration copy', (tester) async {
      final result = PatternChangedEngine.build(
        changeProof: _proofForChoice(RepeatReturnCheckChoice.softer),
        records: [_answeredRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.softer)],
      )!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PatternChangedCard.test(
              result: result,
              entryCount: 4,
              surface: 'record',
              onRecord: () {},
            ),
          ),
        ),
      );

      expect(find.text(PatternChangedCopy.softerTitle), findsOneWidget);
      expect(find.text(PatternChangedCopy.softerBody), findsOneWidget);
      expect(find.text(PatternChangedCopy.recordIfReturnsCta), findsOneWidget);
    });

    testWidgets('CTA triggers record callback', (tester) async {
      final result = PatternChangedEngine.build(
        changeProof: _proofForChoice(RepeatReturnCheckChoice.softer),
        records: [_answeredRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.softer)],
      )!;
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PatternChangedCard.test(
              result: result,
              entryCount: 4,
              surface: 'record',
              onRecord: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('pattern_changed_record_cta')));
      expect(tapped, isTrue);
    });

    testWidgets('dismiss hides card', (tester) async {
      final prefs = _MemoryPrefs();
      final store = PatternChangedStore(prefs);
      final result = PatternChangedEngine.build(
        changeProof: _proofForChoice(RepeatReturnCheckChoice.softer),
        records: [_answeredRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.softer)],
      )!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PatternChangedCard(
              result: result,
              entryCount: 4,
              surface: 'record',
              store: store,
              skipPrefsLoad: true,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('pattern_changed_dismiss')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pattern_changed_card_hidden')), findsOneWidget);
      expect(
        PatternChangedStore.isDismissed(
          entryId: result.entryId,
          type: result.type,
        ),
        isTrue,
      );
    });
  });

  group('PatternChangedAnalytics', () {
    test('metadata only without transcript text', () {
      Map<String, Object>? captured;
      PatternChangedAnalytics.captureForTest = (event, props) {
        captured = props;
      };

      PatternChangedAnalytics.seen(
        surface: 'record',
        entryCount: 4,
        changeType: PatternChangedType.softer,
      );

      expect(captured, isNotNull);
      expect(
        captured!.keys,
        containsAll(['surface', 'entry_count', 'change_type']),
      );
      expect(captured!.keys, isNot(contains('transcript')));
      expect(captured!['change_type'], 'softer');
    });
  });

  group('Pattern changed dedup', () {
    test('no duplicate change proof copy when pattern changed replaces proof', () {
      final proof = _proofForChoice(RepeatReturnCheckChoice.softer);
      final patternChanged = PatternChangedEngine.build(
        changeProof: proof,
        records: [_answeredRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.softer)],
      )!;

      final layout = ArchiveProofSurfaceLayout(
        confirmedRepeatCardVisible: true,
        timelineVisible: false,
        changeProofVisible: true,
        proBridgeVisible: false,
        patternChangedVisible: true,
      );

      expect(layout.effectiveChangeProofVisible, isFalse);
      expect(layout.effectivePatternChangedVisible, isTrue);

      final blocks = ArchiveProofSurfaceCopy.patternsStack(
        layout: layout,
        changeProof: proof,
        patternChanged: patternChanged,
      );

      expect(blocks, contains(PatternChangedCopy.softerTitle));
      expect(blocks, isNot(contains(RepeatReturnCheckCopy.changeProofTitle)));
      expect(blocks, isNot(contains(RepeatReturnCheckCopy.trendSofterThanBefore)));
      expect(
        blocks.where((block) => block == PatternChangedCopy.softerTitle),
        hasLength(1),
      );
    });

    test('record layout keeps pattern changed above folded summary copy', () {
      final layout = ArchiveProofSurfaceLayout(
        confirmedRepeatCardVisible: false,
        timelineVisible: false,
        changeProofVisible: true,
        proBridgeVisible: false,
        patternChangedVisible: true,
        archiveSummaryVisible: true,
      );

      expect(layout.recordPatternChangedVisible, isTrue);
      expect(layout.effectivePatternChangedVisible, isFalse);
    });

    test('folds into Archive Summary without duplicate pattern changed card', () {
      final layout = ArchiveProofSurfaceLayout(
        confirmedRepeatCardVisible: false,
        timelineVisible: false,
        changeProofVisible: true,
        proBridgeVisible: false,
        patternChangedVisible: true,
        archiveSummaryVisible: true,
      );

      expect(layout.effectivePatternChangedVisible, isFalse);
      final blocks = ArchiveProofSurfaceCopy.patternsStack(layout: layout);
      expect(blocks, isNot(contains(PatternChangedCopy.softerTitle)));
      expect(blocks, isNot(contains(RepeatReturnCheckCopy.changeProofTitle)));
    });
  });
}
