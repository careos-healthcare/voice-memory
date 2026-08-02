import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/monetization/domain/access_policy_engine.dart';
import 'package:voicememory_mobile/features/processing_preferences/processing_preferences.dart';
import 'package:voicememory_mobile/features/processing_preferences/processing_preferences_store.dart';
import 'package:voicememory_mobile/features/recording/domain/application/interpretation_disposition_coordinator.dart';
import 'package:voicememory_mobile/features/remote_transcription/remote_transcription_disclosure.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';

const _transcript =
    'I agreed to help before checking whether I had enough time this week.';
const _eligible = UsageSnapshot(
  allowances: {UsageMeterId.remoteObservationGeneration: 3},
);

void main() {
  late Directory root;
  late JournalStore journal;
  late JournalStore activeJournal;
  late _PurposeDisclosureGate disclosure;

  setUp(() async {
    root = await Directory.systemTemp.createTemp(
      'interpretation_disposition_coordinator_',
    );
    journal = await JournalStore.open(
      '${root.path}/journal.json',
      ownerArchiveId: 'archive-one',
      encryptAtRest: false,
    );
    activeJournal = journal;
    disclosure = _PurposeDisclosureGate(interpretationAccepted: true);
    await journal.save(_entry());
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  InterpretationDispositionCoordinator coordinator({
    required InterpretationAnalysisRunner runner,
    ProcessingPreferencesReader preferences =
        const FixedProcessingPreferences(),
  }) => InterpretationDispositionCoordinator(
    journal: () => activeJournal,
    runner: runner,
    disclosure: disclosure,
    preferences: preferences,
    clock: () => DateTime.utc(2026, 8, 3, 10),
  );

  test(
    'askEachTime uses the current choice and makes exactly one request',
    () async {
      final runner = _ImmediateRunner();
      var choices = 0;

      final outcome = await coordinator(runner: runner).resolveForNewCapture(
        entryId: 'entry-1',
        requestChoice: () async {
          choices++;
          return InterpretationDisposition.generatePossibleRead;
        },
        requestDisclosure: () async => fail('disclosure is already accepted'),
        usage: _eligible,
      );

      expect(outcome.kind, InterpretationOutcomeKind.generated);
      expect(choices, 1);
      expect(runner.calls, 1);
      expect(
        (await journal.getById('entry-1'))!.reflection.explainableConclusion,
        isNotNull,
      );
    },
  );

  test(
    'generate standing preference bypasses the choice and generates',
    () async {
      final runner = _ImmediateRunner();

      final outcome =
          await coordinator(
            runner: runner,
            preferences: const FixedProcessingPreferences(
              ProcessingPreferences(
                interpretation: InterpretationPreference.generatePossibleRead,
              ),
            ),
          ).resolveForNewCapture(
            entryId: 'entry-1',
            requestChoice: () async => fail('standing preference must be used'),
            requestDisclosure: () async =>
                fail('disclosure is already accepted'),
            usage: _eligible,
          );

      expect(outcome.kind, InterpretationOutcomeKind.generated);
      expect(runner.calls, 1);
    },
  );

  test('saveWithout standing preference bypasses choice and runner', () async {
    final runner = _ImmediateRunner();

    final outcome =
        await coordinator(
          runner: runner,
          preferences: const FixedProcessingPreferences(
            ProcessingPreferences(
              interpretation:
                  InterpretationPreference.saveWithoutInterpretation,
            ),
          ),
        ).resolveForNewCapture(
          entryId: 'entry-1',
          requestChoice: () async => fail('standing preference must be used'),
          requestDisclosure: () async => fail('decline must not disclose'),
          usage: _eligible,
        );

    expect(outcome.kind, InterpretationOutcomeKind.declined);
    expect(runner.calls, 0);
  });

  test('interpretation requires its purpose-specific disclosure', () async {
    disclosure = _PurposeDisclosureGate(
      transcriptionAccepted: true,
      interpretationAccepted: false,
    );
    final runner = _ImmediateRunner();
    var disclosureRequests = 0;

    final outcome = await coordinator(runner: runner).resolveForNewCapture(
      entryId: 'entry-1',
      requestChoice: () async => InterpretationDisposition.generatePossibleRead,
      requestDisclosure: () async {
        disclosureRequests++;
        disclosure.interpretationAccepted = true;
        return true;
      },
      usage: _eligible,
    );

    expect(outcome.kind, InterpretationOutcomeKind.generated);
    expect(disclosureRequests, 1);
    expect(
      disclosure.checkedPurposes,
      everyElement(RemoteProcessingPurpose.interpretation),
    );
    expect(runner.calls, 1);
  });

  test('explicit decline and dismissed choice never call the runner', () async {
    for (final choice in <InterpretationDisposition?>[
      InterpretationDisposition.saveWithoutInterpretation,
      null,
    ]) {
      final runner = _ImmediateRunner();
      final outcome = await coordinator(runner: runner).resolveForNewCapture(
        entryId: 'entry-1',
        requestChoice: () async => choice,
        requestDisclosure: () async => fail('decline must not disclose'),
        usage: _eligible,
      );

      expect(outcome.kind, InterpretationOutcomeKind.declined);
      expect(runner.calls, 0);
    }
  });

  test('invalid runner output is unavailable and never generated', () async {
    final runner = _ThrowingRunner();

    final outcome = await coordinator(runner: runner).resolveForNewCapture(
      entryId: 'entry-1',
      requestChoice: () async => InterpretationDisposition.generatePossibleRead,
      requestDisclosure: () async => fail('disclosure is already accepted'),
      usage: _eligible,
    );

    expect(outcome.kind, InterpretationOutcomeKind.unavailable);
    expect(outcome.kind, isNot(InterpretationOutcomeKind.generated));
    expect(runner.calls, 1);
    expect(
      (await journal.getById('entry-1'))!.reflection.explainableConclusion,
      isNull,
    );
  });

  test(
    'suppressed validated output is not reported or attached as generated',
    () async {
      final runner = _ImmediateRunner(
        reflection: const _SuppressedReflection(),
      );

      final outcome = await coordinator(runner: runner).resolveForNewCapture(
        entryId: 'entry-1',
        requestChoice: () async =>
            InterpretationDisposition.generatePossibleRead,
        requestDisclosure: () async => fail('disclosure is already accepted'),
        usage: _eligible,
      );

      expect(outcome.kind, InterpretationOutcomeKind.suppressed);
      expect(outcome.kind, isNot(InterpretationOutcomeKind.generated));
      expect(
        (await journal.getById('entry-1'))!.reflection.explainableConclusion,
        isNull,
      );
    },
  );

  test(
    'transcript edit during request returns stale and attaches nothing',
    () async {
      final runner = _ControllableRunner();
      final future = coordinator(runner: runner).resolveForNewCapture(
        entryId: 'entry-1',
        requestChoice: () async =>
            InterpretationDisposition.generatePossibleRead,
        requestDisclosure: () async => fail('disclosure is already accepted'),
        usage: _eligible,
      );
      await runner.started.future;

      final original = (await journal.getById('entry-1'))!;
      await journal.save(
        JournalEntry.fromJson({
          ...original.toJson(),
          'transcript': 'The transcript was edited while analysis was running.',
        }),
      );
      runner.complete(_validReflection(original));

      final outcome = await future;
      expect(outcome.kind, InterpretationOutcomeKind.stale);
      final stored = (await journal.getById('entry-1'))!;
      expect(
        stored.transcript,
        'The transcript was edited while analysis was running.',
      );
      expect(stored.reflection.explainableConclusion, isNull);
    },
  );

  test(
    'simultaneous duplicate returns inProgress and calls runner once',
    () async {
      final runner = _ControllableRunner();
      final coordinatorUnderTest = coordinator(runner: runner);
      final first = coordinatorUnderTest.resolveForNewCapture(
        entryId: 'entry-1',
        requestChoice: () async =>
            InterpretationDisposition.generatePossibleRead,
        requestDisclosure: () async => fail('disclosure is already accepted'),
        usage: _eligible,
      );
      await runner.started.future;

      final duplicate = await coordinatorUnderTest.resolveForNewCapture(
        entryId: 'entry-1',
        requestChoice: () async =>
            InterpretationDisposition.generatePossibleRead,
        requestDisclosure: () async => fail('disclosure is already accepted'),
        usage: _eligible,
      );

      expect(duplicate.kind, InterpretationOutcomeKind.inProgress);
      expect(runner.calls, 1);
      runner.complete(_validReflection(_entry()));
      expect((await first).kind, InterpretationOutcomeKind.generated);
      expect(runner.calls, 1);
    },
  );

  test('archive scope change during request blocks attachment', () async {
    final runner = _ControllableRunner();
    final future = coordinator(runner: runner).resolveForNewCapture(
      entryId: 'entry-1',
      requestChoice: () async => InterpretationDisposition.generatePossibleRead,
      requestDisclosure: () async => fail('disclosure is already accepted'),
      usage: _eligible,
    );
    await runner.started.future;

    activeJournal = await JournalStore.open(
      '${root.path}/other-journal.json',
      ownerArchiveId: 'archive-two',
      encryptAtRest: false,
    );
    runner.complete(_validReflection(_entry()));

    final outcome = await future;
    expect(outcome.kind, InterpretationOutcomeKind.stale);
    expect(
      (await journal.getById('entry-1'))!.reflection.explainableConclusion,
      isNull,
    );
    expect(await activeJournal.getById('entry-1'), isNull);
  });
}

JournalEntry _entry() => JournalEntry(
  id: 'entry-1',
  createdAt: DateTime.utc(2026, 8, 3),
  transcript: _transcript,
  durationSeconds: 8,
  reflection: const Reflection(
    mood: 'neutral',
    emotionalIntensity: 0,
    recurringThemes: [],
    exactLanguagePattern: '',
    concreteObservation: '',
    repeatedSignal: '',
  ),
);

Reflection _validReflection(JournalEntry entry) =>
    Reflection.deterministicTranscriptOnly(
      transcript: entry.transcript,
      entryId: entry.id,
    );

final class _ImmediateRunner implements InterpretationAnalysisRunner {
  _ImmediateRunner({this._reflection});

  final Reflection? _reflection;
  int calls = 0;

  @override
  Future<Reflection> analyze(JournalEntry entry) async {
    calls++;
    return _reflection ?? _validReflection(entry);
  }
}

final class _ThrowingRunner implements InterpretationAnalysisRunner {
  int calls = 0;

  @override
  Future<Reflection> analyze(JournalEntry entry) async {
    calls++;
    throw const FormatException('invalid interpretation response');
  }
}

final class _ControllableRunner implements InterpretationAnalysisRunner {
  final started = Completer<void>();
  final _response = Completer<Reflection>();
  int calls = 0;

  @override
  Future<Reflection> analyze(JournalEntry entry) {
    calls++;
    if (!started.isCompleted) started.complete();
    return _response.future;
  }

  void complete(Reflection reflection) => _response.complete(reflection);
}

final class _PurposeDisclosureGate
    implements RemoteTranscriptionDisclosureGate {
  _PurposeDisclosureGate({
    this.transcriptionAccepted = false,
    this.interpretationAccepted = false,
  });

  bool transcriptionAccepted;
  bool interpretationAccepted;
  final checkedPurposes = <RemoteProcessingPurpose>[];

  @override
  Future<RemoteTranscriptionDisclosureResult> check({
    RemoteProcessingPurpose purpose = RemoteProcessingPurpose.transcription,
  }) async {
    checkedPurposes.add(purpose);
    final accepted = switch (purpose) {
      RemoteProcessingPurpose.transcription => transcriptionAccepted,
      RemoteProcessingPurpose.interpretation => interpretationAccepted,
    };
    return accepted
        ? const RemoteTranscriptionDisclosureResult.accepted(
            remoteTranscriptionDisclosureVersion,
          )
        : const RemoteTranscriptionDisclosureResult.required();
  }
}

final class _SuppressedReflection extends Reflection {
  const _SuppressedReflection()
    : super(
        mood: 'neutral',
        emotionalIntensity: 0,
        recurringThemes: const [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      );

  @override
  Reflection validatedForPersistence({
    required String transcript,
    required String entryId,
  }) => const Reflection(
    mood: 'neutral',
    emotionalIntensity: 0,
    recurringThemes: [],
    exactLanguagePattern: '',
    concreteObservation: '',
    repeatedSignal: '',
  );
}
