import 'package:archiveme_mobile/features/archive_evidence/archive_entry_signal_guard.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_pattern_copy_guard.dart';
import 'package:archiveme_mobile/features/archive_evidence/comparable_evidence_text.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_quality.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// How much real user evidence an entry provides for archive insights.
enum ArchiveEvidenceQualityLevel {
  /// No insight — placeholder, pending, empty, or degraded without correction.
  unusable,

  /// Saved moment only — show neutral fallback, no comparisons.
  weak,

  /// Enough concrete wording for early comparisons and signals.
  usable,

  /// Rich enough moment for proof, belief, and timeline surfaces.
  strong,
}

/// Stable reason ids for analytics — never user transcript text.
enum ArchiveEvidenceQualityReason {
  empty,
  placeholderOrPending,
  degradedVoice,
  systemCopy,
  tooShort,
  genericTestText,
  lowSignal,
  usableMoment,
  strongMoment,
}

/// Assessment of one journal entry for insight engines.
class ArchiveEvidenceQualityVerdict {
  const ArchiveEvidenceQualityVerdict({
    required this.level,
    required this.reason,
    this.textLength = 0,
  });

  final ArchiveEvidenceQualityLevel level;
  final ArchiveEvidenceQualityReason reason;
  final int textLength;

  bool get allowsInsights =>
      level == ArchiveEvidenceQualityLevel.usable ||
      level == ArchiveEvidenceQualityLevel.strong;

  bool get allowsProofSurfaces => level == ArchiveEvidenceQualityLevel.strong;

  bool get showsWeakFallbackOnly =>
      level == ArchiveEvidenceQualityLevel.weak ||
      level == ArchiveEvidenceQualityLevel.unusable;
}

/// Fallback copy when evidence is too weak for comparisons.
abstract final class ArchiveEvidenceQualityCopy {
  ArchiveEvidenceQualityCopy._();

  static const savedTitle = 'Your moment is saved.';
  static const needsClearerWordsBody =
      'ArchiveMe needs clearer words before it can compare this.';

  static const patternsStillFormingTitle = 'Patterns are still forming';
  static const patternsNeedClearerMomentsBody =
      'ArchiveMe needs clearer real moments before it can compare what repeats.';

  static const List<String> all = [
    savedTitle,
    needsClearerWordsBody,
    patternsStillFormingTitle,
    patternsNeedClearerMomentsBody,
  ];
}

/// Classifies saved moments for archive insight safety.
abstract final class ArchiveEvidenceQuality {
  ArchiveEvidenceQuality._();

  static const minUsableChars = 24;
  static const minStrongChars = 40;

  static const _genericTestPhrases = {
    'checking',
    'everything is working',
    'everything works',
    'mic test',
    'audio test',
    'sound check',
    'is this working',
    'testing testing',
  };

  static const _genericTestHarnessPhrases = {
    'this is a test',
    'this is another test',
    'this is a second test',
    'second test',
    'first test',
    'another test',
    'test to check',
    'test for',
    'check function',
    'checking function',
    'function test',
    'testing function',
    'test check',
    'just testing',
    'only testing',
    'quick test',
  };

  static const _genericTestHarnessTokens = {
    'test',
    'testing',
    'check',
    'checking',
    'function',
    'verify',
    'validation',
    'mic',
  };

  static const _momentWords = {
    'said',
    'felt',
    'pressure',
    'again',
    'today',
    'work',
    'help',
    'avoid',
    'tired',
    'anxious',
    'guilty',
    'agreed',
    'disappoint',
    'capacity',
    'conversation',
    'meeting',
    'family',
    'partner',
  };

  /// Classifies [entry] evidence for insight gating.
  static ArchiveEvidenceQualityVerdict assess(JournalEntry entry) {
    if (VoiceCaptureQuality.isDegradedVoiceCapture(entry)) {
      return const ArchiveEvidenceQualityVerdict(
        level: ArchiveEvidenceQualityLevel.unusable,
        reason: ArchiveEvidenceQualityReason.degradedVoice,
      );
    }

    if (ComparableEvidenceText.entryHasPendingTranscript(entry)) {
      return const ArchiveEvidenceQualityVerdict(
        level: ArchiveEvidenceQualityLevel.unusable,
        reason: ArchiveEvidenceQualityReason.placeholderOrPending,
      );
    }

    final text = ComparableEvidenceText.userText(entry);
    final length = text.length;

    if (text.isEmpty) {
      return const ArchiveEvidenceQualityVerdict(
        level: ArchiveEvidenceQualityLevel.unusable,
        reason: ArchiveEvidenceQualityReason.empty,
      );
    }

    if (ArchivePatternCopyGuard.isBlockedPatternText(text)) {
      return ArchiveEvidenceQualityVerdict(
        level: ArchiveEvidenceQualityLevel.unusable,
        reason: ArchiveEvidenceQualityReason.systemCopy,
        textLength: length,
      );
    }

    if (_isGenericTestText(text)) {
      return ArchiveEvidenceQualityVerdict(
        level: ArchiveEvidenceQualityLevel.weak,
        reason: ArchiveEvidenceQualityReason.genericTestText,
        textLength: length,
      );
    }

    if (length < ArchiveEntrySignalGuard.minMeaningfulCharacters) {
      return ArchiveEvidenceQualityVerdict(
        level: ArchiveEvidenceQualityLevel.weak,
        reason: ArchiveEvidenceQualityReason.tooShort,
        textLength: length,
      );
    }

    if (ArchiveEntrySignalGuard.isLowSignalText(text)) {
      return ArchiveEvidenceQualityVerdict(
        level: ArchiveEvidenceQualityLevel.weak,
        reason: ArchiveEvidenceQualityReason.lowSignal,
        textLength: length,
      );
    }

    if (length < minUsableChars) {
      return ArchiveEvidenceQualityVerdict(
        level: ArchiveEvidenceQualityLevel.weak,
        reason: ArchiveEvidenceQualityReason.tooShort,
        textLength: length,
      );
    }

    if (_isStrongMoment(text)) {
      return ArchiveEvidenceQualityVerdict(
        level: ArchiveEvidenceQualityLevel.strong,
        reason: ArchiveEvidenceQualityReason.strongMoment,
        textLength: length,
      );
    }

    return ArchiveEvidenceQualityVerdict(
      level: ArchiveEvidenceQualityLevel.usable,
      reason: ArchiveEvidenceQualityReason.usableMoment,
      textLength: length,
    );
  }

  /// True when [text] looks like a mic/check/function test — not a real moment.
  static bool isGenericTestText(String text) => _isGenericTestText(text);

  static bool entryIsGenericTest(JournalEntry entry) {
    final text = ComparableEvidenceText.userText(entry);
    if (text.isEmpty) return false;
    return isGenericTestText(text);
  }

  static bool _isGenericTestText(String text) {
    final normalized = text
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
    if (normalized.isEmpty) return true;

    for (final phrase in _genericTestPhrases) {
      if (normalized == phrase) return true;
      if (phrase.contains(' ') && normalized.contains(phrase)) return true;
    }

    for (final phrase in _genericTestHarnessPhrases) {
      if (normalized.contains(phrase)) return true;
    }

    final stripped = normalized.replaceAll(RegExp(r'[^\w\s]'), '').trim();
    final wordList = stripped
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    if (RegExp(r'\btests?\b').hasMatch(normalized)) {
      final harnessHits = wordList
          .where((w) => _genericTestHarnessTokens.contains(w))
          .length;
      if (harnessHits >= 2) return true;
      if (wordList.contains('test') && wordList.length <= 8) return true;
    }

    if (wordList.length <= 2 &&
        wordList.every(
          (w) =>
              const {'test', 'testing', 'hello', 'checking', 'mic'}.contains(w),
        )) {
      return true;
    }

    if (wordList.length == 1 &&
        const {
          'test',
          'testing',
          'hello',
          'checking',
          'mic',
        }.contains(wordList.single)) {
      return true;
    }

    return false;
  }

  static bool _isStrongMoment(String text) {
    if (text.length < minStrongChars) return false;

    final normalized = text.toLowerCase();
    final words = normalized
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 3)
        .toList();

    if (words.length < 4) return false;

    final momentHits = words.where((w) => _momentWords.contains(w)).length;
    return momentHits >= 1 || text.length >= 56;
  }
}