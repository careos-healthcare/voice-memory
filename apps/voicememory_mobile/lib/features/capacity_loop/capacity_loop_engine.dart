import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../beta_feedback/beta_feedback_engine.dart';
import '../demo/sample_archive_mode.dart';
import '../loop_mode/loop_mode_engine.dart';
import '../loop_mode/loop_mode_model.dart';
import 'capacity_loop_copy.dart';
import 'capacity_loop_gates.dart';
import 'capacity_loop_models.dart';

/// Builds the capacity yes loop card from local counts and safe theme signals.
class CapacityLoopEngine {
  const CapacityLoopEngine();

  static const _costKeywords = [
    'pressure',
    'stress',
    'tired',
    'exhaust',
    'behind',
    'overwhelm',
    'drained',
  ];

  static const _yesKeywords = [
    'yes',
    'agree',
    'agreed',
    'commit',
    'take on',
    'help',
    'capacity',
    'stretch',
    'full',
  ];

  CapacityLoopResult build(CapacityLoopInput input) {
    if (input.sampleMode) {
      return _screenshotPreview();
    }

    final gateInput = CapacityLoopGateInput(
      realSavedMomentCount: input.realSavedMomentCount,
      capacityEvidenceCount: input.capacityEvidenceCount,
      capacityWedgeActive: input.capacityWedgeActive,
      sampleMode: false,
    );

    if (!CapacityLoopGates.shouldBuildCard(gateInput)) {
      return CapacityLoopResult.empty;
    }

    final isFull =
        input.realSavedMomentCount >= CapacityLoopGates.minRealMomentsForFullCard;
    final count = input.realSavedMomentCount;

    if (!isFull) {
      return _formingCard(input, count);
    }

    return CapacityLoopResult(
      hasCard: true,
      isEmpty: false,
      showOnArchiveHome: CapacityLoopGates.showOnArchiveHome(
        hasCard: true,
        sampleMode: false,
      ),
      title: CapacityLoopCopy.title,
      subtitle: CapacityLoopCopy.subtitle,
      evidenceCountLabel: CapacityLoopCopy.evidenceCountLabel(count),
      whatRepeated: _whatRepeated(input),
      costLater: _costLater(input),
      watchNext: CapacityLoopCopy.watchNext,
      primaryCtaLabel: CapacityLoopCopy.saveYesMomentCta,
      secondaryCtaLabel: CapacityLoopCopy.reviewLoopCta,
      primaryRoute: CapacityLoopCopy.recordRoute,
      secondaryRoute: CapacityLoopCopy.route,
      shareCopy: CapacityLoopCopy.shareCopy,
      triggerLabel: CapacityLoopCopy.loopDiagramTrigger,
      saidYesLabel: CapacityLoopCopy.loopDiagramSaidYes,
      costLaterLabel: CapacityLoopCopy.loopDiagramCostLater,
      repeatedLabel: CapacityLoopCopy.loopDiagramRepeated,
      watchNextLabel: CapacityLoopCopy.loopDiagramWatchNext,
    );
  }

  CapacityLoopResult buildFromJournal({
    required List<JournalEntry> entries,
    required bool capacityLoopActive,
    required bool capacityCohortActive,
    bool sampleMode = false,
  }) {
    final realEntries = SampleArchiveMode.excludeSampleEntries(entries);
    final realCount = BetaFeedbackEngine.realEntryCountFor(realEntries);
    final eligible = ArchiveEvidenceGuard.eligibleEntries(realEntries);
    final capacityCount = _countCapacityEvidence(eligible);
    final theme = _topRecurringTheme(eligible);
    final costCount = _countCostSignals(eligible);

    return build(
      CapacityLoopInput(
        realSavedMomentCount: realCount,
        capacityEvidenceCount: capacityCount,
        capacityLoopActive: capacityLoopActive,
        capacityCohortActive: capacityCohortActive,
        sampleMode: sampleMode,
        topRecurringTheme: theme,
        costSignalCount: costCount,
        triggerSignalCount: capacityCount,
      ),
    );
  }

  int realSavedMomentCount(List<JournalEntry> entries) =>
      BetaFeedbackEngine.realEntryCountFor(
        SampleArchiveMode.excludeSampleEntries(entries),
      );

  int countCapacityEvidence(List<JournalEntry> entries) {
    final realEntries = SampleArchiveMode.excludeSampleEntries(entries);
    return _countCapacityEvidence(
      ArchiveEvidenceGuard.eligibleEntries(realEntries),
    );
  }

  static CapacityLoopResult _formingCard(CapacityLoopInput input, int count) {
    return CapacityLoopResult(
      hasCard: true,
      isEmpty: true,
      showOnArchiveHome: CapacityLoopGates.showOnArchiveHome(
        hasCard: true,
        sampleMode: false,
      ),
      title: CapacityLoopCopy.title,
      subtitle: CapacityLoopCopy.subtitle,
      evidenceCountLabel: CapacityLoopCopy.evidenceCountLabel(count),
      whatRepeated: CapacityLoopCopy.formingWhatRepeated,
      costLater: CapacityLoopCopy.formingCostLater,
      watchNext: CapacityLoopCopy.emptyStateBody,
      primaryCtaLabel: CapacityLoopCopy.saveYesMomentCta,
      secondaryCtaLabel: CapacityLoopCopy.reviewLoopCta,
      primaryRoute: CapacityLoopCopy.recordRoute,
      secondaryRoute: CapacityLoopCopy.route,
      shareCopy: CapacityLoopCopy.shareCopy,
      triggerLabel: CapacityLoopCopy.loopDiagramTrigger,
      saidYesLabel: CapacityLoopCopy.loopDiagramSaidYes,
      costLaterLabel: CapacityLoopCopy.loopDiagramCostLater,
      repeatedLabel: CapacityLoopCopy.loopDiagramRepeated,
      watchNextLabel: CapacityLoopCopy.loopDiagramWatchNext,
    );
  }

  static CapacityLoopResult _screenshotPreview() => const CapacityLoopResult(
        hasCard: false,
        isEmpty: false,
        showOnArchiveHome: false,
        title: CapacityLoopCopy.screenshotTitle,
        subtitle: CapacityLoopCopy.screenshotSubtitle,
        evidenceCountLabel: CapacityLoopCopy.screenshotEvidence,
        whatRepeated: CapacityLoopCopy.screenshotWhatRepeated,
        costLater: CapacityLoopCopy.screenshotCostLater,
        watchNext: CapacityLoopCopy.screenshotWatchNext,
        primaryCtaLabel: CapacityLoopCopy.saveYesMomentCta,
        secondaryCtaLabel: CapacityLoopCopy.reviewLoopCta,
        primaryRoute: CapacityLoopCopy.recordRoute,
        secondaryRoute: CapacityLoopCopy.route,
        shareCopy: CapacityLoopCopy.shareCopy,
        triggerLabel: CapacityLoopCopy.loopDiagramTrigger,
        saidYesLabel: CapacityLoopCopy.loopDiagramSaidYes,
        costLaterLabel: CapacityLoopCopy.loopDiagramCostLater,
        repeatedLabel: CapacityLoopCopy.loopDiagramRepeated,
        watchNextLabel: CapacityLoopCopy.loopDiagramWatchNext,
      );

  String _whatRepeated(CapacityLoopInput input) {
    final theme = input.topRecurringTheme?.trim();
    if (theme != null && theme.isNotEmpty) {
      return CapacityLoopCopy.whatRepeatedWithTheme(theme);
    }
    if (input.capacityEvidenceCount >= CapacityLoopGates.minRealMomentsForFullCard) {
      return CapacityLoopCopy.whatRepeatedStrong;
    }
    return CapacityLoopCopy.whatRepeatedGeneric;
  }

  String _costLater(CapacityLoopInput input) {
    if (input.costSignalCount >= 2) {
      return CapacityLoopCopy.costLaterWithCount(input.costSignalCount);
    }
    if (input.costSignalCount == 1) {
      return CapacityLoopCopy.costLaterForming;
    }
    return CapacityLoopCopy.costLaterUnavailable;
  }

  int _countCapacityEvidence(List<JournalEntry> eligible) {
    final loop = const LoopModeEngine().activate(LoopModeIds.capacityYes);
    var count = 0;
    for (final entry in eligible) {
      if (_entryMatchesCapacity(entry, loop)) count++;
    }
    return count;
  }

  bool _entryMatchesCapacity(JournalEntry entry, LoopMode loop) {
    final lower = entry.transcript.toLowerCase();
    if (const LoopModeEngine().textSupports(loop, entry.transcript)) {
      return true;
    }
    return _yesKeywords.any(lower.contains);
  }

  int _countCostSignals(List<JournalEntry> eligible) {
    var count = 0;
    for (final entry in eligible) {
      final lower = entry.transcript.toLowerCase();
      if (_costKeywords.any(lower.contains)) count++;
    }
    return count;
  }

  String? _topRecurringTheme(List<JournalEntry> eligible) {
    final counts = <String, int>{};
    for (final entry in eligible) {
      for (final theme in entry.reflection?.recurringThemes ?? const []) {
        final normalized = theme.trim().toLowerCase();
        if (normalized.isEmpty) continue;
        counts[normalized] = (counts[normalized] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return null;
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.first.value < 2) return null;
    return sorted.first.key;
  }
}
