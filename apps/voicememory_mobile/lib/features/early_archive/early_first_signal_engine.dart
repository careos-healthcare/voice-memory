import '../../models/journal_entry.dart';
import '../activation/first_three_journey_engine.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../retention/second_session_signal_engine.dart';
import '../timeline/timeline_entry_display.dart';
import 'early_first_signal_copy.dart';

enum EarlyFirstSignalKind {
  oneEntryReceipt,
  twoEntryNoPattern,
  twoEntryFirstSignal,
  threeEntryConfirmedRepeat,
}

/// One line of user-visible evidence on the confirmed-repeat card.
class EarlyFirstSignalEvidenceRow {
  const EarlyFirstSignalEvidenceRow({
    required this.timestampLabel,
    required this.snippet,
  });

  final String timestampLabel;
  final String snippet;
}

/// Lightweight next-observation prompt after a confirmed 3-entry repeat.
class EarlyFirstSignalReturnPrompt {
  const EarlyFirstSignalReturnPrompt({
    required this.title,
    required this.body,
    required this.cta,
    required this.guidedRecordPrompt,
  });

  final String title;
  final String body;
  final String cta;
  final String guidedRecordPrompt;
}

/// User-facing early archive card — deterministic, no invented patterns.
class EarlyFirstSignalModel {
  const EarlyFirstSignalModel({
    required this.kind,
    required this.title,
    required this.lines,
    required this.primaryCta,
    this.evidenceHeading,
    this.evidenceRows = const [],
    this.secondaryCta,
    this.returnPrompt,
  });

  final EarlyFirstSignalKind kind;
  final String title;
  final List<String> lines;
  final String primaryCta;
  final String? evidenceHeading;
  final List<EarlyFirstSignalEvidenceRow> evidenceRows;
  final String? secondaryCta;
  final EarlyFirstSignalReturnPrompt? returnPrompt;

  bool get showsPatternLanguage =>
      kind == EarlyFirstSignalKind.twoEntryFirstSignal ||
      kind == EarlyFirstSignalKind.threeEntryConfirmedRepeat;

  bool get showsConfirmedRepeat =>
      kind == EarlyFirstSignalKind.threeEntryConfirmedRepeat;
}

/// Post-save payoff after capturing the trigger from the return prompt.
class ConfirmedRepeatTriggerPayoff {
  const ConfirmedRepeatTriggerPayoff({
    required this.title,
    required this.body,
    required this.evidenceLines,
    required this.primaryCta,
    required this.secondaryCta,
  });

  final String title;
  final String body;
  final List<String> evidenceLines;
  final String primaryCta;
  final String secondaryCta;
}

abstract final class EarlyFirstSignalEngine {
  EarlyFirstSignalEngine._();

  static const _signalEngine = SecondSessionSignalEngine();
  static const _journeyEngine = FirstThreeJourneyEngine();
  static const _maxSnippetLength = 72;

  /// True when three eligible moments form a grounded repeat chain.
  static bool hasConfirmedRepeatAcrossThree(List<JournalEntry> entries) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length != 3) return false;
    return _signalEngine.hasGroundedRepeatMatch(eligible.sublist(0, 2)) &&
        _signalEngine.hasGroundedRepeatMatch(eligible.sublist(1, 3));
  }

  /// Returns a card model for 1–3 eligible entries when early proof applies.
  static EarlyFirstSignalModel? build({
    required List<JournalEntry> entries,
  }) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.isEmpty) return null;

    if (eligible.length == 1) {
      return const EarlyFirstSignalModel(
        kind: EarlyFirstSignalKind.oneEntryReceipt,
        title: EarlyFirstSignalCopy.oneEntryTitle,
        lines: [
          EarlyFirstSignalCopy.oneEntryBody,
          EarlyFirstSignalCopy.notEnoughEvidence,
        ],
        primaryCta: EarlyFirstSignalCopy.addMomentCta,
      );
    }

    if (eligible.length == 2) {
      if (_signalEngine.hasGroundedRepeatMatch(eligible)) {
        return const EarlyFirstSignalModel(
          kind: EarlyFirstSignalKind.twoEntryFirstSignal,
          title: EarlyFirstSignalCopy.twoEntryPatternStartTitle,
          lines: [
            EarlyFirstSignalCopy.twoEntryNoticedAgain,
            EarlyFirstSignalCopy.notEnoughEvidence,
            EarlyFirstSignalCopy.twoEntryConfirmRepeat,
          ],
          primaryCta: EarlyFirstSignalCopy.addMomentCta,
        );
      }

      return const EarlyFirstSignalModel(
        kind: EarlyFirstSignalKind.twoEntryNoPattern,
        title: EarlyFirstSignalCopy.twoEntryNoPatternTitle,
        lines: [EarlyFirstSignalCopy.twoEntryNoPatternBody],
        primaryCta: EarlyFirstSignalCopy.addMomentCta,
      );
    }

    if (eligible.length == 3 &&
        (_journeyEngine.hasRepeatMatch(entries: eligible) ||
            hasConfirmedRepeatAcrossThree(eligible))) {
      return EarlyFirstSignalModel(
        kind: EarlyFirstSignalKind.threeEntryConfirmedRepeat,
        title: EarlyFirstSignalCopy.threeEntryConfirmedTitle,
        lines: [
          EarlyFirstSignalCopy.threeEntrySeenThreeTimes,
          EarlyFirstSignalCopy.evidenceHeading,
        ],
        evidenceRows: _evidenceRows(eligible),
        primaryCta: EarlyFirstSignalCopy.recordWhatHappensNextCta,
        secondaryCta: EarlyFirstSignalCopy.viewEvidenceCta,
        returnPrompt: const EarlyFirstSignalReturnPrompt(
          title: EarlyFirstSignalCopy.returnPromptTitle,
          body: EarlyFirstSignalCopy.returnPromptBody,
          cta: EarlyFirstSignalCopy.recordTriggerNextTimeCta,
          guidedRecordPrompt: EarlyFirstSignalCopy.recordTriggerGuidedPrompt,
        ),
      );
    }

    return null;
  }

  /// Payoff after saving from the confirmed-repeat trigger guided prompt.
  static ConfirmedRepeatTriggerPayoff? buildTriggerCapturePayoff({
    required List<JournalEntry> entries,
    required bool savedFromTriggerPrompt,
  }) {
    if (!savedFromTriggerPrompt) return null;

    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length < 4) return null;

    final priorThree = eligible.sublist(0, 3);
    if (!hasConfirmedRepeatAcrossThree(priorThree)) return null;

    return const ConfirmedRepeatTriggerPayoff(
      title: EarlyFirstSignalCopy.triggerPayoffTitle,
      body: EarlyFirstSignalCopy.triggerPayoffBody,
      evidenceLines: [
        EarlyFirstSignalCopy.triggerPayoffRepeatEvidence,
        EarlyFirstSignalCopy.triggerPayoffTriggerEvidence,
      ],
      primaryCta: EarlyFirstSignalCopy.triggerPayoffPrimaryCta,
      secondaryCta: EarlyFirstSignalCopy.viewEvidenceCta,
    );
  }

  static List<EarlyFirstSignalEvidenceRow> _evidenceRows(
    List<JournalEntry> eligible,
  ) {
    final rows = <EarlyFirstSignalEvidenceRow>[];
    for (final entry in eligible) {
      final snippet = _snippet(_entryText(entry));
      if (snippet.isEmpty) continue;
      rows.add(
        EarlyFirstSignalEvidenceRow(
          timestampLabel: _timestampLabel(entry.createdAt),
          snippet: snippet,
        ),
      );
    }
    if (rows.length <= 3) return rows;
    return rows.sublist(rows.length - 3);
  }

  static String _entryText(JournalEntry entry) {
    final resolution = resolveEntryDisplayText(entry);
    if (resolution.text.isNotEmpty) return resolution.text.trim();
    return entry.transcript.trim();
  }

  static String _snippet(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.length <= _maxSnippetLength) return trimmed;
    return '${trimmed.substring(0, _maxSnippetLength - 1)}…';
  }

  static String _timestampLabel(DateTime createdAt) {
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
    return '${months[createdAt.month - 1]} ${createdAt.day}';
  }
}
