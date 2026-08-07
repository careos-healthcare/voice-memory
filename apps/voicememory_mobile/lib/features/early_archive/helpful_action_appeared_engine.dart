import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../archive_evidence/archive_repeat_phrase_sanitizer.dart';
import '../repeat_return_check/repeat_return_check_models.dart';
import '../repeat_return_check/repeat_return_check_trend.dart';
import '../timeline/timeline_entry_display.dart';
import 'confirmed_repeat_evidence_phrase_engine.dart';
import 'early_first_signal_engine.dart';
import 'helpful_action_appeared_copy.dart';
import 'helpful_action_appeared_model.dart';

/// Detects a grounded helpful action from later entries after first proof.
abstract final class HelpfulActionAppearedEngine {
  HelpfulActionAppearedEngine._();

  static const minEntryCount = 4;
  static const foundationEntryCount = 3;
  static const maxPhraseWords = 6;

  static const _bannedGenericFeelings = {
    'happy',
    'grateful',
    'gratitude',
    'positive',
    'better day',
    'good day',
    'great day',
    'feeling good',
    'feel good',
    'feeling better',
    'feel better',
    'amazing',
    'awesome',
    'blessed',
  };

  static final _bannedAbstractLabels = {
    ...ConfirmedRepeatEvidencePhraseEngine.bannedGenericLabels,
    'growth',
    'resilience',
  };

  /// Action-oriented cues — must appear in user text, never invented.
  static const _helpfulCuePhrases = [
    'paused before replying',
    'paused before',
    'waited before checking',
    'waited before',
    'walked outside',
    'went for a walk',
    'walk outside',
    'went outside',
    'asked for time',
    'asked for help',
    'left the message',
    'didn\'t check again',
    'did not check again',
    'closed the app',
    'slept on it',
    'took a breath',
    'took a break',
    'took a pause',
    'chose to wait',
    'decided to wait',
    'reached out',
    'called someone',
    'called a friend',
    'wrote it down',
    'started early',
    'started earlier',
  ];

  static HelpfulActionAppeared? build({
    required List<JournalEntry> entries,
    required List<RepeatReturnCheckRecord> returnChecks,
    bool helpfulActionCapturedMilestone = false,
  }) {
    if (!EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries))
      return null;

    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length < minEntryCount) return null;

    final improvementSignal =
        _hasImprovementSignal(returnChecks) || helpfulActionCapturedMilestone;
    final laterEntries = eligible.length > foundationEntryCount
        ? eligible.sublist(foundationEntryCount)
        : <JournalEntry>[eligible.last];

    final actionPhrase = _extractBestActionPhrase(
      laterEntries: laterEntries,
      entries: eligible,
      preferImprovementContext: improvementSignal,
    );

    if (actionPhrase != null) {
      return _result(
        body: HelpfulActionAppearedCopy.bodyWithPhrase(actionPhrase),
        usesActionPhrase: true,
        actionPhrase: actionPhrase,
      );
    }

    if (improvementSignal) {
      return _result(
        body: HelpfulActionAppearedCopy.bodyFallback,
        usesActionPhrase: false,
      );
    }

    return null;
  }

  static HelpfulActionAppeared _result({
    required String body,
    required bool usesActionPhrase,
    String? actionPhrase,
  }) => HelpfulActionAppeared(
    title: HelpfulActionAppearedCopy.title,
    body: body,
    evidenceLabel: HelpfulActionAppearedCopy.evidenceLabel,
    footer: HelpfulActionAppearedCopy.footer,
    chipLabel: HelpfulActionAppearedCopy.chipLabel,
    usesActionPhrase: usesActionPhrase,
    hasConfirmedRepeat: true,
    actionPhrase: actionPhrase,
  );

  static bool _hasImprovementSignal(List<RepeatReturnCheckRecord> records) {
    final latest = RepeatReturnCheckTrendEngine.latestChoice(records);
    return latest == RepeatReturnCheckChoice.softer ||
        latest == RepeatReturnCheckChoice.changed;
  }

  static String? _extractBestActionPhrase({
    required List<JournalEntry> laterEntries,
    required List<JournalEntry> entries,
    required bool preferImprovementContext,
  }) {
    final repeatPhraseSet = ConfirmedRepeatEvidencePhraseEngine.extract(entries)
        .phrases
        .map(ArchiveRepeatPhraseSanitizer.sanitize)
        .where((phrase) => phrase.isNotEmpty)
        .toSet();

    String? bestPhrase;
    var bestScore = -1;

    for (final entry in laterEntries) {
      final text = _entryText(entry);
      if (text.isEmpty) continue;
      final lower = text.toLowerCase();
      if (_containsOnlyGenericFeeling(lower)) continue;

      for (final cue in _helpfulCuePhrases) {
        if (!lower.contains(cue)) continue;
        final display = _displayFromText(text, cue);
        if (display == null || !_isGroundedAction(display, entries)) continue;
        if (_overlapsRepeatEvidence(display, repeatPhraseSet)) continue;

        var score = _phraseScore(display);
        if (preferImprovementContext) score += 2;
        if (score > bestScore) {
          bestScore = score;
          bestPhrase = display;
        }
      }
    }

    return bestPhrase;
  }

  static bool _containsOnlyGenericFeeling(String lower) {
    final hasFeeling = _bannedGenericFeelings.any(lower.contains);
    if (!hasFeeling) return false;
    return !_helpfulCuePhrases.any(lower.contains);
  }

  static bool _isGroundedAction(String phrase, List<JournalEntry> entries) {
    if (!ConfirmedRepeatEvidencePhraseEngine.isConcretePhrase(phrase)) {
      return false;
    }
    if (ConfirmedRepeatEvidencePhraseEngine.isAbstractOnlyPhrase(phrase)) {
      return false;
    }
    if (ConfirmedRepeatEvidencePhraseEngine.usesUngroundedGenericLabel(
      label: phrase,
      entries: entries,
    )) {
      return false;
    }
    final normalized = phrase.toLowerCase().trim();
    for (final label in _bannedAbstractLabels) {
      if (normalized == label) return false;
    }
    return _phraseWithinLimit(phrase);
  }

  static bool _phraseWithinLimit(String phrase) {
    final words = phrase.trim().split(RegExp(r'\s+'));
    return words.isNotEmpty && words.length <= maxPhraseWords;
  }

  static bool _overlapsRepeatEvidence(
    String phrase,
    Set<String> repeatPhraseSet,
  ) {
    final normalized = ArchiveRepeatPhraseSanitizer.sanitize(phrase);
    if (normalized.isEmpty) return false;
    for (final repeat in repeatPhraseSet) {
      if (repeat.isEmpty) continue;
      if (normalized == repeat) return true;
    }
    return false;
  }

  static int _phraseScore(String phrase) {
    final words = phrase.trim().split(RegExp(r'\s+'));
    if (words.length >= 2 && words.length <= maxPhraseWords) return 3;
    if (words.length == 1) return 1;
    return 0;
  }

  static String? _displayFromText(String text, String cueLower) {
    final normalized = ArchiveRepeatPhraseSanitizer.sanitize(cueLower);
    if (normalized.isEmpty) return null;

    final index = text.toLowerCase().indexOf(normalized);
    if (index < 0) return null;
    final end = index + normalized.length;
    if (end > text.length) return null;
    final slice = text.substring(index, end).trim();
    return slice.isEmpty ? null : slice;
  }

  static String _entryText(JournalEntry entry) {
    final resolution = resolveEntryDisplayText(entry);
    if (resolution.text.isNotEmpty) return resolution.text.trim();
    return entry.transcript.trim();
  }
}
