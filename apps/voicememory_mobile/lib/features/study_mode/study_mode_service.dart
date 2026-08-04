import 'dart:convert';

import '../../storage/secure_storage.dart';
import '../archive_ownership/archive_scope_paths.dart';
import '../archive_ownership/local_archive_identity.dart';
import 'study_build_identity.dart';
import 'study_consent.dart';
import 'study_export.dart';
import 'study_feedback.dart';
import 'study_metrics.dart';
import 'study_private_note.dart';

/// Why a participant cannot be enrolled right now.
enum StudyEnrolmentRefusal {
  /// The archive is locked, awaiting an ownership decision, or mid-migration.
  /// Nothing is collected until the user has settled who owns the content.
  ownershipUnsettled,

  /// The consent screen was not fully acknowledged.
  statementsNotAcknowledged,

  /// The run identifier is not a short upper-case token.
  invalidParticipantCode,
}

class StudyEnrolmentException implements Exception {
  const StudyEnrolmentException(this.refusal);

  final StudyEnrolmentRefusal refusal;

  @override
  String toString() => 'StudyEnrolmentException(${refusal.name})';
}

/// The whole real-user testing mode.
///
/// It changes nothing about how the product behaves: it holds an agreement, a
/// set of counters, and structured feedback alongside the app rather than
/// inside it. There is no build-mode switch anywhere in this file, so it works
/// identically in a release binary and in a test.
///
/// Every key it touches is derived from the archive identity it was
/// constructed with, and every record it reads back is checked against that
/// same identity before it is used. Two accounts on one device therefore have
/// separate agreements, separate counters, and separate exports, and neither
/// can observe the other's.
final class StudyModeService {
  StudyModeService({
    required SecureStorageService secure,
    required this.identity,
    this.build = StudyBuildIdentity.fromBuildEnvironment,
  }) : _secure = secure;

  static const _consentPrefix = 'study_mode_consent_v1_';
  static const _metricsPrefix = 'study_mode_metrics_v1_';
  static const _feedbackPrefix = 'study_mode_feedback_v1_';
  static const _notesPrefix = 'study_mode_notes_v1_';

  /// Bounded so a long run cannot grow local storage without limit.
  static const maxFeedbackEntries = 200;
  static const maxPrivateNotes = 200;

  final SecureStorageService _secure;
  final LocalArchiveIdentity identity;
  final StudyBuildIdentity build;

  /// Exposed so a test can assert two accounts never collide on one key.
  String get consentStorageKey => _key(_consentPrefix);

  String get metricsStorageKey => _key(_metricsPrefix);

  String get feedbackStorageKey => _key(_feedbackPrefix);

  String get notesStorageKey => _key(_notesPrefix);

  /// Only a settled, active archive may take part. A guest archive qualifies;
  /// one still awaiting an ownership decision does not.
  bool get mayEnrol =>
      identity.ownershipState == LocalArchiveOwnershipState.active &&
      identity.mayRender;

  Future<StudyConsentState> consentState() async =>
      (await _readConsent())?.state ?? StudyConsentState.never;

  Future<bool> isEnrolled() async =>
      (await consentState()) == StudyConsentState.granted;

  /// Opt in. Every statement in [StudyConsentPolicy.statements] must have been
  /// shown and acknowledged; a partial acknowledgement is a refusal, not a
  /// weaker yes.
  Future<StudyConsentRecord> join({
    required int acknowledgedStatementCount,
    required String participantCode,
    required DateTime at,
  }) async {
    if (!mayEnrol) {
      throw const StudyEnrolmentException(
        StudyEnrolmentRefusal.ownershipUnsettled,
      );
    }
    if (acknowledgedStatementCount < StudyConsentPolicy.statements.length) {
      throw const StudyEnrolmentException(
        StudyEnrolmentRefusal.statementsNotAcknowledged,
      );
    }
    final code = participantCode.trim().toUpperCase();
    if (!StudyConsentPolicy.isValidParticipantCode(code)) {
      throw const StudyEnrolmentException(
        StudyEnrolmentRefusal.invalidParticipantCode,
      );
    }

    final record = StudyConsentRecord(
      archiveId: identity.archiveId,
      policyVersion: StudyConsentPolicy.version,
      participantCode: code,
      grantedAt: at.toUtc(),
      acknowledgedStatementCount: acknowledgedStatementCount,
    );
    // A fresh agreement starts from zero. Counters left by an earlier run, or
    // by a lapsed policy version, are never carried into a new one.
    await _clearCollectedData();
    await _secure.write(consentStorageKey, jsonEncode(record.toJson()));
    return record;
  }

  /// Opt out. Collection stops immediately and the collected counts, feedback
  /// and notes are deleted. What survives is a stub recording that consent was
  /// given and then withdrawn, which carries no study data of its own.
  Future<void> leave({required DateTime at}) async {
    final existing = await _readConsent();
    await _clearCollectedData();
    if (existing == null) {
      await _secure.delete(consentStorageKey);
      return;
    }
    await _secure.write(
      consentStorageKey,
      jsonEncode(existing.revoked(at).toJson()),
    );
  }

  /// Records one catalogued signal. Silently does nothing unless the
  /// participant is enrolled right now, so nothing is ever collected before a
  /// yes or after a no.
  Future<void> recordSignal(StudySignal signal, {required DateTime at}) async {
    if (!await isEnrolled()) return;
    final metrics =
        await _readMetrics() ?? StudyMetrics(archiveId: identity.archiveId);
    await _secure.write(
      metricsStorageKey,
      jsonEncode(metrics.recording(signal, at: at).toJson()),
    );
  }

  Future<StudyMetrics> metrics() async =>
      await _readMetrics() ?? StudyMetrics(archiveId: identity.archiveId);

  /// Files one structured answer, and optionally a note that stays on device.
  ///
  /// Returns null when the participant is not enrolled.
  Future<StudyFeedbackEntry?> submitFeedback({
    required StudyFeedbackTopic topic,
    required int ease,
    required StudyFeedbackBlocker blocker,
    required DateTime at,
    String? privateNote,
  }) async {
    if (!await isEnrolled()) return null;
    if (!StudyFeedbackEntry.isValidEase(ease)) {
      throw ArgumentError.value(ease, 'ease', 'Must be 1 to 5.');
    }

    final note = StudyPrivateNote.normalize(privateNote);
    if (note != null) {
      final notes = [
        ...await privateNotes(),
        StudyPrivateNote(text: note, writtenAt: at.toUtc()),
      ];
      await _secure.write(
        notesStorageKey,
        jsonEncode(
          _tail(
            notes,
            maxPrivateNotes,
          ).map((item) => item.toJson()).toList(growable: false),
        ),
      );
    }

    final entry = StudyFeedbackEntry(
      topic: topic,
      ease: ease,
      blocker: blocker,
      submittedAt: at.toUtc(),
      hasPrivateNote: note != null,
    );
    final entries = _tail([...await feedback(), entry], maxFeedbackEntries);
    await _secure.write(
      feedbackStorageKey,
      jsonEncode(entries.map((item) => item.toJson()).toList(growable: false)),
    );
    await recordSignal(StudySignal.feedbackSubmitted, at: at);
    return entry;
  }

  Future<List<StudyFeedbackEntry>> feedback() async {
    final rows = await _readList(feedbackStorageKey);
    return List.unmodifiable(
      rows.map(StudyFeedbackEntry.fromJson).nonNulls.toList(growable: false),
    );
  }

  /// The participant's own notes, for the participant to read.
  ///
  /// Nothing in the export path calls this.
  Future<List<StudyPrivateNote>> privateNotes() async {
    final rows = await _readList(notesStorageKey);
    return List.unmodifiable(
      rows.map(StudyPrivateNote.fromJson).nonNulls.toList(growable: false),
    );
  }

  /// The payload the participant sends back, or null when they are not
  /// enrolled — including when their agreement was withdrawn, has lapsed onto
  /// an older policy version, or belongs to a different archive.
  Future<String?> exportJson({required DateTime generatedAt}) async {
    final consent = await _readConsent();
    if (consent == null || !consent.isActive) return null;
    return StudyExport.encode(
      consent: consent,
      build: build,
      metrics: await metrics(),
      feedback: await feedback(),
      privateNoteCount: (await privateNotes()).length,
      generatedAt: generatedAt,
    );
  }

  Future<void> _clearCollectedData() async {
    await _secure.delete(metricsStorageKey);
    await _secure.delete(feedbackStorageKey);
    await _secure.delete(notesStorageKey);
  }

  /// Fails closed: a record naming a different archive is treated as absent
  /// rather than adopted, so a mis-derived key or a tampered store can never
  /// hand one account another account's study state.
  Future<StudyConsentRecord?> _readConsent() async {
    final record = StudyConsentRecord.fromJson(
      await _readJson(consentStorageKey),
    );
    if (record == null || record.archiveId != identity.archiveId) return null;
    return record;
  }

  Future<StudyMetrics?> _readMetrics() async {
    final metrics = StudyMetrics.fromJson(await _readJson(metricsStorageKey));
    if (metrics == null || metrics.archiveId != identity.archiveId) {
      return null;
    }
    return metrics;
  }

  Future<Object?> _readJson(String key) async {
    final raw = await _secure.read(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  Future<List<Object?>> _readList(String key) async {
    final decoded = await _readJson(key);
    return decoded is List ? decoded : const [];
  }

  String _key(String prefix) =>
      '$prefix${ArchiveScopePaths.sanitize(identity.archiveId)}';

  static List<T> _tail<T>(List<T> items, int limit) =>
      items.length <= limit ? items : items.sublist(items.length - limit);
}
