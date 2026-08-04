import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_ownership/archive_scope_paths.dart';
import 'package:voicememory_mobile/features/archive_ownership/local_archive_identity.dart';
import 'package:voicememory_mobile/features/journal/migration/saved_moment_legacy_adapter.dart';
import 'package:voicememory_mobile/features/study_mode/study_build_identity.dart';
import 'package:voicememory_mobile/features/study_mode/study_consent.dart';
import 'package:voicememory_mobile/features/study_mode/study_export.dart';
import 'package:voicememory_mobile/features/study_mode/study_feedback.dart';
import 'package:voicememory_mobile/features/study_mode/study_metrics.dart';
import 'package:voicememory_mobile/features/study_mode/study_mode_service.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/secure_storage.dart';

/// The real-user testing mode. The isolation group is modelled on
/// `archive_account_isolation_test.dart` and asks the same question from the
/// study angle: can a participant's study state, counters, or export ever
/// carry something belonging to a different account?
void main() {
  late Directory root;
  late InMemorySecureStorageService secure;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('vm_study_');
    secure = InMemorySecureStorageService();
  });

  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  StudyModeService service(
    LocalArchiveIdentity identity, {
    StudyBuildIdentity build = _identifiedBuild,
  }) => StudyModeService(secure: secure, identity: identity, build: build);

  Future<StudyModeService> enrolled(
    LocalArchiveIdentity identity, {
    String code = 'P-01',
    StudyBuildIdentity build = _identifiedBuild,
  }) async {
    final study = service(identity, build: build);
    await study.join(
      acknowledgedStatementCount: StudyConsentPolicy.statements.length,
      participantCode: code,
      at: _t(1),
    );
    return study;
  }

  group('consent', () {
    test('nothing is collected until the participant opts in', () async {
      final study = service(_accountB);

      await study.recordSignal(StudySignal.appOpened, at: _t(1));
      await study.recordSignal(StudySignal.captureCompleted, at: _t(2));

      expect(await study.consentState(), StudyConsentState.never);
      expect(await study.isEnrolled(), isFalse);
      expect((await study.metrics()).isEmpty, isTrue);
      expect(await study.exportJson(generatedAt: _t(3)), isNull);
      expect(await secure.read(study.metricsStorageKey), isNull);
    });

    test('a partial acknowledgement is a refusal, not a weaker yes', () async {
      final study = service(_accountB);

      await expectLater(
        study.join(
          acknowledgedStatementCount: StudyConsentPolicy.statements.length - 1,
          participantCode: 'P-01',
          at: _t(1),
        ),
        throwsA(
          isA<StudyEnrolmentException>().having(
            (error) => error.refusal,
            'refusal',
            StudyEnrolmentRefusal.statementsNotAcknowledged,
          ),
        ),
      );
      expect(await study.isEnrolled(), isFalse);
    });

    test('a participant code that could carry prose is refused', () async {
      final study = service(_accountB);

      await expectLater(
        study.join(
          acknowledgedStatementCount: StudyConsentPolicy.statements.length,
          participantCode: 'my name is sam',
          at: _t(1),
        ),
        throwsA(
          isA<StudyEnrolmentException>().having(
            (error) => error.refusal,
            'refusal',
            StudyEnrolmentRefusal.invalidParticipantCode,
          ),
        ),
      );
    });

    test('an archive with unsettled ownership cannot be enrolled', () async {
      for (final identity in [_awaitingDecision, _locked, _migrating]) {
        final study = service(identity);
        expect(study.mayEnrol, isFalse, reason: identity.archiveId);
        await expectLater(
          study.join(
            acknowledgedStatementCount: StudyConsentPolicy.statements.length,
            participantCode: 'P-09',
            at: _t(1),
          ),
          throwsA(
            isA<StudyEnrolmentException>().having(
              (error) => error.refusal,
              'refusal',
              StudyEnrolmentRefusal.ownershipUnsettled,
            ),
          ),
        );
      }
    });

    test('the consent screen states every promise the mode keeps', () {
      expect(StudyConsentPolicy.statements, hasLength(5));
      expect(StudyConsentPolicy.version, 'study_consent_v1_2026_08_01');
      expect(
        StudyConsentPolicy.statements.join(' ').toLowerCase(),
        allOf(
          contains('counts only'),
          contains('never collect your recordings'),
          contains('leave at any time'),
        ),
      );
      expect(
        StudyConsentPolicy.leaveStatement.toLowerCase(),
        contains('leave'),
      );
    });

    test('leaving stops collection and deletes what was collected', () async {
      final study = await enrolled(_accountB);
      await study.recordSignal(StudySignal.appOpened, at: _t(2));
      await study.submitFeedback(
        topic: StudyFeedbackTopic.capture,
        ease: 4,
        blocker: StudyFeedbackBlocker.none,
        at: _t(3),
        privateNote: 'the button was hard to find',
      );

      await study.leave(at: _t(4));
      await study.recordSignal(StudySignal.appOpened, at: _t(5));

      expect(await study.consentState(), StudyConsentState.revoked);
      expect(await study.isEnrolled(), isFalse);
      expect(await study.exportJson(generatedAt: _t(6)), isNull);
      expect(await secure.read(study.metricsStorageKey), isNull);
      expect(await secure.read(study.feedbackStorageKey), isNull);
      expect(await secure.read(study.notesStorageKey), isNull);
      expect((await study.metrics()).isEmpty, isTrue);
      expect(await study.privateNotes(), isEmpty);
    });

    test('re-joining after leaving starts from zero', () async {
      final study = await enrolled(_accountB);
      await study.recordSignal(StudySignal.appOpened, at: _t(2));
      await study.leave(at: _t(3));

      await study.join(
        acknowledgedStatementCount: StudyConsentPolicy.statements.length,
        participantCode: 'P-02',
        at: _t(4),
      );

      expect(await study.isEnrolled(), isTrue);
      expect((await study.metrics()).countOf(StudySignal.appOpened), 0);
    });

    test('consent given under an older policy lapses closed', () async {
      final study = service(_accountB);
      await secure.write(
        study.consentStorageKey,
        jsonEncode(
          StudyConsentRecord(
            archiveId: _accountB.archiveId,
            policyVersion: 'study_consent_v0_older',
            participantCode: 'P-01',
            grantedAt: _t(1),
            acknowledgedStatementCount: 5,
          ).toJson(),
        ),
      );

      await study.recordSignal(StudySignal.appOpened, at: _t(2));

      expect(await study.consentState(), StudyConsentState.lapsed);
      expect(await study.isEnrolled(), isFalse);
      expect(await study.exportJson(generatedAt: _t(3)), isNull);
      expect((await study.metrics()).isEmpty, isTrue);
    });
  });

  group('content-free export', () {
    test('the export carries counts, tokens and dates only', () async {
      final study = await enrolled(_accountB, code: 'P-07');
      await study.recordSignal(StudySignal.appOpened, at: _t(2));
      await study.recordSignal(StudySignal.appOpened, at: _t(2));
      await study.recordSignal(StudySignal.captureCompleted, at: _day(3));
      await study.submitFeedback(
        topic: StudyFeedbackTopic.speed,
        ease: 2,
        blocker: StudyFeedbackBlocker.tooSlow,
        at: _day(3),
      );

      final export =
          jsonDecode((await study.exportJson(generatedAt: _day(4)))!)
              as Map<String, dynamic>;

      expect(export['study_schema_version'], StudyExport.schemaVersion);
      expect(export['participant']['code'], 'P-07');
      expect(export['consent']['policy_version'], StudyConsentPolicy.version);
      expect(export['consent']['state'], 'granted');
      expect(export['metrics']['signals']['app_opened'], 2);
      expect(export['metrics']['signals']['capture_completed'], 1);
      expect(export['metrics']['signals']['capture_abandoned'], 0);
      expect(export['metrics']['active_day_count'], 2);
      expect(export['feedback']['entry_count'], 1);
      expect(export['feedback']['entries'].single['blocker'], 'too_slow');
      expect(export['feedback']['entries'].single['ease'], 2);
    });

    test('saved words never reach the export', () async {
      final store = await _open(root, _accountB);
      await store.save(_entry('b-1', owner: _accountB.archiveId));
      final study = await enrolled(_accountB);
      await study.recordSignal(StudySignal.captureCompleted, at: _t(2));
      await study.submitFeedback(
        topic: StudyFeedbackTopic.clarity,
        ease: 3,
        blocker: StudyFeedbackBlocker.confusing,
        at: _t(3),
        privateNote: 'I could not tell what the result meant',
      );

      final export = (await study.exportJson(generatedAt: _t(4)))!;

      expect(await store.exportJson(), contains(_secretWords));
      expect(export, isNot(contains(_secretWords)));
      expect(export, isNot(contains('I could not tell')));
      expect(export, isNot(contains(_accountB.archiveId)));
      expect(export, isNot(contains('subject-b')));
      expect(export, isNot(contains('vault-')));
      expect(RegExp(r'[A-Za-z]+ [A-Za-z]+').hasMatch(export), isFalse);
    });

    test('a note stays on the device and is only ever counted', () async {
      final study = await enrolled(_accountB);
      await study.submitFeedback(
        topic: StudyFeedbackTopic.other,
        ease: 5,
        blocker: StudyFeedbackBlocker.none,
        at: _t(2),
        privateNote: 'this part felt slow on my phone',
      );

      final notes = await study.privateNotes();
      final export =
          jsonDecode((await study.exportJson(generatedAt: _t(3)))!)
              as Map<String, dynamic>;

      expect(notes.single.text, 'this part felt slow on my phone');
      expect(export['feedback']['private_note_count'], 1);
      expect(export['feedback']['entries'].single['has_private_note'], 1);
      expect(jsonEncode(export), isNot(contains('felt slow')));
    });

    test('the export boundary rejects anything that reads as text', () {
      expect(
        () => StudyExport.requireContentFree({'note': 'two words'}),
        throwsStateError,
      );
      expect(
        () => StudyExport.requireContentFree({
          'metrics': [
            {'nested': 'a sentence here'},
          ],
        }),
        throwsStateError,
      );
      expect(
        () => StudyExport.requireContentFree({'a key with spaces': 1}),
        throwsStateError,
      );
      expect(
        () => StudyExport.requireContentFree({'ratio': 1.5}),
        throwsStateError,
      );
      expect(
        () => StudyExport.requireContentFree({
          'ok': 1,
          'also_ok': '2026-08-02T00:00:00.000Z',
          'absent': null,
        }),
        returnsNormally,
      );
    });

    test('feedback with an out-of-range rating is refused', () async {
      final study = await enrolled(_accountB);

      for (final ease in [0, 6, -1]) {
        await expectLater(
          study.submitFeedback(
            topic: StudyFeedbackTopic.price,
            ease: ease,
            blocker: StudyFeedbackBlocker.none,
            at: _t(2),
          ),
          throwsArgumentError,
        );
      }
      expect(await study.feedback(), isEmpty);
    });
  });

  group('build and policy identification', () {
    test('the export names the commit and the policy it ran under', () async {
      final study = await enrolled(_accountB);

      final export =
          jsonDecode((await study.exportJson(generatedAt: _t(2)))!)
              as Map<String, dynamic>;

      expect(export['build']['sha'], _sha);
      expect(export['build']['short_sha'], _sha.substring(0, 12));
      expect(export['build']['app_version'], '1.4.0');
      expect(export['build']['build_number'], '41');
      expect(export['build']['identified'], 1);
      expect(export['consent']['policy_version'], StudyConsentPolicy.version);
      expect(export['consent']['acknowledged_statements'], 5);
      expect(export['consent']['required_statements'], 5);
    });

    test('a build that cannot be traced says so instead of guessing', () async {
      final study = await enrolled(
        _accountB,
        build: const StudyBuildIdentity(
          declaredBuildSha: 'not-a-real-sha',
          declaredAppVersion: 'whatever',
          declaredBuildNumber: 'x',
        ),
      );

      final export =
          jsonDecode((await study.exportJson(generatedAt: _t(2)))!)
              as Map<String, dynamic>;

      expect(export['build']['sha'], StudyBuildIdentity.unknown);
      expect(export['build']['short_sha'], StudyBuildIdentity.unknown);
      expect(export['build']['app_version'], StudyBuildIdentity.unknown);
      expect(export['build']['identified'], 0);
    });

    test('an unconfigured build reports itself as unidentified', () {
      // No --dart-define is passed under `flutter test`, which is exactly the
      // case a study report must not silently attribute to a commit.
      expect(StudyBuildIdentity.fromBuildEnvironment.isIdentified, isFalse);
      expect(
        StudyBuildIdentity.fromBuildEnvironment.buildSha,
        StudyBuildIdentity.unknown,
      );
    });
  });

  group('cross-archive isolation', () {
    test('two accounts never share a study key', () {
      final a = service(_accountA);
      final b = service(_accountB);

      expect(a.consentStorageKey, isNot(b.consentStorageKey));
      expect(a.metricsStorageKey, isNot(b.metricsStorageKey));
      expect(a.feedbackStorageKey, isNot(b.feedbackStorageKey));
      expect(a.notesStorageKey, isNot(b.notesStorageKey));
    });

    test('a foreign agreement already on disk is invisible to B', () async {
      final b = service(_accountB);
      await secure.write(
        b.consentStorageKey,
        jsonEncode(
          StudyConsentRecord(
            archiveId: _accountA.archiveId,
            policyVersion: StudyConsentPolicy.version,
            participantCode: 'A-99',
            grantedAt: _t(1),
            acknowledgedStatementCount: 5,
          ).toJson(),
        ),
      );

      expect(await b.consentState(), StudyConsentState.never);
      expect(await b.isEnrolled(), isFalse);
      expect(await b.exportJson(generatedAt: _t(2)), isNull);
    });

    test('foreign counters are never read, exported, or extended', () async {
      final b = service(_accountB);
      await secure.write(
        b.metricsStorageKey,
        jsonEncode(
          StudyMetrics(
            archiveId: _accountA.archiveId,
          ).recording(StudySignal.appOpened, at: _t(1)).toJson(),
        ),
      );

      expect((await b.metrics()).countOf(StudySignal.appOpened), 0);

      await b.join(
        acknowledgedStatementCount: StudyConsentPolicy.statements.length,
        participantCode: 'P-02',
        at: _t(2),
      );
      await b.recordSignal(StudySignal.appOpened, at: _t(3));
      final export = (await b.exportJson(generatedAt: _t(4)))!;

      expect((await b.metrics()).countOf(StudySignal.appOpened), 1);
      expect(
        jsonDecode(export)['metrics']['signals']['app_opened'],
        1,
        reason: 'B must start at one, not inherit A\'s count',
      );
      expect(export, isNot(contains(_accountA.archiveId)));
      expect(export, isNot(contains('A-99')));
    });

    test('B never observes A activity, feedback, or notes', () async {
      final a = await enrolled(_accountA, code: 'A-01');
      final b = await enrolled(_accountB, code: 'B-01');
      await a.recordSignal(StudySignal.appOpened, at: _t(2));
      await a.recordSignal(StudySignal.appOpened, at: _t(3));
      await a.submitFeedback(
        topic: StudyFeedbackTopic.price,
        ease: 1,
        blocker: StudyFeedbackBlocker.notUseful,
        at: _t(4),
        privateNote: 'account a private words',
      );
      await b.recordSignal(StudySignal.appOpened, at: _t(5));

      expect((await b.metrics()).countOf(StudySignal.appOpened), 1);
      expect(await b.feedback(), isEmpty);
      expect(await b.privateNotes(), isEmpty);
      expect((await a.metrics()).countOf(StudySignal.appOpened), 2);
      expect(
        (await b.exportJson(generatedAt: _t(6)))!,
        isNot(contains('A-01')),
      );
      expect(
        (await b.exportJson(generatedAt: _t(6)))!,
        isNot(contains('not_useful')),
      );
    });

    test('B leaving the study leaves A enrolled and intact', () async {
      final a = await enrolled(_accountA, code: 'A-01');
      final b = await enrolled(_accountB, code: 'B-01');
      await a.recordSignal(StudySignal.captureCompleted, at: _t(2));

      await b.leave(at: _t(3));

      expect(await a.isEnrolled(), isTrue);
      expect((await a.metrics()).countOf(StudySignal.captureCompleted), 1);
      expect(await a.exportJson(generatedAt: _t(4)), isNotNull);
      expect(await b.exportJson(generatedAt: _t(4)), isNull);
    });

    test('the participant handle hides the archive it stands for', () {
      final refA = StudyExport.participantRef(_accountA.archiveId);
      final refB = StudyExport.participantRef(_accountB.archiveId);

      expect(refA, isNot(refB));
      expect(refA, hasLength(16));
      expect(refA, matches(RegExp(r'^[0-9a-f]{16}$')));
      expect(refA, isNot(contains(_accountA.archiveId)));
      expect(
        StudyExport.participantRef(_accountA.archiveId),
        refA,
        reason: 'must be stable across submissions',
      );
    });

    test('two accounts on one device produce separable exports', () async {
      final a = await enrolled(_accountA, code: 'A-01');
      final b = await enrolled(_accountB, code: 'B-01');
      await (await _open(
        root,
        _accountA,
      )).save(_entry('a-1', owner: _accountA.archiveId));

      final exportA =
          jsonDecode((await a.exportJson(generatedAt: _t(9)))!)
              as Map<String, dynamic>;
      final exportB =
          jsonDecode((await b.exportJson(generatedAt: _t(9)))!)
              as Map<String, dynamic>;

      expect(
        exportA['participant']['ref'],
        isNot(exportB['participant']['ref']),
      );
      expect(exportA['participant']['code'], 'A-01');
      expect(exportB['participant']['code'], 'B-01');
    });
  });

  group('production behaviour', () {
    final sources = Directory('lib/features/study_mode')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList(growable: false);

    test('the mode ships as one lean module', () {
      expect(sources, hasLength(7));
    });

    test('nothing here behaves differently in a debug build', () {
      final offenders = <String>[];
      for (final file in sources) {
        final source = file.readAsStringSync();
        for (final marker in const [
          'kDebugMode',
          'kReleaseMode',
          'kProfileMode',
          'debugPrint',
          'package:flutter/foundation.dart',
          'assert(',
        ]) {
          if (source.contains(marker)) offenders.add('${file.path}: $marker');
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('the mode exposes no debug surface and no product controls', () {
      final offenders = <String>[];
      for (final file in sources) {
        final source = file.readAsStringSync();
        for (final marker in const [
          '/debug',
          '/internal',
          'developer-diagnostics',
          'Navigator',
          'MaterialApp',
        ]) {
          if (source.contains(marker)) offenders.add('${file.path}: $marker');
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('the mode cannot reach saved content or the analytics pipe', () {
      final offenders = <String>[];
      for (final file in sources) {
        final source = file.readAsStringSync();
        for (final marker in const [
          'journal_store',
          'JournalStore',
          'journal_entry',
          'JournalEntry',
          'transcript',
          'firebase',
          'Firebase',
          'ProductAnalytics',
          'ActivationFunnelAnalytics',
          'analytics_catalog',
        ]) {
          if (source.contains(marker)) offenders.add('${file.path}: $marker');
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('the export builder has no path to a private note', () {
      final source = File(
        'lib/features/study_mode/study_export.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('study_private_note')));
      expect(source, isNot(contains('StudyPrivateNote')));
    });

    test('study keys stay inside the archive scope helper', () {
      final source = File(
        'lib/features/study_mode/study_mode_service.dart',
      ).readAsStringSync();

      expect(source, contains('ArchiveScopePaths.sanitize'));
      expect(source, contains('record.archiveId != identity.archiveId'));
    });
  });
}

const _sha = 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

const _identifiedBuild = StudyBuildIdentity(
  declaredBuildSha: _sha,
  declaredAppVersion: '1.4.0',
  declaredBuildNumber: '41',
);

const _accountA = LocalArchiveIdentity(
  archiveId: 'account-a',
  ownerKind: LocalArchiveOwnerKind.authenticated,
  authenticatedSubjectId: 'subject-a',
  ownershipState: LocalArchiveOwnershipState.active,
);

const _accountB = LocalArchiveIdentity(
  archiveId: 'account-b',
  ownerKind: LocalArchiveOwnerKind.authenticated,
  authenticatedSubjectId: 'subject-b',
  ownershipState: LocalArchiveOwnershipState.active,
);

const _awaitingDecision = LocalArchiveIdentity(
  archiveId: 'legacy-archive',
  ownerKind: LocalArchiveOwnerKind.legacyUnclaimed,
  ownershipState: LocalArchiveOwnershipState.awaitingDecision,
);

const _locked = LocalArchiveIdentity(
  archiveId: 'guest-archive',
  ownerKind: LocalArchiveOwnerKind.guest,
  ownershipState: LocalArchiveOwnershipState.locked,
);

const _migrating = LocalArchiveIdentity(
  archiveId: 'account-c',
  ownerKind: LocalArchiveOwnerKind.authenticated,
  authenticatedSubjectId: 'subject-c',
  ownershipState: LocalArchiveOwnershipState.migrating,
);

const _secretWords = 'pomegranate lighthouse confession';

DateTime _t(int minute) => DateTime.utc(2026, 8, 2, 9, minute);

DateTime _day(int day) => DateTime.utc(2026, 8, day, 9);

Future<JournalStore> _open(Directory root, LocalArchiveIdentity identity) =>
    JournalStore.open(
      ArchiveScopePaths.journalPath(basePath: root.path, identity: identity),
      ownerArchiveId: identity.archiveId,
      encryptAtRest: false,
    );

JournalEntry _entry(String id, {String? owner}) => JournalEntry(
  id: id,
  ownerArchiveId: owner ?? SavedMomentLegacyAdapter.legacyUnscopedArchiveId,
  createdAt: DateTime.utc(2026, 3, 2),
  transcript: _secretWords,
  durationSeconds: 12,
  localAudioVaultRef: 'vault-$id',
  syncStatus: SyncStatus.pendingUpload,
  reflection: const Reflection(
    mood: 'neutral',
    emotionalIntensity: 2,
    recurringThemes: [],
    exactLanguagePattern: 'a',
    concreteObservation: 'b',
    repeatedSignal: 'c',
  ),
);
