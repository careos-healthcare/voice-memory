import 'package:flutter/material.dart';

import '../config/screenshot_mode.dart';
import '../features/acquisition/acquisition_cohort_coordinator.dart';
import '../features/acquisition/acquisition_cohort_model.dart';
import '../features/beta_feedback/beta_feedback_engine.dart';
import '../features/capacity_loop/capacity_boundary_response_copy.dart';
import '../features/capacity_loop/capacity_boundary_response_engine.dart';
import '../features/capacity_loop/capacity_boundary_response_models.dart';
import '../features/capacity_loop/capacity_boundary_response_store.dart';
import '../features/capacity_loop/capacity_cost_store.dart';
import '../features/capacity_loop/capacity_decision_outcome_store.dart';
import '../features/demo/sample_archive_mode.dart';
import '../features/loop_mode/loop_mode_coordinator.dart';
import '../models/journal_entry.dart';
import '../services/app_services.dart';
import '../services/journal_service.dart';
import '../theme/app_spacing.dart';
import '../widgets/capacity_boundary_response_card.dart';
import '../widgets/pushed_screen_shell.dart';

/// Full capacity boundary response screen — fixed templates only.
class CapacityBoundaryResponseScreen extends StatefulWidget {
  const CapacityBoundaryResponseScreen({
    super.key,
    this.journalService,
    this.engine = const CapacityBoundaryResponseEngine(),
    CapacityBoundaryResponseResult? initialResult,
    CapacityBoundaryResponseInput? initialInput,
    this.capacityLoopActive = false,
    this.capacityCohortActive = false,
  })  : _initialResult = initialResult,
        _initialInput = initialInput;

  final JournalService? journalService;
  final CapacityBoundaryResponseEngine engine;
  final bool capacityLoopActive;
  final bool capacityCohortActive;
  final CapacityBoundaryResponseResult? _initialResult;
  final CapacityBoundaryResponseInput? _initialInput;

  @override
  State<CapacityBoundaryResponseScreen> createState() =>
      _CapacityBoundaryResponseScreenState();
}

class _CapacityBoundaryResponseScreenState
    extends State<CapacityBoundaryResponseScreen> {
  CapacityBoundaryResponseResult? _result;
  CapacityBoundaryResponseInput? _lastInput;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget._initialResult != null) {
      _result = widget._initialResult;
      _lastInput = widget._initialInput;
      _loading = false;
      return;
    }
    _load();
  }

  Future<void> _load() async {
    if (ScreenshotMode.enabled) {
      if (!mounted) return;
      setState(() {
        _result = CapacityBoundaryResponseResult.hidden;
        _loading = false;
      });
      return;
    }

    await CapacityBoundaryResponseStore.ensureLoaded();
    await CapacityCostStore.ensureLoaded();
    await CapacityDecisionOutcomeStore.ensureLoaded();
    final journal = widget.journalService ?? AppServices.instance.journal;
    final entries = await journal.loadAll();
    final loop = await LoopModeCoordinator.loadActive();
    final cohort = await AcquisitionCohortCoordinator.load();
    final loopActive = loop?.isCapacityYes ?? widget.capacityLoopActive;
    final cohortActive =
        cohort?.cohortId == AcquisitionCohortId.capacityYesDirect ||
            widget.capacityCohortActive;

    if (!mounted) return;
    final input = _inputFromJournal(
      entries,
      loopActive: loopActive,
      cohortActive: cohortActive,
    );
    setState(() {
      _lastInput = input;
      _result = widget.engine.build(input);
      _loading = false;
    });
  }

  CapacityBoundaryResponseInput _inputFromJournal(
    List<JournalEntry> entries, {
    required bool loopActive,
    required bool cohortActive,
  }) {
    final realEntries = SampleArchiveMode.excludeSampleEntries(entries);
    final engine = widget.engine;
    return CapacityBoundaryResponseInput(
      sampleMode: false,
      realSavedMomentCount: BetaFeedbackEngine.realEntryCountFor(realEntries),
      capacityWedgeActive: loopActive || cohortActive,
      capacityMomentCount:
          engine.loopEngine.eligibleCapacityEntryIds(realEntries).length,
      capacityEvidenceCount:
          engine.loopEngine.countCapacityEvidence(realEntries),
      outcomeOrCostRecordCount:
          CapacityDecisionOutcomeStore.countWithOutcome(
                CapacityDecisionOutcomeStore.cached,
              ) +
              CapacityCostStore.countWithLaterCost(CapacityCostStore.cached),
      pendingDecisionOutcome: false,
      pendingCostCheckin: false,
      beforeYesPauseOnHome: false,
      weeklyReviewOnHome: false,
      selection: CapacityBoundaryResponseStore.cached,
    );
  }

  void _refreshAfterSelection() {
    final input = _lastInput;
    if (input == null) return;
    setState(() {
      _result = widget.engine.build(
        input.copyWith(selection: CapacityBoundaryResponseStore.cached),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: CapacityBoundaryResponseCopy.title,
      fallbackRoute: CapacityBoundaryResponseCopy.archiveHomeRoute,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              key: const Key('capacity_boundary_response_screen'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: _content(_result!),
            ),
    );
  }

  Widget _content(CapacityBoundaryResponseResult result) {
    if (!result.hasFeature) {
      return Text(
        CapacityBoundaryResponseCopy.body,
        key: const Key('capacity_boundary_response_screen_insufficient'),
      );
    }

    return CapacityBoundaryResponsePicker(
      result: result,
      onSelectionChanged: _refreshAfterSelection,
    );
  }
}
