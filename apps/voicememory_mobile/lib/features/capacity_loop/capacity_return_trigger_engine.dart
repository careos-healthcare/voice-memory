import '../../models/journal_entry.dart';
import '../demo/sample_archive_mode.dart';
import 'capacity_loop_engine.dart';
import 'capacity_return_trigger_copy.dart';
import 'capacity_return_trigger_models.dart';
import 'capacity_three_moment_gates.dart';

/// Builds capacity return trigger from local moment counts — no storage.
class CapacityReturnTriggerEngine {
  const CapacityReturnTriggerEngine({
    this.loopEngine = const CapacityLoopEngine(),
  });

  final CapacityLoopEngine loopEngine;

  CapacityReturnTriggerResult build(CapacityReturnTriggerInput input) {
    if (!_isEligible(input)) {
      return CapacityReturnTriggerResult.hidden;
    }

    final count = input.capacityMomentCount.clamp(0, 999);
    final target = CapacityReturnTriggerCopy.activationTarget;

    return switch (input.surface) {
      CapacityReturnTriggerSurface.completion => _buildCompletion(count, target),
      CapacityReturnTriggerSurface.archiveHome => _buildArchiveHome(count, target),
      CapacityReturnTriggerSurface.recordLine => _buildRecordLine(count, target),
      CapacityReturnTriggerSurface.betaMissionHint =>
        _buildBetaMissionHint(count, target),
    };
  }

  CapacityReturnTriggerResult buildFromJournal({
    required List<JournalEntry> entries,
    required bool capacityLoopActive,
    required bool capacityCohortActive,
    required CapacityReturnTriggerSurface surface,
    bool sampleMode = false,
    bool screenshotMode = false,
  }) {
    final realEntries = SampleArchiveMode.excludeSampleEntries(entries);
    if (sampleMode ||
        screenshotMode ||
        (entries.isNotEmpty && realEntries.isEmpty)) {
      return CapacityReturnTriggerResult.hidden;
    }

    final momentCount =
        loopEngine.eligibleCapacityEntryIds(realEntries).length;

    return build(
      CapacityReturnTriggerInput(
        sampleMode: sampleMode,
        screenshotMode: screenshotMode,
        capacityWedgeActive: capacityLoopActive || capacityCohortActive,
        capacityMomentCount: momentCount,
        surface: surface,
      ),
    );
  }

  static String recordProgressLine(CapacityReturnTriggerResult result) =>
      result.recordProgressLine;

  static String betaMissionHint(CapacityReturnTriggerResult result) =>
      result.betaMissionHint;

  bool _isEligible(CapacityReturnTriggerInput input) {
    if (input.sampleMode || input.screenshotMode) return false;
    if (!input.capacityWedgeActive) return false;
    return true;
  }

  CapacityReturnTriggerResult _buildCompletion(int count, int target) {
    if (count != 1) return CapacityReturnTriggerResult.hidden;

    return CapacityReturnTriggerResult(
      showCard: true,
      title: CapacityReturnTriggerCopy.completionTitle,
      body: CapacityReturnTriggerCopy.completionBody,
      primaryCtaLabel: CapacityReturnTriggerCopy.completionPrimaryCta,
      primaryRoute: '',
      primaryDismisses: true,
      secondaryCtaLabel: CapacityReturnTriggerCopy.completionSecondaryCta,
      secondaryRoute: CapacityReturnTriggerCopy.recordRoute,
      showSecondary: true,
      recordProgressLine: '',
      betaMissionHint: '',
      capacityMomentCount: count,
      activationTarget: target,
    );
  }

  CapacityReturnTriggerResult _buildArchiveHome(int count, int target) {
    if (count <= 0 ||
        count >= target ||
        count > CapacityThreeMomentGates.activationTarget) {
      return CapacityReturnTriggerResult.hidden;
    }

    return CapacityReturnTriggerResult(
      showCard: true,
      title: CapacityReturnTriggerCopy.archiveHomeTitle,
      body: CapacityReturnTriggerCopy.archiveHomeBody(count, target: target),
      primaryCtaLabel: CapacityReturnTriggerCopy.archiveHomePrimaryCta,
      primaryRoute: CapacityReturnTriggerCopy.recordRoute,
      primaryDismisses: false,
      secondaryCtaLabel: CapacityReturnTriggerCopy.archiveHomeReviewCta,
      secondaryRoute: CapacityReturnTriggerCopy.loopRoute,
      showSecondary: true,
      recordProgressLine: '',
      betaMissionHint: '',
      capacityMomentCount: count,
      activationTarget: target,
    );
  }

  CapacityReturnTriggerResult _buildRecordLine(int count, int target) {
    if (count >= target) return CapacityReturnTriggerResult.hidden;

    return CapacityReturnTriggerResult(
      showCard: false,
      title: '',
      body: '',
      primaryCtaLabel: '',
      primaryRoute: '',
      primaryDismisses: false,
      secondaryCtaLabel: '',
      secondaryRoute: '',
      showSecondary: false,
      recordProgressLine: CapacityReturnTriggerCopy.recordProgressLine,
      betaMissionHint: '',
      capacityMomentCount: count,
      activationTarget: target,
    );
  }

  CapacityReturnTriggerResult _buildBetaMissionHint(int count, int target) {
    if (count <= 0 || count >= target) {
      return CapacityReturnTriggerResult.hidden;
    }

    return CapacityReturnTriggerResult(
      showCard: false,
      title: '',
      body: '',
      primaryCtaLabel: '',
      primaryRoute: '',
      primaryDismisses: false,
      secondaryCtaLabel: '',
      secondaryRoute: '',
      showSecondary: false,
      recordProgressLine: '',
      betaMissionHint: CapacityReturnTriggerCopy.betaMissionHint,
      capacityMomentCount: count,
      activationTarget: target,
    );
  }
}
