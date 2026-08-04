import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/archive_evidence/archive_evidence.dart';
import '../features/archive_state_object/archive_state_object.dart';
import '../design/warm_archive_copy.dart';
import '../features/discover/belief_engine.dart';
import '../features/archive_explanations/explanation_models.dart';
import '../features/retention/retention_analytics.dart';
import '../models/journal_entry.dart';
import '../product/consumer_ui_copy.dart';
import '../theme/app_theme.dart';
import 'archive_evidence_panel.dart';
import 'archive_why_button.dart';

/// Shown immediately after a successful save — first 30-second win.
class InstantArchiveBeliefCard extends StatefulWidget {
  const InstantArchiveBeliefCard({
    super.key,
    required this.entries,
    this.state,
    this.onDismiss,
  });

  final List<JournalEntry> entries;
  final ArchiveStateObjectV3? state;
  final VoidCallback? onDismiss;

  @override
  State<InstantArchiveBeliefCard> createState() =>
      _InstantArchiveBeliefCardState();
}

class _InstantArchiveBeliefCardState extends State<InstantArchiveBeliefCard> {
  var _evidenceExpanded = false;
  var _loggedView = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loggedView) {
      _loggedView = true;
      RetentionAnalytics.instantBeliefViewed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = const DiscoverBeliefEngine().build(
      entries: widget.entries,
      state: widget.state,
    );
    final hasMinimum = archiveHasMinimumEvidence(widget.entries);
    final eligible = archiveEligibleEvidenceEntries(widget.entries);

    final learning =
        !hasMinimum ||
        card == null ||
        card.statement.contains('still gathering') ||
        card.statement.contains('still learning');

    return Semantics(
      label: ConsumerUiCopy.instantPatternLead,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                ConsumerUiCopy.instantPatternLead,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                learning
                    ? ConsumerUiCopy.instantStillLearning
                    : '“${card.statement}”',
                style: const TextStyle(fontSize: 16, height: 1.4),
              ),
              if (!learning) ...[
                const SizedBox(height: 10),
                Text(
                  WarmArchiveCopy.confidenceStrengthLine(
                    card.confidencePercent,
                  ),
                  semanticsLabel: WarmArchiveCopy.confidenceStrengthSemantics(
                    card.confidencePercent,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  ConsumerUiCopy.instantMomentsLabel,
                  style: TextStyle(fontSize: 12, color: AppTheme.muted),
                ),
                for (final e in card.supportingEntries.take(3))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '• ${archiveEvidenceRelativeLabel(e.createdAt)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
              ] else if (eligible.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '• ${archiveEvidenceRelativeLabel(eligible.last.createdAt)}',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (!learning)
                    ArchiveWhyButton(
                      ref: ArchiveInsightRef.belief(),
                      entries: widget.entries,
                      state: widget.state,
                      surface: 'instant_belief',
                      compact: true,
                    ),
                  TextButton(
                    onPressed:
                        eligible.isEmpty &&
                            (card?.supportingEntries.isEmpty ?? true)
                        ? null
                        : () {
                            setState(
                              () => _evidenceExpanded = !_evidenceExpanded,
                            );
                            RetentionAnalytics.instantBeliefEvidenceOpened();
                          },
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    child: Text(
                      _evidenceExpanded
                          ? ConsumerUiCopy.hideMoments
                          : ConsumerUiCopy.showMoments,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/archive-belief'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    child: const Text(ConsumerUiCopy.viewAllPatterns),
                  ),
                ],
              ),
              if (_evidenceExpanded)
                ArchiveEvidencePanel(
                  entries: card?.supportingEntries.isNotEmpty == true
                      ? card!.supportingEntries
                      : eligible.reversed.take(4).toList(),
                  analyticsContext: 'instant_belief',
                ),
            ],
          ),
        ),
      ),
    );
  }
}
