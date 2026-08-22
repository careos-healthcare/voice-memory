import 'package:archiveme_mobile/api/api_error_message.dart';
import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/features/archive_evidence/comparable_evidence_text.dart';
import 'package:archiveme_mobile/features/archive_evidence/transcript_pending_copy.dart';
import 'package:archiveme_mobile/features/entry_detail/entry_detail_copy.dart';
import 'package:archiveme_mobile/features/post_save/post_save_recorded_summary_copy.dart';
import 'package:archiveme_mobile/features/voice_capture/provisional_transcript_copy.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_copy.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_quality.dart';
import 'package:archiveme_mobile/models/transcript_status.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/models/sync_status.dart';
import 'package:archiveme_mobile/product/consumer_copy_guard.dart';
import 'package:archiveme_mobile/security/user_content_safety.dart';

/// Source field used for user-facing entry display text.
enum EntryDisplayTextSource {
  transcript,
  body,
  exactLanguage,
  observation,
  summary,
  none,
}

extension EntryDisplayTextSourceLabel on EntryDisplayTextSource {
  String get logLabel => switch (this) {
    EntryDisplayTextSource.transcript => 'transcript',
    EntryDisplayTextSource.body => 'body',
    EntryDisplayTextSource.exactLanguage => 'exactLanguage',
    EntryDisplayTextSource.observation => 'observation',
    EntryDisplayTextSource.summary => 'summary',
    EntryDisplayTextSource.none => 'none',
  };
}

class EntryDisplayResolution {
  const EntryDisplayResolution({required this.text, required this.source});

  final String text;
  final EntryDisplayTextSource source;
}

/// Sanitized transcript stored on the journal entry.
String entrySanitizedTranscript(JournalEntry entry) =>
    UserContentSafety.sanitizePlainText(entry.transcript.trim());

/// Sanitized body text stored on the journal entry reflection.
String entrySanitizedBody(JournalEntry entry) =>
    UserContentSafety.sanitizePlainText(
      entry.reflection.concreteObservation.trim(),
    );

/// True when transcript text is an offline draft or system status placeholder.
bool isDraftOrSystemTranscriptPlaceholder(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return false;
  final lower = trimmed.toLowerCase();
  if (lower.startsWith('[draft]')) return true;
  if (lower == '[draft]') return true;
  if (lower == 'voice reflection') return true;

  const exactBlocked = [
    'saved on this device. cloud processing pending.',
    'saved privately on this device.',
    'saved privately on this device',
    'recording saved locally — transcribe when connected',
    'recording saved locally',
    'offline — saved as a draft',
    'you appear to be offline',
  ];
  for (final phrase in exactBlocked) {
    if (lower == phrase) return true;
  }

  const blockedSubstrings = [
    'recording saved locally',
    'transcribe when connected',
    'saved locally — transcribe',
  ];
  for (final fragment in blockedSubstrings) {
    if (lower.contains(fragment)) return true;
  }

  if (trimmed == AppConfig.backendNotConfiguredMessage) return true;
  if (trimmed == cloudBackendUnavailableMessage) return true;

  return false;
}

bool _isTransportErrorTranscript(String text) {
  final lower = text.toLowerCase();
  const blocked = ['connection refused', 'backend url not configured'];
  for (final phrase in blocked) {
    if (lower.contains(phrase)) return true;
  }
  return false;
}

bool hasPersistedCaptureText(JournalEntry entry) {
  final transcript = entrySanitizedTranscript(entry);
  final body = entrySanitizedBody(entry);
  final hasTranscript =
      transcript.isNotEmpty &&
      !isDraftOrSystemTranscriptPlaceholder(transcript);
  final hasBody =
      body.isNotEmpty && !ConsumerCopyGuard.isSystemObservation(body);
  return hasTranscript || hasBody;
}

/// Best non-placeholder capture text for persistence — transcript > body >
/// exactLanguage > observation.
String? resolveFinalCaptureTranscript({
  String? transcript,
  String? body,
  String? exactLanguage,
  String? observation,
}) {
  for (final raw in [transcript, body, exactLanguage, observation]) {
    final sanitized = UserContentSafety.sanitizePlainText(raw?.trim() ?? '');
    if (sanitized.isEmpty) continue;
    if (isDraftOrSystemTranscriptPlaceholder(sanitized)) continue;
    if (_isTransportErrorTranscript(sanitized)) continue;
    return sanitized;
  }
  return null;
}

/// Applies [finalTranscript] to voice entry fields used by display/insights.
/// Never replaces an existing real transcript with a draft placeholder.
JournalEntry applyFinalTranscriptToVoiceEntry(
  JournalEntry entry, {
  required String? finalTranscript,
  String? draftPlaceholder,
}) {
  final existing = resolveFinalCaptureTranscript(
    transcript: entry.transcript,
    body: entry.reflection.concreteObservation,
    exactLanguage: entry.reflection.exactLanguagePattern,
    observation: entry.reflection.concreteObservation,
  );
  final resolved = finalTranscript ?? existing;
  if (resolved == null || resolved.isEmpty) {
    if (draftPlaceholder == null || draftPlaceholder.trim().isEmpty) {
      return entry;
    }
    if (existing != null) return entry;
    return entry.copyWith(transcript: draftPlaceholder);
  }

  return entry.copyWith(
    transcript: resolved,
    reflection: Reflection(
      mood: entry.reflection.mood,
      emotionalIntensity: entry.reflection.emotionalIntensity,
      recurringThemes: entry.reflection.recurringThemes,
      exactLanguagePattern: entry.reflection.exactLanguagePattern,
      concreteObservation: resolved,
      repeatedSignal: entry.reflection.repeatedSignal,
      tensionOrContradiction: entry.reflection.tensionOrContradiction,
      avoidedOrVagueArea: entry.reflection.avoidedOrVagueArea,
      nextSmallAction: entry.reflection.nextSmallAction,
      patternObservations: entry.reflection.patternObservations,
    ),
  );
}

/// Priority: transcript > body > exactLanguage > observation > summary.
/// Never empty when persisted transcript/body is non-placeholder.
EntryDisplayResolution resolveEntryDisplayText(JournalEntry entry) {
  final transcript = entrySanitizedTranscript(entry);
  if (transcript.isNotEmpty &&
      !isDraftOrSystemTranscriptPlaceholder(transcript) &&
      !_isTransportErrorTranscript(transcript)) {
    return EntryDisplayResolution(
      text: transcript,
      source: EntryDisplayTextSource.transcript,
    );
  }

  final body = entrySanitizedBody(entry);
  if (body.isNotEmpty && !ConsumerCopyGuard.isSystemObservation(body)) {
    return EntryDisplayResolution(
      text: body,
      source: EntryDisplayTextSource.body,
    );
  }

  final exact = ConsumerCopyGuard.userFacingObservation(
    entry.reflection.exactLanguagePattern,
  );
  if (exact != null && exact.isNotEmpty) {
    return EntryDisplayResolution(
      text: UserContentSafety.sanitizePlainText(exact),
      source: EntryDisplayTextSource.exactLanguage,
    );
  }

  final observation = ConsumerCopyGuard.userFacingObservation(
    entry.reflection.concreteObservation,
  );
  if (observation != null && observation.isNotEmpty) {
    return EntryDisplayResolution(
      text: UserContentSafety.sanitizePlainText(observation),
      source: EntryDisplayTextSource.observation,
    );
  }

  final summary = ConsumerCopyGuard.userFacingObservation(
    entry.reflectionSummary,
  );
  if (summary != null && summary.isNotEmpty) {
    return EntryDisplayResolution(
      text: UserContentSafety.sanitizePlainText(summary),
      source: EntryDisplayTextSource.summary,
    );
  }

  return const EntryDisplayResolution(
    text: '',
    source: EntryDisplayTextSource.none,
  );
}

/// User-facing timeline card title — never transport errors or draft placeholders.
String timelineEntryTitle(JournalEntry entry) {
  if (ComparableEvidenceText.entryHasPendingTranscript(entry)) {
    return _recordingDateTitle(entry.createdAt);
  }

  final snippet = _transcriptSnippet(entry.transcript);
  if (snippet != null) return snippet;

  final summary = _reflectionSnippet(entry.reflectionSummary);
  if (summary != null) return summary;

  return _recordingDateTitle(entry.createdAt);
}

bool entryHasProvisionalTranscript(JournalEntry entry) =>
    entry.transcriptStatus == TranscriptStatus.provisional;

/// Short provisional transcript badge; null when server transcript is final.
String? timelineProvisionalTranscriptBadgeLabel(JournalEntry entry) {
  if (!entryHasProvisionalTranscript(entry)) return null;
  return ProvisionalTranscriptCopy.chipLabel;
}

/// Ordered status badges for timeline cards (sync, then transcript quality).
List<String> timelineEntryStatusBadgeLabels(JournalEntry entry) {
  final labels = <String>[];
  final sync = timelineSyncBadgeLabel(entry.syncStatus);
  if (sync != null) labels.add(sync);
  final provisional = timelineProvisionalTranscriptBadgeLabel(entry);
  if (provisional != null) labels.add(provisional);
  return labels;
}

/// Short sync badge on timeline cards; null when fully synced.
String? timelineSyncBadgeLabel(SyncStatus status) {
  switch (status) {
    case SyncStatus.synced:
      return null;
    case SyncStatus.localOnly:
    case SyncStatus.pendingUpload:
      return 'Offline';
    case SyncStatus.error:
      return 'Sync error';
    case SyncStatus.conflict:
      return 'Review';
  }
}

String? _transcriptSnippet(String transcript) {
  final line = transcript.split('\n').first.trim();
  if (line.isEmpty ||
      isDraftOrSystemTranscriptPlaceholder(line) ||
      _isTransportErrorTranscript(line)) {
    return null;
  }
  return UserContentSafety.safeSnippet(line);
}

String? _reflectionSnippet(String summary) {
  final observation = ConsumerCopyGuard.userFacingObservation(summary);
  if (observation == null) return null;
  return UserContentSafety.safeSnippet(observation);
}

String _recordingDateTitle(DateTime createdAt) {
  final local = createdAt.toLocal();
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final month = months[local.month - 1];
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  return 'Recording · $month ${local.day}, ${local.year} · $h:$m';
}

/// Full transcript or first line when it is safe to show in consumer UI.
String? entryUserFacingTranscript(JournalEntry entry) {
  final resolution = resolveEntryDisplayText(entry);
  if (resolution.source == EntryDisplayTextSource.transcript) {
    return resolution.text;
  }
  return _transcriptSnippet(entry.transcript);
}

/// Primary (and optional secondary) copy for entry detail — What you recorded.
EntryDetailRecordedView entryDetailRecordedView(JournalEntry entry) {
  final transcript = entryUserFacingTranscript(entry);
  if (transcript != null) {
    final isProvisional = entryHasProvisionalTranscript(entry);
    return EntryDetailRecordedView(
      primary: transcript,
      secondary: isProvisional ? ProvisionalTranscriptCopy.detailFootnote : null,
      isProvisionalTranscript: isProvisional,
    );
  }

  final exact = ConsumerCopyGuard.userFacingObservation(
    entry.reflection.exactLanguagePattern,
  );
  if (exact != null) {
    return EntryDetailRecordedView(
      primary: UserContentSafety.sanitizePlainText(exact),
    );
  }

  final observation = ConsumerCopyGuard.userFacingObservation(
    entry.reflection.concreteObservation,
  );
  if (observation != null) {
    return EntryDetailRecordedView(
      primary: UserContentSafety.sanitizePlainText(observation),
    );
  }

  if (VoiceCaptureQuality.isDegradedVoiceCapture(entry)) {
    return const EntryDetailRecordedView(
      primary: TranscriptPendingCopy.savedLocallyTitle,
      secondary: TranscriptPendingCopy.savedLocallyBody,
      isPendingTranscript: true,
      isDegradedTranscription: true,
    );
  }

  return const EntryDetailRecordedView(
    primary: EntryDetailCopy.transcriptPending,
    secondary: EntryDetailCopy.transcriptPendingBody,
    isPendingTranscript: true,
  );
}

/// Spoken text for offline read-aloud — null when nothing safe to synthesize.
String? entrySpeakableText(JournalEntry entry) {
  final view = entryDetailRecordedView(entry);
  if (view.isPendingTranscript || view.isDegradedTranscription) {
    return null;
  }

  final text = UserContentSafety.sanitizePlainText(view.primary.trim());
  if (text.isEmpty || isDraftOrSystemTranscriptPlaceholder(text)) {
    return null;
  }
  return text;
}

/// Whether post-save should show the heard card with real transcript text.
bool postSaveHasHeardText(JournalEntry entry) =>
    VoiceCaptureQuality.hasUsableSpokenText(entry);

/// Whether post-save should show degraded transcription fallback UI.
bool postSaveIsDegradedVoiceCapture(JournalEntry entry) =>
    VoiceCaptureQuality.isDegradedVoiceCapture(entry);

/// Short post-save summary (2–3 lines max) — never the full transcript.
String postSaveRecordedSummary(JournalEntry entry) {
  if (postSaveIsDegradedVoiceCapture(entry)) {
    return VoiceCaptureCopy.transcriptionFailedDegraded;
  }

  final resolution = resolveEntryDisplayText(entry);
  if (resolution.text.isNotEmpty) {
    return _trimPostSaveSummary(resolution.text);
  }
  return PostSaveRecordedSummaryCopy.emptyFallback;
}

/// Optional footnote under post-save heard text for device-native transcripts.
String? postSaveProvisionalFootnote(JournalEntry entry) {
  if (!entryHasProvisionalTranscript(entry)) return null;
  if (!VoiceCaptureQuality.hasUsableSpokenText(entry)) return null;
  return ProvisionalTranscriptCopy.postSaveFootnote;
}

String _trimPostSaveSummary(String text, {int maxLength = 220}) {
  return UserContentSafety.safeSnippet(text, maxChars: maxLength);
}

class EntryDetailRecordedView {
  const EntryDetailRecordedView({
    required this.primary,
    this.secondary,
    this.isPendingTranscript = false,
    this.isDegradedTranscription = false,
    this.isProvisionalTranscript = false,
  });

  final String primary;
  final String? secondary;
  final bool isPendingTranscript;
  final bool isDegradedTranscription;
  final bool isProvisionalTranscript;
}