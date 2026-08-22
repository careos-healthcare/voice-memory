import 'package:archiveme_mobile/features/archive_explanations/explanation_models.dart';
import 'package:archiveme_mobile/features/breakthrough_tracking/breakthrough_insight_card.dart';
import 'package:archiveme_mobile/features/breakthrough_tracking/breakthrough_tracking_engine.dart';
import 'package:archiveme_mobile/features/evidence_artifact/evidence_artifact_copy.dart';
import 'package:archiveme_mobile/features/evidence_artifact/evidence_proof_navigation.dart';
import 'package:archiveme_mobile/features/evidence_method/insight.dart';
import 'package:archiveme_mobile/features/pattern_correction/pattern_correction_copy.dart';
import 'package:archiveme_mobile/features/pattern_correction/pattern_correction_model.dart';
import 'package:archiveme_mobile/features/session_movement/session_movement_models.dart';
import 'package:archiveme_mobile/services/api_service.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/widgets/archive_v1/archive_insight_feed_card.dart';
import 'package:archiveme_mobile/widgets/archive_v1/inline_evidence_quote.dart';
import 'package:flutter/material.dart';

/// Displays an Evidence Method insight with inline fact-ledger verification.
class EvidenceInsightCard extends StatefulWidget {
  const EvidenceInsightCard({
    required this.insight, super.key,
    this.apiService,
    this.onCorrected,
  });

  final Insight insight;
  final ApiService? apiService;
  final VoidCallback? onCorrected;

  @override
  State<EvidenceInsightCard> createState() => _EvidenceInsightCardState();
}

class _EvidenceInsightCardState extends State<EvidenceInsightCard> {
  bool _suppressed = false;
  bool _submittingCorrection = false;

  ApiService? get _apiService {
    if (widget.apiService != null) return widget.apiService;
    if (AppServices.isInitialized) return AppServices.instance.apiService;
    return null;
  }

  Future<void> _openCorrectionSheet() async {
    final reason = await showModalBottomSheet<PatternCorrectionReason>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => const _EvidenceInsightCorrectionSheet(),
    );

    if (!mounted || reason == null) return;

    final apiService = _apiService;
    if (apiService == null) {
      _showSnackBar('Correction is unavailable right now.');
      return;
    }

    setState(() => _submittingCorrection = true);

    try {
      await apiService.submitInsightCorrection(
        insightId: widget.insight.id,
        reason: reason,
      );
      if (!mounted) return;

      setState(() {
        _suppressed = true;
        _submittingCorrection = false;
      });
      widget.onCorrected?.call();
      _showSnackBar('Pattern suppressed in future analysis.');
    } catch (_, stackTrace) {
      if (!mounted) return;
      setState(() => _submittingCorrection = false);
      _showSnackBar('Could not save your correction. Try again.');
    }
  }

  Future<void> _onAgree() async {
    _showSnackBar('Evidence noted — thanks for confirming.');
  }

  Future<void> _onDisagree() async {
    await _openCorrectionSheet();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_suppressed) return const SizedBox.shrink();

    if (widget.insight.kind == ArchiveInsightKind.breakthrough) {
      return BreakthroughInsightCard(
        shift: BreakthroughShift(
          headline: widget.insight.insightText,
          movementKind: SessionMovementKind.beliefChanged,
        ),
      );
    }

    return AnimatedOpacity(
      opacity: _submittingCorrection ? 0.55 : 1,
      duration: const Duration(milliseconds: 180),
      child: IgnorePointer(
        ignoring: _submittingCorrection,
        child: ArchiveInsightFeedCard(
          key: const Key('evidence_insight_card'),
          insightText: widget.insight.insightText,
          confidenceBand: widget.insight.confidenceBand,
          quotes: InlineEvidenceQuote.fromCitedEntries(widget.insight.citedEntries),
          onAgree: _onAgree,
          onDisagree: _onDisagree,
          onCorrect: _openCorrectionSheet,
          feedbackBusy: _submittingCorrection,
          footer: Row(
            children: [
              TextButton(
                key: const Key('evidence_insight_inspect_math_button'),
                onPressed: () => openEvidenceProofForInsight(
                  context,
                  insight: widget.insight,
                ),
                child: const Text(EvidenceArtifactCopy.inspectEvidenceMath),
              ),
              TextButton(
                key: const Key('evidence_insight_share_proof_button'),
                onPressed: () => openEvidenceProofForInsight(
                  context,
                  insight: widget.insight,
                  openShareOnLaunch: true,
                ),
                child: const Text(EvidenceArtifactCopy.shareProofCard),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EvidenceInsightCorrectionSheet extends StatelessWidget {
  const _EvidenceInsightCorrectionSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'What feels inaccurate?',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            for (final reason in PatternCorrectionCopy.evidenceInsightReasons)
              ListTile(
                key: Key('evidence_insight_correction_${reason.name}'),
                contentPadding: EdgeInsets.zero,
                title: Text(PatternCorrectionCopy.reasonLabel(reason)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).pop(reason),
              ),
          ],
        ),
      ),
    );
  }
}