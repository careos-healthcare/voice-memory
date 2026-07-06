import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../archive_evidence/archive_evidence_quality_gate.dart';
import '../archive_evidence/comparable_evidence_text.dart';
import '../early_archive/archive_change_timeline_engine.dart';
import '../early_archive/confirmed_repeat_evidence_phrase_engine.dart';
import '../early_archive/early_first_signal_engine.dart';
import '../early_archive/helpful_action_appeared_engine.dart';
import '../early_archive/helpful_action_appeared_model.dart';
import '../pattern_naming/pattern_name_engine.dart';
import '../repeat_return_check/pattern_changed_engine.dart';
import '../repeat_return_check/repeat_return_check_engine.dart';
import '../repeat_return_check/repeat_return_check_models.dart';
import '../repeat_return_check/repeat_return_check_trend.dart';
import '../repeat_return_check/repeat_return_check_change_proof.dart';
import '../what_changed/what_changed_v2_model.dart';
import '../what_changed/what_changed_v2_store.dart';
import 'belief_change_moment_copy.dart';
import 'belief_change_moment_model.dart';

/// Builds belief change payoff from existing change engines only.
abstract final class BeliefChangeMomentEngine {
  BeliefChangeMomentEngine._();

  static const _maxSnippetChars = 72;
  static const _minSnippetChars = 12;

  static BeliefChangeMoment? build({
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
    RepeatReturnCheckChangeProof? changeProof,
    bool helpfulActionCapturedMilestone = false,
    bool viewingConfirmedRepeatOrTimeline = false,
    bool isRecording = false,
    bool isPostSave = false,
  }) {
    if (!viewingConfirmedRepeatOrTimeline) return null;
    if (!EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries)) {
      return null;
    }
    if (!ArchiveEvidenceQualityGate.allowsBeliefSurfaces(entries)) return null;
    if (ArchiveEvidenceQualityGate.showsGenericTestEvidenceFallback(entries)) {
      return null;
    }
    if (ArchiveEvidenceQualityGate.showsPendingTranscriptFallback(entries)) {
      return null;
    }

    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length < 4) return null;

    final foundation = eligible.sublist(0, 3);
    if (!EarlyFirstSignalEngine.hasConfirmedRepeatAcrossThree(foundation)) {
      return null;
    }

    final earlierPhrase = _foundationPhrase(foundation, eligible);
    if (earlierPhrase == null) return null;

    final resolvedChangeProof = changeProof ??
        RepeatReturnCheckEngine.changeProofForReady(
          entryCount: entries.length,
          viewingConfirmedRepeat: viewingConfirmedRepeatOrTimeline,
          isRecording: isRecording,
          isPostSave: isPostSave,
          records: returnChecks,
        );
    final latestChoice = RepeatReturnCheckTrendEngine.latestChoice(returnChecks);
    final whatChanged = _latestWhatChangedMarker(entries);
    final patternChanged = PatternChangedEngine.build(
      changeProof: resolvedChangeProof,
      records: returnChecks,
      entries: entries,
    );
    final helpfulAction = HelpfulActionAppearedEngine.build(
      entries: entries,
      returnChecks: returnChecks,
      helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
    );
    final changeNotice = EarlyFirstSignalEngine.buildChangeNotice(entries: entries);

    final changeType = _resolveChangeType(
      latestChoice: latestChoice,
      whatChanged: whatChanged,
      patternChanged: patternChanged,
      helpfulAction: helpfulAction,
      changeNotice: changeNotice,
      eligible: eligible,
    );
    if (changeType == null) return null;

    final laterPhrase = _laterChangePhrase(
      changeType: changeType,
      patternChanged: patternChanged,
      helpfulAction: helpfulAction,
      eligible: eligible,
      latestChoice: latestChoice,
    );
    if (laterPhrase == null || !_phrasesMeaningfullyDiffer(earlierPhrase, laterPhrase)) {
      return null;
    }

    final earlierSnippet = _snippetForEntry(foundation.first, earlierPhrase);
    final laterSnippet = _snippetForEntry(eligible.last, laterPhrase);
    if (earlierSnippet == null || laterSnippet == null) return null;

    final timeline = ArchiveChangeTimelineEngine.build(
      entries: entries,
      helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
      returnChecks: returnChecks,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
      isRecording: isRecording,
      isPostSave: isPostSave,
    );

    return BeliefChangeMoment(
      changeType: changeType,
      earlierBeliefExample:
          BeliefChangeMomentCopy.formatBeliefExample(earlierPhrase),
      changeExample: BeliefChangeMomentCopy.formatChangeExample(laterPhrase),
      earlierSnippet: BeliefChangeEvidenceSnippet(
        label: BeliefChangeMomentCopy.earlierLabel,
        quote: earlierSnippet,
      ),
      laterSnippet: BeliefChangeEvidenceSnippet(
        label: BeliefChangeMomentCopy.laterLabel,
        quote: laterSnippet,
      ),
      timeline: timeline,
    );
  }

  static BeliefChangeType? _resolveChangeType({
    required RepeatReturnCheckChoice? latestChoice,
    required WhatChangedV2Option? whatChanged,
    required PatternChangedResult? patternChanged,
    required HelpfulActionAppeared? helpfulAction,
    required ConfirmedRepeatChangeNotice? changeNotice,
    required List<JournalEntry> eligible,
  }) {
    if (latestChoice == RepeatReturnCheckChoice.stronger ||
        latestChoice == RepeatReturnCheckChoice.same ||
        whatChanged == WhatChangedV2Option.stronger ||
        whatChanged == WhatChangedV2Option.same) {
      return null;
    }

    if (latestChoice == RepeatReturnCheckChoice.changed ||
        whatChanged == WhatChangedV2Option.differentResponse ||
        (patternChanged != null &&
            latestChoice == RepeatReturnCheckChoice.changed)) {
      return BeliefChangeType.differentResponse;
    }

    if ((helpfulAction?.usesActionPhrase ?? false) &&
        helpfulAction!.actionPhrase != null) {
      return BeliefChangeType.helpfulAction;
    }
    if (whatChanged == WhatChangedV2Option.somethingHelped &&
        helpfulAction != null) {
      return BeliefChangeType.helpfulAction;
    }

    if (_isLowerUrgency(eligible, changeNotice)) {
      return BeliefChangeType.lowerUrgency;
    }

    if (latestChoice == RepeatReturnCheckChoice.softer ||
        whatChanged == WhatChangedV2Option.softer ||
        changeNotice != null ||
        (patternChanged != null &&
            latestChoice == RepeatReturnCheckChoice.softer)) {
      return BeliefChangeType.softened;
    }

    return null;
  }

  static bool _isLowerUrgency(
    List<JournalEntry> eligible,
    ConfirmedRepeatChangeNotice? changeNotice,
  ) {
    if (changeNotice != null) {
      final joined = changeNotice.evidenceLines.join(' ').toLowerCase();
      if (joined.contains('less urgent')) return true;
    }
    if (eligible.isEmpty) return false;
    final latestText = ComparableEvidenceText.userText(eligible.last).toLowerCase();
    return latestText.contains('less urgent');
  }

  static WhatChangedV2Option? _latestWhatChangedMarker(List<JournalEntry> entries) {
    final ids = entries.map((entry) => entry.id).toSet();
    final marker = WhatChangedV2Store.cached
        .where((record) => ids.contains(record.entryId))
        .firstOrNull;
    return marker?.option;
  }

  static String? _foundationPhrase(
    List<JournalEntry> foundation,
    List<JournalEntry> eligible,
  ) {
    final shared =
        ConfirmedRepeatEvidencePhraseEngine.sharedConcretePhrase(foundation);
    if (shared != null && _isGroundedPhrase(shared, eligible)) {
      return PatternNameEngine.displayLabelForGroundedPhrase(shared);
    }

    for (final phrase
        in ConfirmedRepeatEvidencePhraseEngine.extract(foundation).phrases) {
      if (_isGroundedPhrase(phrase, eligible)) {
        return PatternNameEngine.displayLabelForGroundedPhrase(phrase);
      }
    }
    return null;
  }

  static String? _laterChangePhrase({
    required BeliefChangeType changeType,
    required PatternChangedResult? patternChanged,
    required HelpfulActionAppeared? helpfulAction,
    required List<JournalEntry> eligible,
    required RepeatReturnCheckChoice? latestChoice,
  }) {
    if (changeType == BeliefChangeType.helpfulAction) {
      final phrase = helpfulAction?.actionPhrase;
      if (phrase != null && phrase.isNotEmpty) return phrase;
    }
    final changedPhrase = patternChanged?.thisTimePhrase;
    if (changedPhrase != null && changedPhrase.isNotEmpty) {
      return PatternNameEngine.displayLabelForGroundedPhrase(changedPhrase);
    }

    final latest = eligible.last;
    final concrete =
        ConfirmedRepeatEvidencePhraseEngine.singleEntryConcretePhrase(latest);
    if (concrete != null && _isGroundedPhrase(concrete, eligible)) {
      return PatternNameEngine.displayLabelForGroundedPhrase(concrete);
    }

    if (latestChoice == RepeatReturnCheckChoice.softer ||
        latestChoice == RepeatReturnCheckChoice.changed) {
      final text = ComparableEvidenceText.userText(latest);
      if (text.length >= _minSnippetChars) {
        return _trimSnippet(text);
      }
    }
    return null;
  }

  static String? _snippetForEntry(JournalEntry entry, String phrase) {
    final text = ComparableEvidenceText.userText(entry);
    if (text.length < _minSnippetChars) return null;

    final normalized = phrase.trim().toLowerCase();
    if (normalized.isNotEmpty) {
      final index = text.toLowerCase().indexOf(normalized);
      if (index >= 0) {
        final start = index > 24 ? index - 24 : 0;
        final end = (index + normalized.length + 32).clamp(0, text.length);
        final slice = text.substring(start, end).trim();
        if (slice.length >= _minSnippetChars) return _trimSnippet(slice);
      }
    }
    return _trimSnippet(text);
  }

  static bool _phrasesMeaningfullyDiffer(String earlier, String later) {
    return earlier.toLowerCase().trim() != later.toLowerCase().trim();
  }

  static bool _isGroundedPhrase(String phrase, List<JournalEntry> entries) {
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
    final words = phrase.trim().split(RegExp(r'\s+'));
    return words.isNotEmpty && words.length <= 6;
  }

  static String _trimSnippet(String snippet) {
    final cleaned = snippet.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length <= _maxSnippetChars) return cleaned;
    return '${cleaned.substring(0, _maxSnippetChars - 1).trim()}…';
  }
}
