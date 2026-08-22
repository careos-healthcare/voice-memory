import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_quality_gate.dart';
import 'package:archiveme_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:archiveme_mobile/features/three_day_challenge/three_day_challenge_copy.dart';
import 'package:archiveme_mobile/features/three_day_challenge/three_day_challenge_model.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_quality.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Visibility gates for early record guidance aligned with the landing promise.
abstract final class ThreeDayChallengeGates {
  ThreeDayChallengeGates._();

  static const maxEarlyEntryCount = 7;

  static bool isEarlyUser({required int entryCount}) =>
      entryCount <= maxEarlyEntryCount;

  static bool shouldShow({
    required bool isReady,
    required bool isRecording,
    required bool isPostSave,
    required bool isDegradedTranscriptState,
    required bool firstProofPayoffVisible,
    ThreeDayChallengeState? challenge,
  }) =>
      isReady &&
      !isRecording &&
      !isPostSave &&
      !isDegradedTranscriptState &&
      !firstProofPayoffVisible &&
      challenge != null &&
      !challenge.isComplete;
}

/// Builds challenge state from saved journal entries — no notifications or fake proof.
abstract final class ThreeDayChallengeEngine {
  ThreeDayChallengeEngine._();

  static ThreeDayChallengeState? build({
    required List<JournalEntry> entries,
    DateTime? now,
  }) {
    if (!ThreeDayChallengeGates.isEarlyUser(entryCount: entries.length)) {
      return null;
    }
    if (_blocksForEvidenceQuality(entries)) return null;

    final eligible = ArchiveEvidenceGuard.eligibleEntries(
      entries,
      analyticsSource: 'three_day_challenge',
    );
    final distinctDays = _distinctRecordingDays(eligible);
    final entryCount = eligible.length;

    if (_isChallengeComplete(eligible, distinctDays)) {
      return ThreeDayChallengeState(
        day: ThreeDayChallengeDay.complete,
        title: ThreeDayChallengeCopy.title,
        body: ThreeDayChallengeCopy.completionBody,
        entryCount: entryCount,
        distinctDayCount: distinctDays,
        isComplete: true,
      );
    }

    if (entryCount == 0) {
      return const ThreeDayChallengeState(
        day: ThreeDayChallengeDay.day1,
        title: ThreeDayChallengeCopy.day1Title,
        body: ThreeDayChallengeCopy.day1Body,
        entryCount: 0,
        distinctDayCount: 0,
        isComplete: false,
      );
    }

    if (entryCount == 1 || distinctDays < 2) {
      return ThreeDayChallengeState(
        day: ThreeDayChallengeDay.day2,
        title: ThreeDayChallengeCopy.day2Title,
        body: ThreeDayChallengeCopy.day2Body,
        entryCount: entryCount,
        distinctDayCount: distinctDays,
        isComplete: false,
      );
    }

    return ThreeDayChallengeState(
      day: ThreeDayChallengeDay.day3,
      title: ThreeDayChallengeCopy.day3Title,
      body: ThreeDayChallengeCopy.day3Body,
      entryCount: entryCount,
      distinctDayCount: distinctDays,
      isComplete: false,
    );
  }

  static bool shouldHideForDegradedTranscript(List<JournalEntry> entries) {
    if (entries.isEmpty) return false;
    return VoiceCaptureQuality.isDegradedVoiceCapture(entries.last) ||
        ArchiveEvidenceQualityGate.showsPendingTranscriptFallback(entries) ||
        ArchiveEvidenceQualityGate.showsGenericTestEvidenceFallback(entries);
  }

  static bool _blocksForEvidenceQuality(List<JournalEntry> entries) {
    if (entries.isEmpty) return false;
    return shouldHideForDegradedTranscript(entries);
  }

  static bool _isChallengeComplete(
    List<JournalEntry> eligible,
    int distinctDays,
  ) {
    if (eligible.length >= 3) return true;
    if (eligible.length >= 2 &&
        distinctDays >= 2 &&
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(eligible)) {
      return true;
    }
    return false;
  }

  static int _distinctRecordingDays(List<JournalEntry> entries) {
    if (entries.isEmpty) return 0;
    final days = <String>{};
    for (final entry in entries) {
      final created = entry.createdAt;
      days.add('${created.year}-${created.month}-${created.day}');
    }
    return days.length;
  }
}