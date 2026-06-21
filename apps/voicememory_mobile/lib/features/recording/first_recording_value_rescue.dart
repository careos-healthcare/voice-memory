import 'package:flutter/foundation.dart';

import '../../models/journal_entry.dart';
import '../archive_reactivity/archive_display_copy_guard.dart';
import '../archive_reactivity/instant_loop_map_preview.dart';
import '../timeline/timeline_entry_display.dart';
import '../voice_capture/voice_capture_quality.dart';

enum FirstRecordingValueRescueReason {
  noSpeech,
  missingTranscript,
  lowQualityTranscript,
  analysisUnavailable,
  displayTextMissing,
}

enum FirstRecordingValueRescueVariant {
  voiceFailed,
  analysisUnavailableWithTranscript,
}

class FirstRecordingValueRescueState {
  const FirstRecordingValueRescueState({
    required this.shouldRescue,
    this.reason,
    this.variant = FirstRecordingValueRescueVariant.voiceFailed,
    this.title = '',
    this.body = '',
    this.suggestedPrompt = '',
    this.ctaLabel = '',
    this.secondaryLabel = '',
  });

  final bool shouldRescue;
  final FirstRecordingValueRescueReason? reason;
  final FirstRecordingValueRescueVariant variant;
  final String title;
  final String body;
  final String suggestedPrompt;
  final String ctaLabel;
  final String secondaryLabel;

  static const noRescue = FirstRecordingValueRescueState(shouldRescue: false);

  static const typedPlaceholder =
      'What were you checking, proving, avoiding, or trying to get right?';
}

abstract class FirstRecordingValueRescueCopy {
  FirstRecordingValueRescueCopy._();

  static const voiceFailedTitle = "Let's still map this";
  static const voiceFailedBody =
      'ArchiveMe did not catch enough words to sketch the loop. Type the moment in your own words and it can build the early map from that.';
  static const voiceFailedCta = 'Type what I said';
  static const voiceFailedSecondary = 'Record again';

  static const analysisSavedTitle = 'Your recording was saved';
  static const analysisSavedBody =
      'ArchiveMe heard the moment. The deeper analysis is temporarily unavailable, but it can still sketch the early loop from your words.';
  static const analysisSavedCta = 'Show early map';
  static const analysisSavedSecondary = 'Record again';
}

abstract class FirstRecordingValueRescueLog {
  FirstRecordingValueRescueLog._();

  static void shown(FirstRecordingValueRescueReason reason) {
    debugPrint(
      'ARCHIVEME_FIRST_VALUE_RESCUE_SHOWN reason=${reason.name}',
    );
  }

  static void ctaTapped(String action) {
    debugPrint(
      'ARCHIVEME_FIRST_VALUE_RESCUE_CTA_TAPPED action=$action',
    );
  }

  static void typedSaved(int length) {
    debugPrint(
      'ARCHIVEME_FIRST_VALUE_RESCUE_TYPED_SAVED length=$length',
    );
  }

  static void previewBuilt(InstantLoopMapPreviewState state) {
    debugPrint(
      'ARCHIVEME_FIRST_VALUE_RESCUE_PREVIEW_BUILT state=${state.logId}',
    );
  }

  static void skipped(String reason) {
    debugPrint(
      'ARCHIVEME_FIRST_VALUE_RESCUE_SKIPPED reason=$reason',
    );
  }
}

abstract class FirstRecordingValueRescueResolver {
  FirstRecordingValueRescueResolver._();

  static FirstRecordingValueRescueState resolve({
    required int entryCount,
    required bool hasTranscript,
    required int transcriptLength,
    required bool hasDisplayText,
    required String? transcriptionErrorCode,
    required String? analysisErrorCode,
    required bool isOnboardingActive,
    bool userTypedInstead = false,
    bool hasPersonalPreview = false,
    bool quiet = false,
  }) {
    if (FirstRecordingValueRescueGate.shouldSuppress()) {
      if (!quiet) {
        FirstRecordingValueRescueLog.skipped('explicit_scripted_suppression');
      }
      return FirstRecordingValueRescueState.noRescue;
    }

    if (entryCount > 1) {
      if (!quiet) {
        FirstRecordingValueRescueLog.skipped('not_first_entry');
      }
      return FirstRecordingValueRescueState.noRescue;
    }

    if (userTypedInstead) {
      if (!quiet) {
        FirstRecordingValueRescueLog.skipped('user_typed');
      }
      return FirstRecordingValueRescueState.noRescue;
    }

    if (_isAnalysisUnavailable(analysisErrorCode) && hasDisplayText) {
      return _analysisUnavailableRescue(
        isOnboardingActive: isOnboardingActive,
        logShown: !quiet,
      );
    }

    if (hasPersonalPreview) {
      if (!quiet) {
        FirstRecordingValueRescueLog.skipped('usable_transcript');
      }
      return FirstRecordingValueRescueState.noRescue;
    }

    if (hasTranscript && hasDisplayText) {
      if (!quiet) {
        FirstRecordingValueRescueLog.skipped('usable_transcript');
      }
      return FirstRecordingValueRescueState.noRescue;
    }

    final reason = _voiceFailureReason(
      hasTranscript: hasTranscript,
      hasDisplayText: hasDisplayText,
      transcriptLength: transcriptLength,
      transcriptionErrorCode: transcriptionErrorCode,
    );
    if (reason == null) {
      if (!quiet) {
        FirstRecordingValueRescueLog.skipped('usable_transcript');
      }
      return FirstRecordingValueRescueState.noRescue;
    }

    return _voiceFailedRescue(reason: reason, logShown: !quiet);
  }

  static FirstRecordingValueRescueState resolveForEntry({
    required List<JournalEntry> entries,
    required JournalEntry latestEntry,
    required bool analysisSucceeded,
    required bool lowQualityTranscript,
    required bool userTypedInstead,
    required bool isOnboardingActive,
    String? transcriptionErrorCode,
    String? analysisErrorCode,
    bool quiet = false,
  }) {
    final voiceNeedsRescue = VoiceCaptureQuality.isVoiceEntry(latestEntry) &&
        (isDraftOrSystemTranscriptPlaceholder(
              entrySanitizedTranscript(latestEntry),
            ) ||
            !VoiceCaptureQuality.hasUsableSpokenText(latestEntry));
    final degradedVoice = voiceNeedsRescue;
    final hasDisplayText = degradedVoice
        ? false
        : VoiceCaptureQuality.displayTextLength(latestEntry) > 0;
    final hasTranscript = degradedVoice
        ? false
        : VoiceCaptureQuality.hasUsableSpokenText(latestEntry);
    final preview = InstantLoopMapPreviewResolver.resolve(
      entries: entries,
      latestEntry: latestEntry,
    );
    final hasPersonalPreview = !voiceNeedsRescue &&
        InstantLoopMapPreviewResolver.isPersonalFirstValuePreview(preview) &&
        VoiceCaptureQuality.hasUsableSpokenText(latestEntry);

    return resolve(
      entryCount: entries.length,
      hasTranscript: hasTranscript,
      transcriptLength: latestEntry.transcript.trim().length,
      hasDisplayText: hasDisplayText,
      transcriptionErrorCode: transcriptionErrorCode ??
          _inferTranscriptionErrorCode(
            entry: latestEntry,
            lowQualityTranscript: lowQualityTranscript,
          ),
      analysisErrorCode: analysisErrorCode ??
          (!analysisSucceeded && hasTranscript
              ? 'ANALYZE_UNAVAILABLE'
              : null),
      isOnboardingActive: isOnboardingActive,
      userTypedInstead: userTypedInstead,
      hasPersonalPreview: hasPersonalPreview,
      quiet: quiet,
    );
  }

  static String? _inferTranscriptionErrorCode({
    required JournalEntry entry,
    required bool lowQualityTranscript,
  }) {
    if (!VoiceCaptureQuality.isVoiceEntry(entry)) return null;
    if (isDraftOrSystemTranscriptPlaceholder(
      entrySanitizedTranscript(entry),
    )) {
      return 'MISSING_TRANSCRIPT';
    }
    if (VoiceCaptureQuality.hasUsableSpokenText(entry)) return null;
    if (lowQualityTranscript) return 'LOW_QUALITY';
    final transcript = entry.transcript.trim();
    if (transcript.isEmpty || isDraftOrSystemTranscriptPlaceholder(transcript)) {
      return 'MISSING_TRANSCRIPT';
    }
    if (_codeContains(transcript, 'no_speech') ||
        _codeContains(transcript, 'NO_SPEECH')) {
      return 'NO_SPEECH';
    }
    return 'NO_SPEECH';
  }

  static FirstRecordingValueRescueReason? _voiceFailureReason({
    required bool hasTranscript,
    required bool hasDisplayText,
    required int transcriptLength,
    required String? transcriptionErrorCode,
  }) {
    if (!hasTranscript) {
      if (_codeContains(transcriptionErrorCode, 'NO_SPEECH')) {
        return FirstRecordingValueRescueReason.noSpeech;
      }
      if (_codeContains(transcriptionErrorCode, 'LOW_QUALITY')) {
        return FirstRecordingValueRescueReason.lowQualityTranscript;
      }
      if (_codeContains(transcriptionErrorCode, 'MISSING_TRANSCRIPT') ||
          transcriptLength == 0) {
        return FirstRecordingValueRescueReason.missingTranscript;
      }
      return FirstRecordingValueRescueReason.displayTextMissing;
    }
    if (!hasDisplayText) {
      return FirstRecordingValueRescueReason.displayTextMissing;
    }
    return null;
  }

  static bool _isAnalysisUnavailable(String? code) =>
      _codeContains(code, 'ANALYZE_UNAVAILABLE');

  static bool _codeContains(String? code, String token) =>
      code?.toUpperCase().contains(token.toUpperCase()) == true;

  static FirstRecordingValueRescueState _voiceFailedRescue({
    required FirstRecordingValueRescueReason reason,
    bool logShown = true,
  }) {
    if (logShown) {
      FirstRecordingValueRescueLog.shown(reason);
    }
    return FirstRecordingValueRescueState(
      shouldRescue: true,
      reason: reason,
      variant: FirstRecordingValueRescueVariant.voiceFailed,
      title: _guard(FirstRecordingValueRescueCopy.voiceFailedTitle),
      body: _guard(
        FirstRecordingValueRescueCopy.voiceFailedBody,
        requireSpecificity: false,
      ),
      suggestedPrompt: _guard(
        FirstRecordingValueRescueState.typedPlaceholder,
        requireSpecificity: false,
      ),
      ctaLabel: _guard(FirstRecordingValueRescueCopy.voiceFailedCta),
      secondaryLabel: _guard(FirstRecordingValueRescueCopy.voiceFailedSecondary),
    );
  }

  static FirstRecordingValueRescueState _analysisUnavailableRescue({
    required bool isOnboardingActive,
    bool logShown = true,
  }) {
    if (logShown) {
      FirstRecordingValueRescueLog.shown(
        FirstRecordingValueRescueReason.analysisUnavailable,
      );
    }
    return FirstRecordingValueRescueState(
      shouldRescue: true,
      reason: FirstRecordingValueRescueReason.analysisUnavailable,
      variant: FirstRecordingValueRescueVariant.analysisUnavailableWithTranscript,
      title: _guard(FirstRecordingValueRescueCopy.analysisSavedTitle),
      body: _guard(
        FirstRecordingValueRescueCopy.analysisSavedBody,
        requireSpecificity: false,
      ),
      suggestedPrompt: '',
      ctaLabel: _guard(FirstRecordingValueRescueCopy.analysisSavedCta),
      secondaryLabel: _guard(FirstRecordingValueRescueCopy.analysisSavedSecondary),
    );
  }

  static String _guard(
    String raw, {
    bool requireSpecificity = true,
  }) {
    final approved = ArchiveDisplayCopyGuard.validateAndNormalize(
      field: 'hero',
      text: raw,
      allowShortLabel: true,
      requireSpecificity: requireSpecificity,
      allowGenericFallback: true,
    );
    return approved.isNotEmpty ? approved : raw.trim();
  }
}

abstract class FirstRecordingValueRescueGate {
  FirstRecordingValueRescueGate._();

  @visibleForTesting
  static bool? releaseSmokeOverride;

  @visibleForTesting
  static bool? suppressScriptedE2EOverride;

  static const _releaseSmokeFromEnvironment = bool.fromEnvironment(
    'ARCHIVEME_RELEASE_SMOKE',
    defaultValue: false,
  );

  static const _suppressScriptedE2EFromEnvironment = bool.fromEnvironment(
    'ARCHIVEME_SUPPRESS_FIRST_VALUE_RESCUE_FOR_SCRIPTED_E2E',
    defaultValue: false,
  );

  static bool get isReleaseSmoke =>
      releaseSmokeOverride ?? _releaseSmokeFromEnvironment;

  static bool get suppressForScriptedE2E =>
      suppressScriptedE2EOverride ?? _suppressScriptedE2EFromEnvironment;

  /// Release smoke and normal app runs keep rescue enabled. Only activation
  /// scripted E2E may suppress when explicitly flagged.
  static bool shouldSuppress() {
    if (isReleaseSmoke) return false;
    return suppressForScriptedE2E;
  }

  @visibleForTesting
  static void resetForTest() {
    releaseSmokeOverride = null;
    suppressScriptedE2EOverride = null;
  }
}
