import 'package:archiveme_mobile/design/user_facing_date.dart';
import 'package:archiveme_mobile/features/privacy_trust/privacy_trust_copy.dart';
import 'package:archiveme_mobile/features/proof_admission/archive_correction.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/security/local_privacy_data_controls.dart';
import 'package:archiveme_mobile/security/private_data_service.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/account/stopped_observations_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_storage_sandbox.dart';

Reflection _reflection() => const Reflection(
  mood: 'neutral',
  emotionalIntensity: 1,
  recurringThemes: [],
  exactLanguagePattern: '',
  concreteObservation: 'You mentioned checking Slack.',
  repeatedSignal: '',
);

JournalEntry _entry({
  required String id,
  String transcript = 'I keep checking Slack before I go to sleep.',
}) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 3, 10, 12),
  transcript: transcript,
  durationSeconds: 12,
  reflection: _reflection(),
);

ArchiveCorrection _correction({
  required String id,
  List<String> evidenceRefs = const [],
  DateTime? createdAt,
}) {
  final at = createdAt ?? DateTime(2026, 3, 15, 12);
  return ArchiveCorrection(
    correctionId: id,
    archiveScope: 'default',
    targetProofId: 'proof-$id',
    targetProofFingerprint: 'fp-$id',
    semanticFramingFingerprint: 'frame-$id',
    wordingFingerprint: 'word-$id',
    affectedEvidenceRefs: evidenceRefs,
    choice: ArchiveCorrectionChoice.ignoreForever,
    createdAt: at,
    updatedAt: at,
    sourceSurface: 'test',
  );
}

class _FakePrivacyControls extends LocalPrivacyDataControls {
  _FakePrivacyControls({
    List<ArchiveCorrection> observations = const [],
    this.stopIgnoringResult = 1,
    this.stopIgnoringThrows = false,
  }) : observations = List.of(observations),
       super(
         privateDataService: PrivateDataService(
           journalStore: AppServices.instance.journalStore,
           prefs: AppServices.instance.prefs,
         ),
       );

  List<ArchiveCorrection> observations;
  final int stopIgnoringResult;
  final bool stopIgnoringThrows;
  int stopIgnoringCalls = 0;

  @override
  Future<List<ArchiveCorrection>> ignoredObservations({
    String? archiveScope,
  }) async {
    return List.of(observations);
  }

  @override
  Future<int> stopIgnoring(ArchiveCorrection correction, {DateTime? now}) async {
    stopIgnoringCalls++;
    if (stopIgnoringThrows) {
      throw StateError('undo failed');
    }
    if (stopIgnoringResult <= 0) {
      return stopIgnoringResult;
    }
    observations = observations
        .where((item) => item.correctionId != correction.correctionId)
        .toList();
    return stopIgnoringResult;
  }
}

Future<void> _pumpSheet(
  WidgetTester tester,
  LocalPrivacyDataControls controls,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: StoppedObservationsSheet(controls: controls)),
    ),
  );
  // Journal lookups in `_reload` are real I/O and need the real event loop.
  await tester.runAsync(() async {
    await Future<void>.delayed(Duration.zero);
  });
  await tester.pump();
  expect(find.byKey(const Key('stopped_observations_loading')), findsNothing);
}

void main() {
  late TestStorageSandbox sandbox;

  setUp(() async {
    sandbox = TestStorageSandbox.create();
    await AppServices.resetForTest(
      journalPath: sandbox.journalPath,
      prefsPath: sandbox.prefsPath,
      skipRevenueCat: true,
    );
  });

  tearDown(() => sandbox.dispose());

  testWidgets('empty state shows Nothing stopped.', (tester) async {
    await _pumpSheet(tester, _FakePrivacyControls());

    expect(find.byKey(const Key('stopped_observations_empty')), findsOneWidget);
    expect(find.text(PrivacyTrustCopy.stoppedObservationsEmpty), findsOneWidget);
    expect(find.text('Nothing stopped.'), findsOneWidget);
  });

  testWidgets('resolvable journal entry shows the snippet', (tester) async {
    const entryId = 'entry-present';
    const snippet = 'I keep checking Slack before I go to sleep.';
    await tester.runAsync(() async {
      await AppServices.instance.journalStore.save(_entry(id: entryId));
    });

    await _pumpSheet(
      tester,
      _FakePrivacyControls(
        observations: [
          _correction(id: 'c-present', evidenceRefs: const [entryId]),
        ],
      ),
    );

    expect(
      find.byKey(const Key('stopped_observations_row_c-present')),
      findsOneWidget,
    );
    expect(find.textContaining(snippet), findsOneWidget);
    expect(find.text('Nothing stopped.'), findsNothing);
  });

  testWidgets(
    'missing journal entry shows Stopped · date fallback',
    (tester) async {
      final createdAt = DateTime(2026, 3, 15, 12);
      final fallback = PrivacyTrustCopy.stoppedObservationsFallback(
        formatUserFacingDate(createdAt),
      );

      await _pumpSheet(
        tester,
        _FakePrivacyControls(
          observations: [
            _correction(
              id: 'c-missing',
              evidenceRefs: const ['entry-gone'],
              createdAt: createdAt,
            ),
          ],
        ),
      );

      expect(
        find.byKey(const Key('stopped_observations_row_c-missing')),
        findsOneWidget,
      );
      expect(find.text(fallback), findsOneWidget);
      expect(find.text('Stopped · ${formatUserFacingDate(createdAt)}'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping Undo shows confirm dialog before stopIgnoring is called',
    (tester) async {
      final controls = _FakePrivacyControls(
        observations: [_correction(id: 'c-undo')],
      );

      await _pumpSheet(tester, controls);
      await tester.tap(
        find.byKey(const Key('stopped_observations_undo_c-undo')),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('stopped_observations_undo_confirm')),
        findsOneWidget,
      );
      expect(find.text(PrivacyTrustCopy.stoppedObservationsUndoTitle), findsOneWidget);
      expect(controls.stopIgnoringCalls, 0);
    },
  );

  testWidgets(
    'confirming Undo calls stopIgnoring and removes the item',
    (tester) async {
      final controls = _FakePrivacyControls(
        observations: [_correction(id: 'c-confirm')],
      );

      await _pumpSheet(tester, controls);
      await tester.tap(
        find.byKey(const Key('stopped_observations_undo_c-confirm')),
      );
      await tester.pump();
      expect(controls.stopIgnoringCalls, 0);

      await tester.tap(
        find.byKey(const Key('stopped_observations_undo_accept')),
      );
      await tester.pump();
      await tester.pump();

      expect(controls.stopIgnoringCalls, 1);
      expect(
        find.byKey(const Key('stopped_observations_row_c-confirm')),
        findsNothing,
      );
      expect(find.text(PrivacyTrustCopy.stoppedObservationsEmpty), findsOneWidget);
    },
  );

  testWidgets(
    'failed undo shows snackbar and keeps the item',
    (tester) async {
      final controls = _FakePrivacyControls(
        observations: [_correction(id: 'c-fail')],
        stopIgnoringResult: 0,
      );

      await _pumpSheet(tester, controls);
      await tester.tap(
        find.byKey(const Key('stopped_observations_undo_c-fail')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('stopped_observations_undo_accept')),
      );
      await tester.pump();
      await tester.pump();

      expect(controls.stopIgnoringCalls, 1);
      expect(
        find.text(PrivacyTrustCopy.stoppedObservationsUndoFailed),
        findsOneWidget,
      );
      expect(find.text('Could not undo. Try again.'), findsOneWidget);
      expect(
        find.byKey(const Key('stopped_observations_row_c-fail')),
        findsOneWidget,
      );
    },
  );
}
