// Public named parameters cannot expose private field names.
// ignore_for_file: prefer_initializing_formals

import '../../../../api/voice_capture_api_client.dart';
import '../../../../models/journal_entry.dart';
import '../../../../models/reflection.dart';
import '../../../../services/capture_attest_service.dart';
import '../../../../storage/journal_store.dart';
import '../../../monetization/domain/access_policy_engine.dart';
import '../../../processing_preferences/processing_preferences.dart';
import '../../../processing_preferences/processing_preferences_store.dart';
import '../../../remote_transcription/remote_transcription_disclosure.dart';

/// The second, separately answered question about a saved moment.
///
/// It is deliberately separate from the transcription choice: the moment is
/// already saved by the time this is asked, so neither answer can affect
/// whether the recording survives.
enum InterpretationDisposition {
  generatePossibleRead,
  saveWithoutInterpretation,
}

extension InterpretationDispositionLabel on InterpretationDisposition {
  String get label => switch (this) {
    InterpretationDisposition.generatePossibleRead => 'Generate possible read',
    InterpretationDisposition.saveWithoutInterpretation =>
      'Save without interpretation',
  };

  String get detail => switch (this) {
    InterpretationDisposition.generatePossibleRead =>
      ProcessingControlsCopy.generatePossibleReadDetail,
    InterpretationDisposition.saveWithoutInterpretation =>
      ProcessingControlsCopy.saveWithoutInterpretationDetail,
  };
}

abstract final class InterpretationCopy {
  static const title = 'Do you want a possible read?';
  static const body =
      'The moment is already saved either way. A possible read is one '
      'suggested interpretation of what you said, and you can ask for one '
      'later instead.';
  static const declinedNote =
      'Saved without an interpretation. Nothing was sent.';
  static const generatedNote = 'A possible read was added to this moment.';
  static const alreadyPresentNote = 'This moment already has a possible read.';
  static const notEligibleNote =
      'A possible read is not available on your plan right now. The moment is '
      'saved exactly as it is.';
  static const unavailableNote =
      'A possible read could not be produced. The moment is saved exactly as '
      'it is.';
  static const noTranscriptNote =
      'A possible read needs a transcript first. The moment is saved exactly '
      'as it is.';
  static const missingEntryNote = 'That moment is no longer in your archive.';
  static const requestLaterCta = 'Ask for a possible read';
}

enum InterpretationOutcomeKind {
  generated,
  alreadyPresent,
  declined,
  notEligible,
  unavailable,
  suppressed,
  inProgress,
  stale,
  noTranscript,
  missingEntry,
}

final class InterpretationOutcome {
  const InterpretationOutcome({
    required this.kind,
    required this.note,
    this.entry,
    this.decision,
  });

  final InterpretationOutcomeKind kind;
  final String note;
  final JournalEntry? entry;
  final AccessDecision? decision;

  /// True only when a request actually left this device.
  bool get contactedRemoteService =>
      kind == InterpretationOutcomeKind.generated ||
      kind == InterpretationOutcomeKind.unavailable;
}

/// Produces one possible read for an already-saved moment.
///
/// Kept behind an interface so declining interpretation is provably a
/// no-call path: a test can assert the runner was never asked.
abstract interface class InterpretationAnalysisRunner {
  Future<Reflection> analyze(JournalEntry entry);
}

/// Production runner: `/api/analyze`, reached only after consent.
final class RemoteInterpretationAnalysisRunner
    implements InterpretationAnalysisRunner {
  const RemoteInterpretationAnalysisRunner({
    required VoiceCaptureApiClient api,
    required CaptureAttestService attest,
  }) : _api = api,
       _attest = attest;

  final VoiceCaptureApiClient _api;
  final CaptureAttestService _attest;

  @override
  Future<Reflection> analyze(JournalEntry entry) async {
    final token = await _attest.ensureCaptureToken();
    return _api.postAnalyze(
      transcript: entry.transcript,
      captureToken: token,
      entryId: entry.id,
    );
  }
}

typedef InterpretationChoiceRequest =
    Future<InterpretationDisposition?> Function();

/// Asks — or remembers — whether a saved moment may be interpreted.
///
/// Every refusal path returns before the runner is touched, so declining can
/// never produce a request. The saved moment is never modified except to
/// attach a possible read the user asked for.
final class InterpretationDispositionCoordinator {
  InterpretationDispositionCoordinator({
    required JournalStore Function() journal,
    required InterpretationAnalysisRunner runner,
    required RemoteTranscriptionDisclosureGate disclosure,
    ProcessingPreferencesReader preferences =
        const FixedProcessingPreferences(),
    DateTime Function()? clock,
  }) : _journal = journal,
       _runner = runner,
       _disclosure = disclosure,
       _preferences = preferences,
       _clock = clock ?? DateTime.now;

  final JournalStore Function() _journal;
  final InterpretationAnalysisRunner _runner;
  final RemoteTranscriptionDisclosureGate _disclosure;
  final ProcessingPreferencesReader _preferences;
  final DateTime Function() _clock;
  static final Set<String> _inFlight = <String>{};

  /// Whether this archive may generate a new possible read at all.
  static AccessDecision decide({
    required EntitlementSnapshot entitlement,
    UsageSnapshot usage = const UsageSnapshot(),
    ProductValueState productValue = const ProductValueState(),
  }) => AccessPolicyEngine.decide(
    capability: CapabilityId.remoteObservationGeneration,
    entitlement: entitlement,
    usage: usage,
    productValue: productValue,
  );

  /// The question asked immediately after a capture is saved.
  Future<InterpretationOutcome> resolveForNewCapture({
    required String entryId,
    required InterpretationChoiceRequest requestChoice,
    required Future<bool> Function() requestDisclosure,
    EntitlementSnapshot entitlement = const EntitlementSnapshot.free(),
    UsageSnapshot usage = const UsageSnapshot(),
    ProductValueState productValue = const ProductValueState(),
  }) => _resolve(
    entryId: entryId,
    requestChoice: requestChoice,
    requestDisclosure: requestDisclosure,
    entitlement: entitlement,
    usage: usage,
    productValue: productValue,
  );

  /// The same question, asked later about a moment already in the archive.
  ///
  /// This is the path for a moment saved with everything declined: the audio
  /// and transcript are untouched, and the user can come back and ask for a
  /// read whenever they are eligible.
  Future<InterpretationOutcome> requestForExistingEntry({
    required String entryId,
    required Future<bool> Function() requestDisclosure,
    InterpretationChoiceRequest? requestChoice,
    EntitlementSnapshot entitlement = const EntitlementSnapshot.free(),
    UsageSnapshot usage = const UsageSnapshot(),
    ProductValueState productValue = const ProductValueState(),
  }) => _resolve(
    entryId: entryId,
    // Opening this path is itself the request, so an explicit prompt is
    // optional here.
    requestChoice:
        requestChoice ??
        () async => InterpretationDisposition.generatePossibleRead,
    requestDisclosure: requestDisclosure,
    entitlement: entitlement,
    usage: usage,
    productValue: productValue,
  );

  Future<InterpretationOutcome> _resolve({
    required String entryId,
    required InterpretationChoiceRequest requestChoice,
    required Future<bool> Function() requestDisclosure,
    required EntitlementSnapshot entitlement,
    required UsageSnapshot usage,
    required ProductValueState productValue,
  }) async {
    final store = _journal();
    final archiveId = store.ownerArchiveId;
    final requestKey = '$archiveId\u0000$entryId';
    if (!_inFlight.add(requestKey)) {
      return const InterpretationOutcome(
        kind: InterpretationOutcomeKind.inProgress,
        note: 'A possible read is already being prepared.',
      );
    }
    try {
      return await _resolveOnce(
        store: store,
        archiveId: archiveId,
        entryId: entryId,
        requestChoice: requestChoice,
        requestDisclosure: requestDisclosure,
        entitlement: entitlement,
        usage: usage,
        productValue: productValue,
      );
    } finally {
      _inFlight.remove(requestKey);
    }
  }

  Future<InterpretationOutcome> _resolveOnce({
    required JournalStore store,
    required String archiveId,
    required String entryId,
    required InterpretationChoiceRequest requestChoice,
    required Future<bool> Function() requestDisclosure,
    required EntitlementSnapshot entitlement,
    required UsageSnapshot usage,
    required ProductValueState productValue,
  }) async {
    final entry = await store.getById(entryId);
    if (entry == null) {
      return const InterpretationOutcome(
        kind: InterpretationOutcomeKind.missingEntry,
        note: InterpretationCopy.missingEntryNote,
      );
    }
    if (!_hasInterpretableTranscript(entry)) {
      return InterpretationOutcome(
        kind: InterpretationOutcomeKind.noTranscript,
        note: InterpretationCopy.noTranscriptNote,
        entry: entry,
      );
    }
    if (entry.reflection.explainableConclusion != null) {
      return InterpretationOutcome(
        kind: InterpretationOutcomeKind.alreadyPresent,
        note: InterpretationCopy.alreadyPresentNote,
        entry: entry,
      );
    }

    final chosen = await _chosenDisposition(requestChoice);
    if (chosen != InterpretationDisposition.generatePossibleRead) {
      return InterpretationOutcome(
        kind: InterpretationOutcomeKind.declined,
        note: InterpretationCopy.declinedNote,
        entry: entry,
      );
    }

    final decision = decide(
      entitlement: entitlement,
      usage: usage,
      productValue: productValue,
    );
    if (!decision.allowed) {
      return InterpretationOutcome(
        kind: InterpretationOutcomeKind.notEligible,
        note: InterpretationCopy.notEligibleNote,
        entry: entry,
        decision: decision,
      );
    }

    if (!await _hasCurrentDisclosureAcceptance()) {
      final accepted = await requestDisclosure();
      // The stored gate stays authoritative, so an approval that failed to
      // persist can never authorize a request.
      if (!accepted || !await _hasCurrentDisclosureAcceptance()) {
        return InterpretationOutcome(
          kind: InterpretationOutcomeKind.declined,
          note: InterpretationCopy.declinedNote,
          entry: entry,
          decision: decision,
        );
      }
    }

    try {
      final reflection = (await _runner.analyze(entry)).validatedForPersistence(
        transcript: entry.transcript,
        entryId: entry.id,
      );
      final currentStore = _journal();
      final latest = await store.getById(entry.id);
      if (currentStore.ownerArchiveId != archiveId ||
          latest == null ||
          latest.ownerArchiveId != archiveId ||
          latest.isDeleted ||
          latest.isArchived ||
          latest.transcript != entry.transcript ||
          latest.updatedAt != entry.updatedAt) {
        return InterpretationOutcome(
          kind: InterpretationOutcomeKind.stale,
          note:
              'The saved words changed before this possible read finished. '
              'Nothing was attached.',
          entry: latest ?? entry,
          decision: decision,
        );
      }
      if (!await _hasCurrentDisclosureAcceptance()) {
        return InterpretationOutcome(
          kind: InterpretationOutcomeKind.declined,
          note:
              'Interpretation permission changed before this possible read '
              'finished. Nothing was attached.',
          entry: latest,
          decision: decision,
        );
      }
      if (reflection.explainableConclusion == null) {
        return InterpretationOutcome(
          kind: InterpretationOutcomeKind.suppressed,
          note:
              'ArchiveMe could not support a possible read with exact evidence. '
              'The moment is still saved.',
          entry: latest,
          decision: decision,
        );
      }
      return InterpretationOutcome(
        kind: InterpretationOutcomeKind.generated,
        note: InterpretationCopy.generatedNote,
        entry: await _attach(store, latest, reflection),
        decision: decision,
      );
    } on Object {
      return InterpretationOutcome(
        kind: InterpretationOutcomeKind.unavailable,
        note: InterpretationCopy.unavailableNote,
        entry: entry,
        decision: decision,
      );
    }
  }

  /// The stored answer when there is one, otherwise the user's answer now.
  ///
  /// A dismissed prompt means no interpretation, because the moment is
  /// already safe and silence must never authorize a request.
  Future<InterpretationDisposition> _chosenDisposition(
    InterpretationChoiceRequest requestChoice,
  ) async {
    final remembered = await _rememberedDisposition();
    if (remembered != null) return remembered;
    return await requestChoice() ??
        InterpretationDisposition.saveWithoutInterpretation;
  }

  Future<InterpretationDisposition?> _rememberedDisposition() async {
    try {
      return switch ((await _preferences.read()).interpretation) {
        InterpretationPreference.askEachTime => null,
        InterpretationPreference.generatePossibleRead =>
          InterpretationDisposition.generatePossibleRead,
        InterpretationPreference.saveWithoutInterpretation =>
          InterpretationDisposition.saveWithoutInterpretation,
      };
    } on Object {
      return null;
    }
  }

  Future<bool> _hasCurrentDisclosureAcceptance() async {
    try {
      return (await _disclosure.check(
        purpose: RemoteProcessingPurpose.interpretation,
      )).isAccepted;
    } on Object {
      return false;
    }
  }

  Future<JournalEntry> _attach(
    JournalStore store,
    JournalEntry entry,
    Reflection reflection,
  ) async {
    final updated = JournalEntry.fromJson({
      ...entry.toJson(),
      'reflection': reflection.toJson(),
      'updatedAt': _clock().toUtc().toIso8601String(),
    });
    await store.save(updated, first25Source: 'interpretation_requested');
    return updated;
  }

  static bool _hasInterpretableTranscript(JournalEntry entry) {
    if (entry.isDeleted || entry.isArchived) return false;
    final transcript = entry.transcript.trim();
    if (transcript.isEmpty) return false;
    // Placeholders describe the absence of words rather than any of them.
    return !transcript.startsWith('[draft]');
  }
}
