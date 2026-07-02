import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../repeat_return_check/pattern_changed_engine.dart';
import '../repeat_return_check/repeat_return_check_change_proof.dart';
import '../repeat_return_check/repeat_return_check_engine.dart';
import '../repeat_return_check/repeat_return_check_models.dart';
import '../repeat_return_check/repeat_return_check_trend.dart';
import '../timeline/timeline_entry_display.dart';
import 'confirmed_repeat_evidence_phrase_engine.dart';
import 'early_first_signal_engine.dart';
import 'helpful_action_appeared_engine.dart';
import 'helpful_action_appeared_model.dart';
import 'private_archive_report_copy.dart';
import 'private_archive_report_model.dart';

/// Builds a private evidence report from existing proof engines only.
abstract final class PrivateArchiveReportEngine {
  PrivateArchiveReportEngine._();

  static const _maxPhraseWords = 6;

  static PrivateArchiveReport? build({
    required List<JournalEntry> entries,
    bool triggerCapturedMilestone = false,
    bool helpfulActionCapturedMilestone = false,
    List<RepeatReturnCheckRecord> returnChecks = const [],
    bool viewingConfirmedRepeatOrTimeline = false,
    bool isRecording = false,
    bool isPostSave = false,
  }) {
    if (!viewingConfirmedRepeatOrTimeline) return null;
    if (!EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries)) return null;

    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.isEmpty) return null;

    final foundation = eligible.length >= 3
        ? eligible.sublist(0, 3)
        : eligible;
    final changeProof = RepeatReturnCheckEngine.changeProofForReady(
      entryCount: entries.length,
      viewingConfirmedRepeat: viewingConfirmedRepeatOrTimeline,
      isRecording: isRecording,
      isPostSave: isPostSave,
      records: returnChecks,
    );
    final latestChoice = RepeatReturnCheckTrendEngine.latestChoice(returnChecks);
    final patternChanged = PatternChangedEngine.build(
      changeProof: changeProof,
      records: returnChecks,
      entries: entries,
    );
    final helpfulAction = HelpfulActionAppearedEngine.build(
      entries: entries,
      returnChecks: returnChecks,
      helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
    );

    final repeatPhrase = _groundedPhrase(foundation);
    if (repeatPhrase == null) return null;

    final repeatCount = _countMomentsWithPhrase(eligible, repeatPhrase);
    final sections = [
      _whatRepeatedSection(repeatPhrase, repeatCount),
      _whatSoftenedSection(latestChoice, eligible, repeatPhrase),
      _whatGotLouderSection(latestChoice, eligible, repeatPhrase),
      _whatHelpedSection(helpfulAction, eligible),
      _whatChangedSection(patternChanged, eligible),
      _whatToRecordNextSection(),
    ];

    final report = PrivateArchiveReport(
      title: PrivateArchiveReportCopy.title,
      intro: PrivateArchiveReportCopy.intro,
      sections: sections,
    );

    if (!report.hasContent) return null;
    return report;
  }

  static PrivateArchiveReportSection _whatRepeatedSection(
    String phrase,
    int count,
  ) =>
      PrivateArchiveReportSection(
        heading: PrivateArchiveReportCopy.whatRepeatedHeading,
        lines: [
          PrivateArchiveReportCopy.whatRepeatedBody(phrase, count),
        ],
      );

  static PrivateArchiveReportSection _whatSoftenedSection(
    RepeatReturnCheckChoice? latestChoice,
    List<JournalEntry> eligible,
    String foundationPhrase,
  ) {
    if (latestChoice != RepeatReturnCheckChoice.softer) {
      return _fallbackSection(PrivateArchiveReportCopy.whatSoftenedHeading);
    }
    final phrase = _latestGroundedPhrase(eligible) ?? foundationPhrase;
    if (!_isGroundedPhrase(phrase, eligible)) {
      return _fallbackSection(PrivateArchiveReportCopy.whatSoftenedHeading);
    }
    return PrivateArchiveReportSection(
      heading: PrivateArchiveReportCopy.whatSoftenedHeading,
      lines: [PrivateArchiveReportCopy.whatSoftenedBody(phrase)],
    );
  }

  static PrivateArchiveReportSection _whatGotLouderSection(
    RepeatReturnCheckChoice? latestChoice,
    List<JournalEntry> eligible,
    String foundationPhrase,
  ) {
    if (latestChoice != RepeatReturnCheckChoice.stronger) {
      return _fallbackSection(PrivateArchiveReportCopy.whatGotLouderHeading);
    }
    final phrase = _latestGroundedPhrase(eligible) ?? foundationPhrase;
    if (!_isGroundedPhrase(phrase, eligible)) {
      return _fallbackSection(PrivateArchiveReportCopy.whatGotLouderHeading);
    }
    return PrivateArchiveReportSection(
      heading: PrivateArchiveReportCopy.whatGotLouderHeading,
      lines: [PrivateArchiveReportCopy.whatGotLouderBody(phrase)],
    );
  }

  static PrivateArchiveReportSection _whatHelpedSection(
    HelpfulActionAppeared? helpfulAction,
    List<JournalEntry> entries,
  ) {
    final phrase = helpfulAction?.actionPhrase;
    if (helpfulAction == null ||
        !helpfulAction.usesActionPhrase ||
        phrase == null ||
        !_isGroundedPhrase(phrase, entries)) {
      return _fallbackSection(PrivateArchiveReportCopy.whatHelpedHeading);
    }
    return PrivateArchiveReportSection(
      heading: PrivateArchiveReportCopy.whatHelpedHeading,
      lines: [PrivateArchiveReportCopy.whatHelpedBody(phrase)],
    );
  }

  static PrivateArchiveReportSection _whatChangedSection(
    PatternChangedResult? patternChanged,
    List<JournalEntry> entries,
  ) {
    final phrase = patternChanged?.thisTimePhrase;
    if (patternChanged == null ||
        !patternChanged.usesPhraseEvidence ||
        phrase == null ||
        !_isGroundedPhrase(phrase, entries)) {
      return _fallbackSection(PrivateArchiveReportCopy.whatChangedHeading);
    }
    return PrivateArchiveReportSection(
      heading: PrivateArchiveReportCopy.whatChangedHeading,
      lines: [PrivateArchiveReportCopy.whatChangedBody(phrase)],
    );
  }

  static PrivateArchiveReportSection _whatToRecordNextSection() =>
      const PrivateArchiveReportSection(
        heading: PrivateArchiveReportCopy.whatToRecordNextHeading,
        lines: [PrivateArchiveReportCopy.whatToRecordNextBody],
      );

  static PrivateArchiveReportSection _fallbackSection(String heading) =>
      PrivateArchiveReportSection(
        heading: heading,
        lines: const [PrivateArchiveReportCopy.missingEvidenceFallback],
      );

  static String? _groundedPhrase(List<JournalEntry> entries) {
    final shared =
        ConfirmedRepeatEvidencePhraseEngine.sharedConcretePhrase(entries);
    if (shared != null && _isGroundedPhrase(shared, entries)) return shared;

    for (final phrase
        in ConfirmedRepeatEvidencePhraseEngine.extract(entries).phrases) {
      if (_isGroundedPhrase(phrase, entries)) return phrase;
    }
    return null;
  }

  static String? _latestGroundedPhrase(List<JournalEntry> entries) {
    if (entries.isEmpty) return null;
    final phrase = ConfirmedRepeatEvidencePhraseEngine.singleEntryConcretePhrase(
      entries.last,
    );
    if (phrase == null || !_isGroundedPhrase(phrase, entries)) return null;
    return phrase;
  }

  static int _countMomentsWithPhrase(
    List<JournalEntry> entries,
    String phrase,
  ) {
    final normalized = phrase.toLowerCase().trim();
    if (normalized.isEmpty) return 0;
    return entries
        .where((entry) => _entryText(entry).toLowerCase().contains(normalized))
        .length;
  }

  static bool _isGroundedPhrase(String phrase, List<JournalEntry> entries) {
    if (!ConfirmedRepeatEvidencePhraseEngine.isConcretePhrase(phrase)) {
      return false;
    }
    if (ConfirmedRepeatEvidencePhraseEngine.isAbstractOnlyPhrase(phrase)) {
      return false;
    }
    if (entries.isNotEmpty &&
        ConfirmedRepeatEvidencePhraseEngine.usesUngroundedGenericLabel(
          label: phrase,
          entries: entries,
        )) {
      return false;
    }
    final words = phrase.trim().split(RegExp(r'\s+'));
    return words.isNotEmpty && words.length <= _maxPhraseWords;
  }

  static String _entryText(JournalEntry entry) {
    final resolution = resolveEntryDisplayText(entry);
    if (resolution.text.isNotEmpty) return resolution.text.trim();
    return entry.transcript.trim();
  }
}
