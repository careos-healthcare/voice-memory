import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/acquisition/audience_wedge_model.dart';
import '../../features/first_session/first_session_pattern_model.dart';
import '../../features/interpretation/interpretation_quality_engine.dart';
import '../../features/loop_mode/loop_mode_model.dart';
import '../../features/post_save_insight/selected_signal_model.dart';
import '../../features/post_save_insight/signal_feedback_model.dart';
import '../../features/prove_enough/prove_enough_post_record_engine.dart';
import '../../features/prove_enough/prove_enough_post_record_model.dart';
import '../../features/retention/retention_metrics_tracker.dart';
import '../../features/prove_enough/prove_enough_stop_cost_store.dart';
import '../../models/journal_entry.dart';
import '../../theme/app_spacing.dart';
import 'choice_vs_pressure_card.dart';
import 'enoughness_score_card.dart';
import 'prove_enough_retention_panel.dart';
import 'stop_cost_prompt_card.dart';

/// Post-save prove_enough payoff: enoughness, choice vs pressure, stop-cost.
class ProveEnoughPostRecordPayoff extends StatefulWidget {
  const ProveEnoughPostRecordPayoff({
    super.key,
    required this.entryId,
    required this.entry,
    required this.activeLoop,
    required this.pattern,
    this.priorEntries = const [],
    this.feedback = const [],
    this.selectedSignal,
    this.audienceWedge,
    this.includeRetentionPanel = true,
    @visibleForTesting this.stopCostStore,
    @visibleForTesting this.skipStopCostInitialLoad = false,
  });

  final String entryId;
  final JournalEntry entry;
  final LoopMode activeLoop;
  final FirstSessionPattern pattern;
  final List<JournalEntry> priorEntries;
  final List<PostSaveSignalFeedback> feedback;
  final SelectedSignalRecord? selectedSignal;
  final AudienceWedge? audienceWedge;
  final bool includeRetentionPanel;

  @visibleForTesting
  final ProveEnoughStopCostStore? stopCostStore;

  @visibleForTesting
  final bool skipStopCostInitialLoad;

  @override
  State<ProveEnoughPostRecordPayoff> createState() =>
      _ProveEnoughPostRecordPayoffState();
}

class _ProveEnoughPostRecordPayoffState
    extends State<ProveEnoughPostRecordPayoff> {
  static const _engine = ProveEnoughPostRecordEngine();
  static const _interpretationEngine = InterpretationQualityEngine();

  late final ProveEnoughPostRecordModel _model;
  var _metricsTracked = false;

  @override
  void initState() {
    super.initState();
    final interpretation = _interpretationEngine.build(
      latestEntry: widget.entry,
      priorEntries: widget.priorEntries,
      feedback: widget.feedback,
      selectedSignal: widget.selectedSignal,
      patternHint: widget.pattern,
      audienceWedge: widget.audienceWedge,
      activeLoop: widget.activeLoop,
    );
    _model = _engine.analyzeEntry(
      entry: widget.entry,
      interpretationReads: interpretation.reads,
      activeLoop: widget.activeLoop,
    );
    unawaited(_trackShownMetrics());
  }

  Future<void> _trackShownMetrics() async {
    if (_metricsTracked) return;
    _metricsTracked = true;
    await RetentionMetricsTracker.track(
      RetentionMetricsTracker.enoughnessScoreShown,
    );
    await RetentionMetricsTracker.track(
      RetentionMetricsTracker.choicePressureShown,
    );
    await RetentionMetricsTracker.track(
      RetentionMetricsTracker.stopCostPromptShown,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('prove_enough_post_record_payoff'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EnoughnessScoreCard(model: _model),
        const SizedBox(height: AppSpacing.sm),
        ChoiceVsPressureCard(model: _model),
        const SizedBox(height: AppSpacing.sm),
        StopCostPromptCard(
          entryId: widget.entryId,
          stopCostStore: widget.stopCostStore,
          skipInitialLoad: widget.skipStopCostInitialLoad,
        ),
        if (widget.includeRetentionPanel) ...[
          const SizedBox(height: AppSpacing.sm),
          ProveEnoughRetentionPanel(
            postRecordModel: _model,
            entryId: widget.entryId,
          ),
        ],
      ],
    );
  }
}
