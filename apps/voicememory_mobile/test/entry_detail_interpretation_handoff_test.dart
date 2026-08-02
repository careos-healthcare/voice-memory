import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voicememory_mobile/api/api_transport.dart';
import 'package:voicememory_mobile/config/app_config.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion.dart';
import 'package:voicememory_mobile/features/remote_transcription/remote_transcription_disclosure.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/screens/entry_detail_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/secure_storage.dart';
import 'package:voicememory_mobile/widgets/record/compact_auditable_conclusion_card.dart';

const _entryId = 'saved-entry';
const _transcript =
    'I checked the finished task one more time before sending it.';

void main() {
  late Directory root;
  late bool failAnalysis;
  late List<String> requestedPaths;

  setUpAll(AppConfig.initApiResolution);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('entry_detail_handoff_');
    failAnalysis = false;
    requestedPaths = [];
    await AppServices.resetForTest(
      journalPath: '${root.path}/journal.json',
      skipRevenueCat: true,
      secureStorage: InMemorySecureStorageService(),
      apiTransport: ApiTransport(
        baseUrl: 'https://example.test',
        httpClient: MockClient((request) async {
          requestedPaths.add(request.url.path);
          if (request.url.path == '/api/auth/session') {
            return http.Response(
              '{}',
              401,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path == '/api/capture/attest') {
            return http.Response(
              jsonEncode({
                'ok': true,
                'token': 'capture-token',
                'expiresInSeconds': 3600,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path == '/api/analyze') {
            if (failAnalysis) {
              return http.Response(
                jsonEncode({'error': 'unavailable'}),
                500,
                headers: {'content-type': 'application/json'},
              );
            }
            return http.Response(
              jsonEncode({'reflection': _generatedReflection().toJson()}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            '{}',
            404,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );
  });

  tearDown(() async {
    await AppServices.disposeForTest().timeout(
      const Duration(seconds: 5),
      onTimeout: () {},
    );
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<JournalEntry> saveEntry({
    String transcript = _transcript,
    bool archived = false,
    bool deleted = false,
    Reflection reflection = const Reflection(
      mood: 'neutral',
      emotionalIntensity: 1,
      recurringThemes: [],
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    ),
  }) async {
    final entry = JournalEntry.fromJson({
      'id': _entryId,
      'ownerArchiveId': AppServices.instance.journalStore.ownerArchiveId,
      'createdAt': DateTime(2026, 8, 1, 10).toUtc().toIso8601String(),
      'updatedAt': DateTime(2026, 8, 1, 10).toUtc().toIso8601String(),
      'transcript': transcript,
      'durationSeconds': 12,
      'reflection': reflection.toJson(),
      if (archived) 'isArchived': true,
      if (deleted) 'deletedAt': DateTime(2026, 8, 2).toIso8601String(),
    });
    await AppServices.instance.journalStore.save(entry);
    return entry;
  }

  Future<void> pumpDetail(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: EntryDetailScreen(entryId: _entryId)),
    );
    await advanceUntilFound(
      tester,
      find.byKey(const Key('entry_detail_recorded_body')),
    );
  }

  testWidgets('an eligible active saved entry offers the exact CTA', (
    tester,
  ) async {
    await tester.runAsync(saveEntry);
    await pumpDetail(tester);

    expect(find.text('Generate a possible read'), findsOneWidget);
  });

  testWidgets('placeholder transcripts hide the CTA', (tester) async {
    await tester.runAsync(
      () => saveEntry(transcript: '[draft] transcription pending'),
    );
    await pumpDetail(tester);

    expect(find.text('Generate a possible read'), findsNothing);
  });

  testWidgets('archived entries hide the CTA', (tester) async {
    await tester.runAsync(() => saveEntry(archived: true));
    await pumpDetail(tester);

    expect(find.text('Generate a possible read'), findsNothing);
  });

  testWidgets('deleted entries hide the CTA', (tester) async {
    await tester.runAsync(() => saveEntry(deleted: true));
    await tester.pumpWidget(
      const MaterialApp(home: EntryDetailScreen(entryId: _entryId)),
    );
    await advanceUntilFound(
      tester,
      find.text('This saved moment is unavailable.'),
    );

    expect(find.text('Generate a possible read'), findsNothing);
  });

  testWidgets('ask-each-time decline keeps the original and blocks repeats', (
    tester,
  ) async {
    await tester.runAsync(saveEntry);
    await pumpDetail(tester);

    await tester.tap(find.text('Generate a possible read'));
    await advanceUntilFound(
      tester,
      find.byKey(const Key('post_capture_interpretation_sheet')),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.byKey(const Key('post_capture_interpretation_sheet')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('entry_detail_generate_read')),
          )
          .onPressed,
      isNull,
    );
    await tester.ensureVisible(find.text('Save without interpretation'));
    await tester.tap(find.text('Save without interpretation'));
    await advanceUntilFound(
      tester,
      find.text('Saved without an interpretation. Nothing was sent.'),
    );

    final stored = await tester.runAsync(
      () => AppServices.instance.journalStore.getById(_entryId),
    );
    expect(stored!.transcript, _transcript);
    expect(stored.reflection.explainableConclusion, isNull);
    expect(find.text('Generate a possible read'), findsOneWidget);
  });

  testWidgets(
    'accepted disclosure reloads and renders validated evidence controls',
    (tester) async {
      await tester.runAsync(saveEntry);
      AppServices.instance.tokenCache.setToken(
        'capture-token',
        expiresInSeconds: 3600,
      );
      await pumpDetail(tester);

      await tester.tap(find.text('Generate a possible read'));
      await advanceUntilFound(
        tester,
        find.byKey(const Key('post_capture_interpretation_sheet')),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.ensureVisible(find.text('Generate possible read'));
      await tester.tap(find.text('Generate possible read'));
      await advanceUntilFound(tester, find.text('Online interpretation'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Online interpretation'), findsOneWidget);
      await tester.ensureVisible(
        find.text('Continue with online interpretation'),
      );
      await tester.tap(find.text('Continue with online interpretation'));
      await advanceUntilFound(
        tester,
        find.byType(CompactAuditableConclusionCard),
      );
      expect(requestedPaths, contains('/api/analyze'));
      expect(find.byType(CompactAuditableConclusionCard), findsOneWidget);

      expect(find.text('Accurate'), findsOneWidget);
      expect(find.text('Wrong angle'), findsOneWidget);
      expect(find.text('Too generic'), findsOneWidget);
      expect(find.text('Hide'), findsOneWidget);
      expect(find.text('Check all evidence'), findsOneWidget);
      expect(find.text('Generate a possible read'), findsNothing);

      final stored = await tester.runAsync(
        () => AppServices.instance.journalStore.getById(_entryId),
      );
      expect(stored!.transcript, _transcript);
      expect(stored.reflection.explainableConclusion, isNotNull);
      await advanceRounds(tester, 20);
    },
  );

  testWidgets('remote failure leaves the saved original visible and intact', (
    tester,
  ) async {
    failAnalysis = true;
    await tester.runAsync(saveEntry);
    AppServices.instance.tokenCache.setToken(
      'capture-token',
      expiresInSeconds: 3600,
    );
    await tester.runAsync(
      () => AppServices.instance.remoteTranscriptionDisclosure.acceptCurrent(
        purpose: RemoteProcessingPurpose.interpretation,
      ),
    );
    await pumpDetail(tester);

    await tester.tap(find.text('Generate a possible read'));
    await advanceUntilFound(
      tester,
      find.byKey(const Key('post_capture_interpretation_sheet')),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.ensureVisible(find.text('Generate possible read'));
    await tester.tap(find.text('Generate possible read'));
    await advanceUntilFound(
      tester,
      find.text(
        'A possible read could not be produced. The moment is saved exactly as it is.',
      ),
    );

    final stored = await tester.runAsync(
      () => AppServices.instance.journalStore.getById(_entryId),
    );
    expect(stored!.transcript, _transcript);
    expect(stored.reflection.explainableConclusion, isNull);
    expect(find.text(_transcript), findsOneWidget);
  });
}

Future<void> advanceUntilFound(WidgetTester tester, Finder finder) async {
  await advanceUntil(tester, () => finder.evaluate().isNotEmpty);
  expect(finder, findsWidgets);
}

Future<void> advanceUntil(
  WidgetTester tester,
  bool Function() condition,
) async {
  for (var round = 0; round < 500 && !condition(); round++) {
    await tester.runAsync(() async {
      for (var yields = 0; yields < 4; yields++) {
        await Future<void>.delayed(Duration.zero);
      }
    });
    await tester.pump(const Duration(milliseconds: 1));
  }
  expect(condition(), isTrue);
}

Future<void> advanceRounds(WidgetTester tester, int rounds) async {
  for (var round = 0; round < rounds; round++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump(const Duration(milliseconds: 1));
  }
}

Reflection _generatedReflection() {
  final conclusion = ExplainableConclusion(
    id: 'generated-observation',
    statement: 'You described checking the finished task again.',
    confidence: 60,
    reasoning: const ['The exact saved words describe checking again.'],
    uncertaintyNote: 'One moment cannot establish a repeating pattern.',
    evidence: [
      TranscriptEvidenceCitation(
        entryId: _entryId,
        quote: _transcript,
        startUtf16: 0,
        endUtf16: _transcript.length,
        role: TranscriptEvidenceRole.supporting,
        sourceCapturedAt: DateTime(2026, 8, 1, 10).toUtc(),
        sourceType: EvidenceSourceType.voice,
      ),
    ],
    alternatives: const [
      ExplainableAlternative(
        statement: 'This may be specific to this one task.',
        rationale: 'Only one saved moment supports the observation.',
      ),
    ],
    provenance: ExplainableConclusionProvenance(
      source: 'model',
      generatedAt: DateTime(2026, 8, 1, 10, 1).toUtc(),
      schemaVersion: ExplainableConclusion.schemaVersion,
    ),
  );
  return Reflection(
    mood: 'neutral',
    emotionalIntensity: 1,
    recurringThemes: const [],
    exactLanguagePattern: _transcript,
    concreteObservation: conclusion.statement,
    repeatedSignal: '',
    explainableConclusion: conclusion,
  );
}
