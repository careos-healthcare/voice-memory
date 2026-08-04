import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voicememory_mobile/api/api_client.dart';
import 'package:voicememory_mobile/config/app_config.dart';
import 'package:voicememory_mobile/features/monetization/domain/access_policy_engine.dart';
import 'package:voicememory_mobile/features/processing_preferences/online_processing_permission.dart';
import 'package:voicememory_mobile/features/processing_preferences/processing_controls_screen.dart';
import 'package:voicememory_mobile/features/processing_preferences/processing_preferences.dart';
import 'package:voicememory_mobile/features/processing_preferences/processing_preferences_store.dart';
import 'package:voicememory_mobile/features/recording/domain/application/interpretation_disposition_coordinator.dart';
import 'package:voicememory_mobile/features/recording/domain/application/on_device_transcription_availability.dart';
import 'package:voicememory_mobile/features/recording/domain/application/post_capture_disposition_coordinator.dart';
import 'package:voicememory_mobile/features/recording/domain/application/vault_persistence_coordinator.dart';
import 'package:voicememory_mobile/features/recording/post_capture_choice_sheet.dart';
import 'package:voicememory_mobile/features/remote_transcription/remote_transcription_disclosure.dart';
import 'package:voicememory_mobile/features/remote_transcription/remote_transcription_disclosure_dialog.dart';
import 'package:voicememory_mobile/features/transcription_queue/transcription_ledger.dart';
import 'package:voicememory_mobile/features/voice_capture/transcription/on_device_transcription_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/services/capture_attest_service.dart';
import 'package:voicememory_mobile/services/capture_pipeline_service.dart';
import 'package:voicememory_mobile/services/privacy/audio_vault_service.dart';
import 'package:voicememory_mobile/services/privacy/sensitive_temporary_audio_store.dart';
import 'package:voicememory_mobile/storage/capture_token_cache.dart';
import 'package:voicememory_mobile/storage/device_id.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

/// A transcript with enough real words to survive persistence validation.
const _spokenTranscript =
    'I said I would call my brother back and I did not call him back today.';

void main() {
  late Directory root;
  late Directory vaultDirectory;
  late Directory workingDirectory;
  late Directory protectedDirectory;
  late AudioVaultService vault;
  late JournalStore journal;
  late MobilePrefsStore prefs;
  late RemoteTranscriptionDisclosureStore disclosure;
  late ProcessingPreferencesStore preferences;
  late SensitiveTemporaryAudioStore temporaryAudio;
  late TranscriptionLedger ledger;

  /// Every byte that leaves this device passes through here.
  late int outboundHttpRequests;
  late VoiceCaptureApiClient api;
  late int remoteQueueStarts;

  setUpAll(AppConfig.initApiResolution);

  setUp(() async {
    ActivationFunnelAnalytics.resetForTest();
    ActivationFunnelAnalytics.captureForTest((_, _) {});
    root = await Directory.systemTemp.createTemp('ai_processing_controls_');
    vaultDirectory = Directory('${root.path}/vault');
    workingDirectory = Directory('${root.path}/working');
    protectedDirectory = Directory('${root.path}/protected');
    await protectedDirectory.create(recursive: true);
    temporaryAudio = SensitiveTemporaryAudioStore(
      directory: () async => protectedDirectory,
      legacyDirectories: const [],
    );
    vault = AudioVaultService(
      keyStore: InMemoryAudioVaultKeyStore(),
      vaultDirectory: () async => vaultDirectory,
      temporaryDirectory: () async => workingDirectory,
    );
    journal = JournalStore(
      file: File('${root.path}/journal.json'),
      ownerArchiveId: 'local',
    );
    prefs = await MobilePrefsStore.open('${root.path}/prefs.json');
    disclosure = RemoteTranscriptionDisclosureStore(() => prefs);
    preferences = ProcessingPreferencesStore(
      prefs: () => prefs,
      archiveId: () => journal.ownerArchiveId,
    );
    outboundHttpRequests = 0;
    api = VoiceCaptureApiClient(
      ApiTransport(
        baseUrl: 'https://example.test',
        httpClient: MockClient((_) async {
          outboundHttpRequests++;
          return http.Response('{}', 500);
        }),
      ),
    );
    remoteQueueStarts = 0;
    ledger = await TranscriptionLedger.open(
      directory: Directory('${root.path}/queue'),
    );
  });

  tearDown(() async {
    ActivationFunnelAnalytics.resetForTest();
    await ledger.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<File> capturedAudio([String name = 'capture.m4a']) async {
    final file = await temporaryAudio.create(
      ownerId: 'voice-capture',
      extension: 'm4a',
    );
    final bytes = List<int>.generate(
      4096,
      (index) => (index + name.length) % 251,
    )..setRange(4, 8, 'ftyp'.codeUnits);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  PostCaptureDispositionCoordinator captureCoordinator({
    OnDeviceTranscriptionEngine? onDeviceEngine,
    ProcessingPreferencesReader? processingPreferences,
  }) => PostCaptureDispositionCoordinator(
    vault: vault,
    journal: () => journal,
    onDeviceEngine: onDeviceEngine ?? _FakeOnDeviceEngine(),
    disclosure: disclosure,
    remoteQueue: VaultPersistenceCoordinator(ledger),
    startRemoteQueue: () async => remoteQueueStarts++,
    onDeviceSupport: const FixedOnDeviceTranscriptionSupport(true),
    preferences: processingPreferences ?? preferences,
    temporaryAudio: temporaryAudio,
  );

  InterpretationDispositionCoordinator interpretationCoordinator({
    InterpretationAnalysisRunner? runner,
    ProcessingPreferencesReader? processingPreferences,
  }) => InterpretationDispositionCoordinator(
    journal: () => journal,
    runner:
        runner ??
        RemoteInterpretationAnalysisRunner(api: api, attest: _FakeAttest(api)),
    disclosure: disclosure,
    preferences: processingPreferences ?? preferences,
  );

  Future<bool> refuse() async => false;

  Future<JournalEntry> savedSpokenMoment() async {
    final outcome =
        await captureCoordinator(
          onDeviceEngine: _FakeOnDeviceEngine(transcript: _spokenTranscript),
        ).resolve(
          audio: await capturedAudio(),
          durationSeconds: 11,
          requestChoice: (_) async => PostCaptureDisposition.transcribeOnDevice,
          requestRemoteDisclosure: refuse,
          confirmDelete: refuse,
        );
    expect(outcome.kind, PostCaptureOutcomeKind.transcribedOnDevice);
    return outcome.entry!;
  }

  const eligible = UsageSnapshot(
    allowances: {UsageMeterId.remoteObservationGeneration: 3},
  );
  const exhausted = UsageSnapshot(
    used: {UsageMeterId.remoteObservationGeneration: 1},
    allowances: {UsageMeterId.remoteObservationGeneration: 1},
  );

  group('no request precedes disclosure', () {
    test(
      'capture API boundary makes zero analysis calls without consent',
      () async {
        const text =
            'This original typed moment must be archived before any optional AI.';
        final pipeline = CapturePipelineService(
          api: api,
          attest: _FakeAttest(api),
          journalStore: journal,
        );

        final result = await pipeline.saveTextThought(transcript: text);

        expect(result.localSaved, isTrue);
        expect(result.analysisSucceeded, isFalse);
        expect(outboundHttpRequests, 0);
        expect((await journal.loadAll()).single.transcript, text);
      },
    );

    test('transcription acceptance never authorizes interpretation', () async {
      await disclosure.acceptCurrent(
        purpose: RemoteProcessingPurpose.transcription,
      );
      await preferences.setInterpretation(
        InterpretationPreference.generatePossibleRead,
      );
      final entry = await savedSpokenMoment();
      final runner = _SpyRunner();

      final outcome = await interpretationCoordinator(runner: runner)
          .resolveForNewCapture(
            entryId: entry.id,
            requestChoice: () async =>
                fail('the private standing interpretation choice is used'),
            requestDisclosure: () async => false,
            usage: eligible,
          );

      expect(outcome.kind, InterpretationOutcomeKind.declined);
      expect(runner.calls, 0);
      expect(outboundHttpRequests, 0);
      expect(
        (await disclosure.check(
          purpose: RemoteProcessingPurpose.interpretation,
        )).isAccepted,
        isFalse,
      );
    });

    test(
      'declining the transcription disclosure uploads and queues nothing',
      () async {
        var jobsWhenAsked = -1;
        var startsWhenAsked = -1;
        var requestsWhenAsked = -1;

        final outcome = await captureCoordinator().resolve(
          audio: await capturedAudio(),
          durationSeconds: 9,
          requestChoice: (_) async => PostCaptureDisposition.transcribeOnline,
          requestRemoteDisclosure: () async {
            jobsWhenAsked = ledger.jobs.length;
            startsWhenAsked = remoteQueueStarts;
            requestsWhenAsked = outboundHttpRequests;
            return false;
          },
          confirmDelete: refuse,
        );

        // Anything queued or started before this point would be an upload the
        // user had not yet agreed to.
        expect(jobsWhenAsked, 0);
        expect(startsWhenAsked, 0);
        expect(requestsWhenAsked, 0);
        expect(outcome.kind, PostCaptureOutcomeKind.savedAudioOnly);
        expect(outcome.audioRetained, isTrue);
        expect(ledger.jobs, isEmpty);
        expect(remoteQueueStarts, 0);
        expect(outboundHttpRequests, 0);
      },
    );

    test('declining the interpretation disclosure sends nothing', () async {
      final entry = await savedSpokenMoment();
      var requestsWhenAsked = -1;

      final outcome = await interpretationCoordinator().resolveForNewCapture(
        entryId: entry.id,
        requestChoice: () async =>
            InterpretationDisposition.generatePossibleRead,
        requestDisclosure: () async {
          requestsWhenAsked = outboundHttpRequests;
          return false;
        },
        entitlement: const EntitlementSnapshot.free(),
        usage: eligible,
      );

      expect(requestsWhenAsked, 0);
      expect(outcome.kind, InterpretationOutcomeKind.declined);
      expect(outcome.contactedRemoteService, isFalse);
      expect(outboundHttpRequests, 0);
      final stored = (await journal.getById(entry.id))!;
      expect(stored.transcript, _spokenTranscript);
      expect(stored.reflection.explainableConclusion, isNull);
    });

    test('accepting the interpretation disclosure is what sends it', () async {
      final entry = await savedSpokenMoment();

      final outcome = await interpretationCoordinator().resolveForNewCapture(
        entryId: entry.id,
        requestChoice: () async =>
            InterpretationDisposition.generatePossibleRead,
        requestDisclosure: () async {
          expect(
            outboundHttpRequests,
            0,
            reason: 'nothing may be sent before the answer',
          );
          await disclosure.acceptCurrent(
            purpose: RemoteProcessingPurpose.interpretation,
          );
          return true;
        },
        entitlement: const EntitlementSnapshot.free(),
        usage: eligible,
      );

      // The stubbed server refuses, but the request provably happened only
      // after acceptance — which is what makes the decline case meaningful.
      expect(outboundHttpRequests, greaterThan(0));
      expect(outcome.kind, InterpretationOutcomeKind.unavailable);
      expect(outcome.entry!.transcript, _spokenTranscript);
    });

    test('an ineligible archive never reaches the network', () async {
      final entry = await savedSpokenMoment();
      final runner = _SpyRunner();

      final outcome = await interpretationCoordinator(runner: runner)
          .resolveForNewCapture(
            entryId: entry.id,
            requestChoice: () async =>
                InterpretationDisposition.generatePossibleRead,
            requestDisclosure: () async =>
                fail('eligibility is decided before any disclosure'),
            entitlement: const EntitlementSnapshot.free(),
            usage: exhausted,
          );

      expect(outcome.kind, InterpretationOutcomeKind.notEligible);
      expect(outcome.decision!.allowed, isFalse);
      expect(runner.calls, 0);
      expect(outboundHttpRequests, 0);
    });
  });

  group('saved originals never depend on AI', () {
    test('a save with every AI step declined still succeeds', () async {
      final audio = await capturedAudio();
      final original = await audio.readAsBytes();
      final runner = _SpyRunner();

      final saved = await captureCoordinator().resolve(
        audio: audio,
        durationSeconds: 7,
        requestChoice: (_) async => PostCaptureDisposition.saveAudioOnly,
        requestRemoteDisclosure: () async =>
            fail('declining a transcript cannot ask for an upload'),
        confirmDelete: refuse,
      );

      final interpretation = await interpretationCoordinator(runner: runner)
          .resolveForNewCapture(
            entryId: saved.entry!.id,
            requestChoice: () async =>
                InterpretationDisposition.saveWithoutInterpretation,
            requestDisclosure: () async =>
                fail('declining a read cannot ask for an upload'),
          );

      expect(saved.kind, PostCaptureOutcomeKind.savedAudioOnly);
      expect(saved.audioRetained, isTrue);
      expect(
        interpretation.kind,
        anyOf(
          InterpretationOutcomeKind.declined,
          InterpretationOutcomeKind.noTranscript,
        ),
      );

      final entry = (await journal.loadAll()).single;
      expect(entry.id, saved.entry!.id);
      expect(
        await vault.readPlaintextBytes(entry.localAudioVaultRef!),
        original,
      );
      expect(await journal.exportJson(), contains(entry.id));
      expect(runner.calls, 0);
      expect(ledger.jobs, isEmpty);
      expect(remoteQueueStarts, 0);
      expect(outboundHttpRequests, 0);
    });

    test('declining interpretation does not remove the moment', () async {
      final entry = await savedSpokenMoment();
      final runner = _SpyRunner();

      final outcome = await interpretationCoordinator(runner: runner)
          .resolveForNewCapture(
            entryId: entry.id,
            requestChoice: () async =>
                InterpretationDisposition.saveWithoutInterpretation,
            requestDisclosure: () async => fail('nothing to disclose'),
          );

      expect(outcome.kind, InterpretationOutcomeKind.declined);
      final stored = (await journal.loadAll()).single;
      expect(stored.id, entry.id);
      expect(stored.transcript, _spokenTranscript);
      expect(await vault.exists(stored.localAudioVaultRef!), isTrue);
      expect(await journal.exportJson(), contains(entry.id));
      expect(runner.calls, 0);
    });

    test('a dismissed interpretation prompt means no', () async {
      final entry = await savedSpokenMoment();
      final runner = _SpyRunner();

      final outcome = await interpretationCoordinator(runner: runner)
          .resolveForNewCapture(
            entryId: entry.id,
            requestChoice: () async => null,
            requestDisclosure: () async => fail('silence is not consent'),
          );

      expect(outcome.kind, InterpretationOutcomeKind.declined);
      expect(runner.calls, 0);
    });
  });

  group('an existing moment can ask for a read later', () {
    test(
      'a previously declined moment can be interpreted afterwards',
      () async {
        final entry = await savedSpokenMoment();
        final runner = _SpyRunner();
        final coordinator = interpretationCoordinator(runner: runner);

        final declined = await coordinator.resolveForNewCapture(
          entryId: entry.id,
          requestChoice: () async =>
              InterpretationDisposition.saveWithoutInterpretation,
          requestDisclosure: () async => fail('nothing to disclose'),
        );
        expect(declined.kind, InterpretationOutcomeKind.declined);

        await disclosure.acceptCurrent(
          purpose: RemoteProcessingPurpose.interpretation,
        );
        final later = await coordinator.requestForExistingEntry(
          entryId: entry.id,
          requestDisclosure: () async => true,
          entitlement: const EntitlementSnapshot.free(),
          usage: eligible,
        );

        expect(later.kind, InterpretationOutcomeKind.generated);
        expect(runner.calls, 1);
        final stored = (await journal.getById(entry.id))!;
        expect(stored.transcript, _spokenTranscript);
        expect(stored.reflection.explainableConclusion, isNotNull);
      },
    );

    test('asking again returns the read already on the moment', () async {
      final entry = await savedSpokenMoment();
      final runner = _SpyRunner();
      final coordinator = interpretationCoordinator(runner: runner);
      await disclosure.acceptCurrent(
        purpose: RemoteProcessingPurpose.interpretation,
      );

      await coordinator.requestForExistingEntry(
        entryId: entry.id,
        requestDisclosure: () async => true,
        usage: eligible,
      );
      final again = await coordinator.requestForExistingEntry(
        entryId: entry.id,
        requestDisclosure: () async => fail('nothing new is being sent'),
        usage: eligible,
      );

      expect(again.kind, InterpretationOutcomeKind.alreadyPresent);
      expect(runner.calls, 1);
    });

    test('a moment with no transcript is left alone', () async {
      final saved = await captureCoordinator().resolve(
        audio: await capturedAudio(),
        durationSeconds: 4,
        requestChoice: (_) async => PostCaptureDisposition.saveAudioOnly,
        requestRemoteDisclosure: refuse,
        confirmDelete: refuse,
      );
      final runner = _SpyRunner();

      final outcome = await interpretationCoordinator(runner: runner)
          .requestForExistingEntry(
            entryId: saved.entry!.id,
            requestDisclosure: () async => fail('nothing to send'),
            usage: eligible,
          );

      expect(outcome.kind, InterpretationOutcomeKind.noTranscript);
      expect(runner.calls, 0);
      expect(await journal.loadAll(), hasLength(1));
    });
  });

  group('preferences are remembered privately', () {
    test('defaults ask every time and store nothing', () async {
      expect(await preferences.read(), ProcessingPreferences.askEveryTime);
      expect(
        await prefs.readJsonMap(ProcessingPreferencesStore.storageKey),
        isNull,
      );
    });

    test('a stored transcription answer replaces the question', () async {
      await preferences.setTranscription(
        TranscriptionPreference.saveWithoutTranscript,
      );

      var asked = 0;
      final outcome = await captureCoordinator().resolve(
        audio: await capturedAudio(),
        durationSeconds: 6,
        requestChoice: (_) async {
          asked++;
          return PostCaptureDisposition.transcribeOnline;
        },
        requestRemoteDisclosure: () async => fail('nothing may be uploaded'),
        confirmDelete: refuse,
      );

      expect(asked, 0);
      expect(outcome.kind, PostCaptureOutcomeKind.savedAudioOnly);
      expect(outboundHttpRequests, 0);
    });

    test('a stored online answer still requires the disclosure', () async {
      await preferences.setTranscription(TranscriptionPreference.online);
      var disclosureRequests = 0;

      final outcome = await captureCoordinator().resolve(
        audio: await capturedAudio(),
        durationSeconds: 6,
        requestChoice: (_) async => fail('the stored answer is used'),
        requestRemoteDisclosure: () async {
          disclosureRequests++;
          return false;
        },
        confirmDelete: refuse,
      );

      expect(disclosureRequests, 1);
      expect(outcome.kind, PostCaptureOutcomeKind.savedAudioOnly);
      expect(ledger.jobs, isEmpty);
      expect(outboundHttpRequests, 0);
    });

    test('an answer this device cannot honour falls back to asking', () async {
      await preferences.setTranscription(TranscriptionPreference.onThisDevice);
      final options = await PostCaptureDispositionCoordinator(
        vault: vault,
        journal: () => journal,
        onDeviceEngine: _FakeOnDeviceEngine(ready: false),
        disclosure: disclosure,
        remoteQueue: VaultPersistenceCoordinator(ledger),
        startRemoteQueue: () async {},
        temporaryAudio: temporaryAudio,
      ).options();

      expect(
        PostCaptureDispositionCoordinator.rememberedDisposition(
          options,
          TranscriptionPreference.onThisDevice,
        ),
        isNull,
      );
    });

    test('a stored interpretation answer replaces the question', () async {
      final entry = await savedSpokenMoment();
      await preferences.setInterpretation(
        InterpretationPreference.saveWithoutInterpretation,
      );
      final runner = _SpyRunner();

      final outcome = await interpretationCoordinator(runner: runner)
          .resolveForNewCapture(
            entryId: entry.id,
            requestChoice: () async => fail('the stored answer is used'),
            requestDisclosure: () async => fail('nothing may be sent'),
          );

      expect(outcome.kind, InterpretationOutcomeKind.declined);
      expect(runner.calls, 0);
    });

    test('answers are scoped to one archive and stay on the device', () async {
      await preferences.setTranscription(TranscriptionPreference.online);
      await preferences.setInterpretation(
        InterpretationPreference.generatePossibleRead,
      );

      final otherArchive = ProcessingPreferencesStore(
        prefs: () => prefs,
        archiveId: () => 'archive-two',
      );
      expect(await otherArchive.read(), ProcessingPreferences.askEveryTime);

      final stored = await prefs.readJsonMap(
        ProcessingPreferencesStore.storageKey,
      );
      expect(stored!.keys, contains('local'));
      expect(stored.keys, isNot(contains('archive-two')));
      expect(await journal.exportJson(), isNot(contains('processingPref')));
    });

    test('an answer can be changed and cleared at any time', () async {
      await preferences.setTranscription(TranscriptionPreference.online);
      expect(
        (await preferences.read()).transcription,
        TranscriptionPreference.online,
      );

      await preferences.setTranscription(TranscriptionPreference.onThisDevice);
      expect(
        (await preferences.read()).transcription,
        TranscriptionPreference.onThisDevice,
      );

      await preferences.clear();
      expect(await preferences.read(), ProcessingPreferences.askEveryTime);
    });
  });

  group('the choices are presented without bias', () {
    testWidgets('every transcription option is offered identically', (
      tester,
    ) async {
      PostCaptureDisposition? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () async {
                  selected = await showPostCaptureChoiceSheet(
                    context: context,
                    options: const PostCaptureChoiceOptions(
                      available: PostCaptureDisposition.values,
                      recommended: PostCaptureDisposition.transcribeOnline,
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('On this device'), findsOneWidget);
      expect(find.text('Online'), findsOneWidget);
      expect(find.text('Save without transcript'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      // No badge, no filled button, no pre-selection: nothing marks one answer
      // as the intended one.
      expect(find.byType(Chip), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('post_capture_choice_sheet')),
          matching: find.byType(FilledButton),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('post_capture_choice_sheet')),
          matching: find.byType(Radio<Object?>),
        ),
        findsNothing,
      );

      TextStyle styleOf(String label) =>
          tester.widget<Text>(find.text(label)).style!;
      expect(styleOf('Online'), styleOf('On this device'));
      expect(styleOf('Online'), styleOf('Save without transcript'));

      await tester.tap(find.text('Save without transcript'));
      await tester.pumpAndSettle();
      expect(selected, PostCaptureDisposition.saveAudioOnly);
    });

    testWidgets('both interpretation answers are offered identically', (
      tester,
    ) async {
      InterpretationDisposition? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () async {
                  selected = await showInterpretationChoiceSheet(
                    context: context,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Generate possible read'), findsOneWidget);
      expect(find.text('Save without interpretation'), findsOneWidget);
      expect(find.byType(Chip), findsNothing);

      TextStyle styleOf(String label) =>
          tester.widget<Text>(find.text(label)).style!;
      expect(
        styleOf('Generate possible read'),
        styleOf('Save without interpretation'),
      );

      await tester.tap(find.text('Save without interpretation'));
      await tester.pumpAndSettle();
      expect(selected, InterpretationDisposition.saveWithoutInterpretation);
    });
  });

  group('the disclosure names what is actually sent', () {
    Future<void> openDisclosure(
      WidgetTester tester,
      RemoteProcessingPurpose purpose,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => showRemoteTranscriptionDisclosure(
                  context: context,
                  store: disclosure,
                  purpose: purpose,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    testWidgets('audio for transcription', (tester) async {
      await openDisclosure(tester, RemoteProcessingPurpose.transcription);

      expect(
        find.text(RemoteTranscriptionDisclosureCopy.title),
        findsOneWidget,
      );
      expect(find.text(RemoteTranscriptionDisclosureCopy.body), findsOneWidget);
      expect(
        find.text(RemoteTranscriptionDisclosureCopy.continueOnline),
        findsOneWidget,
      );
    });

    testWidgets('text for a possible read', (tester) async {
      await openDisclosure(tester, RemoteProcessingPurpose.interpretation);

      expect(
        find.text(RemoteTranscriptionDisclosureCopy.interpretationTitle),
        findsOneWidget,
      );
      expect(
        find.text(RemoteTranscriptionDisclosureCopy.interpretationBody),
        findsOneWidget,
      );
      expect(
        find.text(RemoteTranscriptionDisclosureCopy.continueInterpretation),
        findsOneWidget,
      );
      // The audio wording must not appear where only text is sent.
      expect(find.text(RemoteTranscriptionDisclosureCopy.body), findsNothing);
    });
  });

  group('account settings', () {
    late InMemoryProcessingPreferences screenPreferences;
    late InMemoryOnlineProcessingPermission screenPermission;

    Future<void> openControls(
      WidgetTester tester, {
      bool permissionGranted = false,
    }) async {
      screenPreferences = InMemoryProcessingPreferences();
      screenPermission = InMemoryOnlineProcessingPermission(
        granted: permissionGranted,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ProcessingControlsScreen(
            preferences: screenPreferences,
            permission: screenPermission,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> choose(WidgetTester tester, String key) async {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
    }

    testWidgets('both defaults can be set and changed', (tester) async {
      await openControls(tester);

      await choose(tester, 'transcription_pref_onThisDevice');
      expect(
        (await screenPreferences.read()).transcription,
        TranscriptionPreference.onThisDevice,
      );

      await choose(tester, 'transcription_pref_saveWithoutTranscript');
      expect(
        (await screenPreferences.read()).transcription,
        TranscriptionPreference.saveWithoutTranscript,
      );

      await choose(tester, 'interpretation_pref_generatePossibleRead');
      expect(
        (await screenPreferences.read()).interpretation,
        InterpretationPreference.generatePossibleRead,
      );

      await choose(tester, 'interpretation_pref_askEachTime');
      expect(
        (await screenPreferences.read()).interpretation,
        InterpretationPreference.askEachTime,
      );
    });

    testWidgets('remote processing is explained in plain words', (
      tester,
    ) async {
      await openControls(tester);

      expect(
        find.text(ProcessingControlsCopy.remoteExplanationBody),
        findsOneWidget,
      );
      expect(find.text(ProcessingControlsCopy.scopeNote), findsOneWidget);
      expect(
        find.text(ProcessingControlsCopy.permissionNotGrantedBody),
        findsOneWidget,
      );
    });

    testWidgets('permission for online processing can be withdrawn', (
      tester,
    ) async {
      await openControls(tester, permissionGranted: true);

      expect(
        find.text(ProcessingControlsCopy.permissionGrantedBody),
        findsOneWidget,
      );
      await choose(tester, 'withdraw_online_processing_permission');

      expect(await screenPermission.isGranted(), isFalse);
      expect(
        find.text(ProcessingControlsCopy.permissionNotGrantedBody),
        findsOneWidget,
      );
    });
  });

  test('analytics boundary drops journal content', () {
    const privateContent =
        'I told Maria my private diagnosis and account token yesterday';
    final captured = <Map<String, Object>>[];
    ActivationFunnelAnalytics.captureForTest(
      (event, properties) => captured.add({'event': event, ...properties}),
    );

    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.firstRecordingSaved,
      source: privateContent,
      reason: privateContent,
      promptType: privateContent,
      entryCount: 1,
    );

    expect(captured, hasLength(1));
    expect(captured.single.values.join(' '), isNot(contains(privateContent)));
    expect(captured.single, isNot(contains('source')));
    expect(captured.single, isNot(contains('reason')));
    expect(captured.single, isNot(contains('prompt_type')));
    expect(captured.single['entry_count'], 1);
  });

  test(
    'withdrawing permission makes the next online capture ask again',
    () async {
      await disclosure.acceptCurrent();
      final permission = DisclosureOnlineProcessingPermission(disclosure);
      expect(await permission.isGranted(), isTrue);

      await permission.withdraw();
      expect(await permission.isGranted(), isFalse);

      var disclosureRequests = 0;
      final outcome = await captureCoordinator().resolve(
        audio: await capturedAudio(),
        durationSeconds: 5,
        requestChoice: (_) async => PostCaptureDisposition.transcribeOnline,
        requestRemoteDisclosure: () async {
          disclosureRequests++;
          return false;
        },
        confirmDelete: refuse,
      );

      expect(disclosureRequests, 1);
      expect(outcome.kind, PostCaptureOutcomeKind.savedAudioOnly);
      expect(outboundHttpRequests, 0);
    },
  );
}

final class _SpyRunner implements InterpretationAnalysisRunner {
  int calls = 0;

  @override
  Future<Reflection> analyze(JournalEntry entry) async {
    calls++;
    return const Reflection(
      mood: 'steady',
      emotionalIntensity: 2,
      recurringThemes: ['calling back'],
      exactLanguagePattern: 'did not call him back',
      concreteObservation: 'A stated intention was not acted on today.',
      repeatedSignal: '',
    );
  }
}

final class _FakeOnDeviceEngine implements OnDeviceTranscriptionEngine {
  _FakeOnDeviceEngine({this.ready = true, this.transcript = _spokenTranscript});

  final bool ready;
  final String transcript;

  @override
  Future<bool> isReady() async => ready;

  @override
  Future<void> prepare() async {}

  @override
  Future<String> transcribe(File audioFile) async => transcript;
}

final class _FakeAttest extends CaptureAttestService {
  _FakeAttest(VoiceCaptureApiClient api)
    : super(
        api: api,
        deviceIds: _FakeDeviceIdStore(),
        tokenCache: CaptureTokenCache(),
      );

  @override
  Future<String> ensureCaptureToken({bool forceRefresh = false}) async =>
      'capture-token';
}

final class _FakeDeviceIdStore extends DeviceIdStore {
  @override
  Future<String> getOrCreate() async => 'device-id';
}
