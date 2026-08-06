import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../models/journal_entry.dart';
import '../../../../services/app_services.dart';
import '../../../../services/journal_service.dart';
import '../../domain/models/cognitive_biomarkers.dart';
import '../../domain/models/curiosity_hook.dart' as domain;
import '../../domain/services/cognitive_anomaly_detector.dart';
import '../../domain/services/cognitive_trajectory_evaluator.dart';
import '../../repositories/clinical_trajectory_history_store.dart';
import '../../repositories/cognitive_baseline_store.dart';
import '../models/curiosity_hook_presentation.dart';
import 'grounding_breath_spacer.dart';

export '../models/curiosity_hook_presentation.dart';

/// UI hook state consumed by [CuriosityHookCard].
typedef CuriosityHook = CuriosityHookPresentation;

typedef CuriosityHookSubmit =
    FutureOr<void> Function(String responseText, {required bool wasGrounded});

@Deprecated('Use CuriosityHookSubmit')
typedef CuriosityHookResponseSubmitted = CuriosityHookSubmit;

class CuriosityHookCard extends StatefulWidget {
  CuriosityHookCard({
    super.key,
    CuriosityHookPresentation? presentation,
    CuriosityHookPresentation? hook,
    this.onSubmit,
    this.onResponseSubmitted,
    this.groundingPacingDuration = const Duration(seconds: 4),
  }) : presentation = presentation ?? hook!;

  CuriosityHookCard.fromDomain({
    super.key,
    required domain.CuriosityHook hook,
    JournalEntry? sourceEntry,
    CognitiveBiomarkers? currentMetrics,
    CognitiveBiomarkers? baselineMetrics,
    CognitiveAnomalyDetector? anomalyDetector,
    this.onSubmit,
    this.onResponseSubmitted,
    this.groundingPacingDuration = const Duration(seconds: 4),
  }) : presentation = _hookFromDomain(
         hook,
         sourceEntry: sourceEntry,
         currentMetrics: currentMetrics,
         baselineMetrics: baselineMetrics,
         anomalyDetector: anomalyDetector,
       );

  final CuriosityHookPresentation presentation;
  final CuriosityHookSubmit? onSubmit;
  final CuriosityHookSubmit? onResponseSubmitted;
  final Duration groundingPacingDuration;

  CuriosityHookPresentation get hook => presentation;

  CuriosityHookSubmit? get _resolvedSubmit => onSubmit ?? onResponseSubmitted;

  static CuriosityHookPresentation _hookFromDomain(
    domain.CuriosityHook hook, {
    JournalEntry? sourceEntry,
    CognitiveBiomarkers? currentMetrics,
    CognitiveBiomarkers? baselineMetrics,
    CognitiveAnomalyDetector? anomalyDetector,
  }) {
    final resolvedCurrentMetrics = currentMetrics ?? sourceEntry?.biomarkers;

    return CuriosityHookPresentation.fromDomain(
      hook,
      currentMetrics: resolvedCurrentMetrics,
      baselineMetrics: baselineMetrics,
      sourceLexicalDiversity: sourceEntry?.biomarkers?.lexicalDiversity,
      detector: anomalyDetector ?? const CognitiveAnomalyDetector(),
    );
  }

  @override
  State<CuriosityHookCard> createState() => _CuriosityHookCardState();
}

class _CuriosityHookCardState extends State<CuriosityHookCard> {
  final TextEditingController _textController = TextEditingController();
  bool _hasCompletedGrounding = false;

  @override
  void didUpdateWidget(covariant CuriosityHookCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.presentation.id != widget.presentation.id ||
        oldWidget.presentation.isLowCognitiveLoad !=
            widget.presentation.isLowCognitiveLoad) {
      _hasCompletedGrounding = false;
      _textController.clear();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _handleSubmission() {
    final responseText = _textController.text.trim();
    if (responseText.isEmpty) return;

    widget._resolvedSubmit?.call(
      responseText,
      wasGrounded: widget.presentation.isLowCognitiveLoad,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOverloaded = widget.presentation.isLowCognitiveLoad;

    final dynamicCardPadding = isOverloaded
        ? const EdgeInsets.all(28.0)
        : const EdgeInsets.all(16.0);
    final requiresPacingGate = isOverloaded && !_hasCompletedGrounding;

    return AnimatedContainer(
      key: const Key('curiosity_hook_card'),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: dynamicCardPadding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(isOverloaded ? 28 : 16),
        border: Border.all(
          color: isOverloaded
              ? theme.colorScheme.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.presentation.prompt,
            key: const Key('curiosity_hook_prompt'),
            style: isOverloaded
                ? theme.textTheme.titleMedium?.copyWith(
                    fontSize: 19,
                    height: 1.6,
                    fontWeight: FontWeight.w600,
                  )
                : theme.textTheme.bodyMedium,
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutCubic,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: requiresPacingGate
                  ? Padding(
                      key: const ValueKey('breath_gate_active'),
                      padding: const EdgeInsets.only(top: 24.0),
                      child: Center(
                        child: GroundingBreathSpacer(
                          pacingDuration: widget.groundingPacingDuration,
                          onPacingComplete: () {
                            setState(() => _hasCompletedGrounding = true);
                          },
                        ),
                      ),
                    )
                  : Padding(
                      key: const ValueKey('text_input_active'),
                      padding: const EdgeInsets.only(top: 24.0),
                      child: TextField(
                        key: const Key('curiosity_hook_response_input'),
                        controller: _textController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: isOverloaded
                              ? 'Write down simple words. No pressure.'
                              : 'Capture your conceptual flow details here...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              isOverloaded ? 16 : 8,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: isOverloaded ? 64.0 : 48.0,
            width: double.infinity,
            child: FilledButton(
              key: const Key('curiosity_hook_submit_action'),
              onPressed: requiresPacingGate || widget._resolvedSubmit == null
                  ? null
                  : _handleSubmission,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isOverloaded ? 16 : 8),
                ),
              ),
              child: Text(
                requiresPacingGate
                    ? 'Follow the Breath to Unlock Input'
                    : 'Commit Response Telemetry',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Loads EWMA baseline metrics and renders [CuriosityHookCard] with anomaly detection.
class ConnectedCuriosityHookCard extends StatelessWidget {
  const ConnectedCuriosityHookCard({
    super.key,
    required this.hook,
    this.sourceEntry,
    this.onSubmit,
    this.baselineStore,
    this.journalService,
    this.trajectoryStore,
    this.groundingPacingDuration = const Duration(seconds: 4),
  });

  const ConnectedCuriosityHookCard.fromDomain({
    super.key,
    required this.hook,
    this.sourceEntry,
    this.onSubmit,
    this.baselineStore,
    this.journalService,
    this.trajectoryStore,
    this.groundingPacingDuration = const Duration(seconds: 4),
  });

  final domain.CuriosityHook hook;
  final JournalEntry? sourceEntry;
  final CuriosityHookSubmit? onSubmit;
  final CognitiveBaselineStore? baselineStore;
  final JournalService? journalService;
  final ClinicalTrajectoryHistoryStore? trajectoryStore;
  final Duration groundingPacingDuration;

  @override
  Widget build(BuildContext context) {
    return _ConnectedCuriosityHookCardScope(
      hook: hook,
      sourceEntry: sourceEntry,
      onSubmit: onSubmit,
      baselineStore: baselineStore,
      journalService: journalService,
      trajectoryStore: trajectoryStore,
      groundingPacingDuration: groundingPacingDuration,
    );
  }
}

class _ConnectedCuriosityHookCardScope extends StatefulWidget {
  const _ConnectedCuriosityHookCardScope({
    required this.hook,
    this.sourceEntry,
    this.onSubmit,
    this.baselineStore,
    this.journalService,
    this.trajectoryStore,
    required this.groundingPacingDuration,
  });

  final domain.CuriosityHook hook;
  final JournalEntry? sourceEntry;
  final CuriosityHookSubmit? onSubmit;
  final CognitiveBaselineStore? baselineStore;
  final JournalService? journalService;
  final ClinicalTrajectoryHistoryStore? trajectoryStore;
  final Duration groundingPacingDuration;

  @override
  State<_ConnectedCuriosityHookCardScope> createState() =>
      _ConnectedCuriosityHookCardScopeState();
}

class _ConnectedCuriosityHookCardScopeState
    extends State<_ConnectedCuriosityHookCardScope> {
  late Future<
    ({
      JournalEntry? sourceEntry,
      CognitiveBiomarkers? currentMetrics,
      CognitiveBaselineSnapshot? baselineSnapshot,
    })
  >
  _contextFuture;

  @override
  void initState() {
    super.initState();
    _contextFuture = _loadPresentationContext();
  }

  @override
  void didUpdateWidget(covariant _ConnectedCuriosityHookCardScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hook.id != widget.hook.id ||
        oldWidget.sourceEntry?.id != widget.sourceEntry?.id ||
        oldWidget.baselineStore != widget.baselineStore ||
        oldWidget.journalService != widget.journalService) {
      _contextFuture = _loadPresentationContext();
    }
  }

  String _resolvedSourceEntryId() {
    final sourceEntryId = widget.hook.sourceEntryId?.trim();
    if (sourceEntryId != null && sourceEntryId.isNotEmpty) {
      return sourceEntryId;
    }
    return widget.hook.entryId;
  }

  Future<
    ({
      JournalEntry? sourceEntry,
      CognitiveBiomarkers? currentMetrics,
      CognitiveBaselineSnapshot? baselineSnapshot,
    })
  >
  _loadPresentationContext() async {
    final baselineSnapshot = widget.baselineStore != null
        ? await widget.baselineStore!.loadSnapshot()
        : AppServices.isInitialized
        ? await AppServices.instance.getBaselineStore().loadSnapshot()
        : null;

    JournalEntry? sourceEntry = widget.sourceEntry;
    final targetEntryId = _resolvedSourceEntryId();
    if (sourceEntry?.id != targetEntryId) {
      if (widget.journalService != null) {
        sourceEntry = await widget.journalService!.getEntry(targetEntryId);
      } else if (AppServices.isInitialized) {
        sourceEntry = await AppServices.instance.journal.getEntry(
          targetEntryId,
        );
      }
    }

    final currentMetrics =
        sourceEntry?.biomarkers ??
        (AppServices.isInitialized
            ? await AppServices.instance.getCurrentMetrics(widget.hook)
            : null);

    return (
      sourceEntry: sourceEntry,
      currentMetrics: currentMetrics,
      baselineSnapshot: baselineSnapshot,
    );
  }

  Future<void> _commitTrajectoryRecord({required bool wasGrounded}) async {
    if (!AppServices.isInitialized) return;

    final trajectoryStore =
        widget.trajectoryStore ?? AppServices.instance.getTrajectoryStore();
    final resultRecord = StoredTrajectoryRecord(
      date: DateTime.now().toUtc(),
      directionValue: CognitiveDirection.stagnant.name,
      lexicalDelta: 0.0,
      driftDelta: 0.0,
      wasGrounded: wasGrounded,
      entryId: widget.hook.entryId,
      hookId: widget.hook.id,
    );
    await trajectoryStore.appendRecord(resultRecord);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<
      ({
        JournalEntry? sourceEntry,
        CognitiveBiomarkers? currentMetrics,
        CognitiveBaselineSnapshot? baselineSnapshot,
      })
    >(
      future: _contextFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final contextData = snapshot.data!;
        final presentation = CuriosityHookPresentation.fromDomain(
          widget.hook,
          currentMetrics: contextData.currentMetrics,
          baselineMetrics: contextData.baselineSnapshot?.biomarkers,
          sourceLexicalDiversity:
              contextData.sourceEntry?.biomarkers?.lexicalDiversity,
        );

        return CuriosityHookCard(
          presentation: presentation,
          groundingPacingDuration: widget.groundingPacingDuration,
          onSubmit:
              widget.onSubmit ??
              (_, {required wasGrounded}) =>
                  _commitTrajectoryRecord(wasGrounded: wasGrounded),
        );
      },
    );
  }
}
