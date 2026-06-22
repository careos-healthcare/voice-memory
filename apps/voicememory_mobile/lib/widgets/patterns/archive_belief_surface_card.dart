import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/archive_evidence/archive_belief_correction_store.dart';
import '../../features/archive_evidence/archive_belief_thread_copy.dart';
import '../../features/archive_evidence/archive_belief_thread_model.dart';
import '../../features/archive_proof/archive_belief_surface.dart';
import '../../features/archive_proof/archive_belief_surface_copy.dart';
import '../../features/tomorrow_return/active_pattern_thread_coordinator.dart';
import '../../features/tomorrow_return/active_pattern_thread_model.dart';
import '../../features/tomorrow_return/watch_for_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import 'archive_belief_correction_actions.dart';

/// Archive belief proof surface — above timeline on the Patterns tab.
class ArchiveBeliefSurfaceCard extends StatefulWidget {
  const ArchiveBeliefSurfaceCard({
    super.key,
    required this.surface,
    required this.onRecordNext,
    this.onDismissed,
  });

  final ArchiveBeliefSurface surface;
  final VoidCallback onRecordNext;
  final VoidCallback? onDismissed;

  @override
  State<ArchiveBeliefSurfaceCard> createState() =>
      _ArchiveBeliefSurfaceCardState();
}

class _ArchiveBeliefSurfaceCardState extends State<ArchiveBeliefSurfaceCard> {
  String? _statusMessage;

  ArchiveBeliefThread? get _thread => widget.surface.thread;

  bool get _hidden {
    if (!widget.surface.shouldShow) return true;
    final thread = _thread;
    if (thread == null) return false;
    return ArchiveBeliefCorrectionStore.isDismissed(thread.suggestionId);
  }

  Future<void> _saveThread() async {
    final thread = _thread;
    if (thread == null) return;
    final now = DateTime.now();
    await ActivePatternThreadCoordinator.writeCurrentForFirstSession(
      ActivePatternThread(
        id: 'thread_${now.millisecondsSinceEpoch}',
        title: thread.currentBelief,
        createdAt: now,
        updatedAt: now,
        watchForText: thread.whatToTest,
        chips: const [],
        status: ActivePatternThreadStatus.active,
        daysActive: 1,
        lastResult: WatchForResult.unclear,
        nextPrompt: thread.whatToTest,
      ),
    );
    ArchiveBeliefCorrectionStore.markSaved(thread.suggestionId);
    setState(
      () => _statusMessage = ArchiveBeliefThreadCopy.saveThreadThanks,
    );
  }

  void _dismiss(String thanks) {
    final thread = _thread;
    if (thread == null) return;
    ArchiveBeliefCorrectionStore.dismiss(thread.suggestionId);
    setState(() => _statusMessage = thanks);
    widget.onDismissed?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox.shrink();

    final surface = widget.surface;
    return Container(
      key: const Key('archive_belief_proof_primary_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F9F4),
        borderRadius: BorderRadius.circular(VoiceMemoryCards.radius),
        border: Border.all(
          color: AppColors.accentPrimary.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: VoiceMemoryCards.standard().boxShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (surface.isPreview) ...[
            Text(
              ArchiveBeliefSurfaceCopy.previewBadge,
              key: const Key('archive_belief_surface_preview_badge'),
              style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(
            surface.headline,
            style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
              color: AppColors.accentPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '“${surface.beliefSummary}”',
            key: const Key('archive_belief_surface_belief'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            ArchiveBeliefSurfaceCopy.evidenceLabel,
            style: ArchiveMobileTypography.cardLabel(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            surface.evidenceSummary,
            key: const Key('archive_belief_surface_evidence'),
            style: ArchiveMobileTypography.body(context),
          ),
          if (surface.whatChangedSummary case final changed?) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              ArchiveBeliefSurfaceCopy.whatChangedLabel,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              changed,
              key: const Key('archive_belief_surface_what_changed'),
              style: ArchiveMobileTypography.body(context),
            ),
          ],
          if (surface.confidenceLabel case final confidence?) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              ArchiveBeliefSurfaceCopy.confidenceLabel,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              confidence,
              key: const Key('archive_belief_surface_confidence'),
              style: ArchiveMobileTypography.body(context),
            ),
          ],
          if (surface.recordNextCta case final cta?) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('archive_belief_surface_record_next'),
                onPressed: widget.onRecordNext,
                child: Text(cta),
              ),
            ),
          ],
          if (_thread != null && !surface.isPreview) ...[
            if (_statusMessage case final message?) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                style: ArchiveMobileTypography.responsiveHelper(context),
              ),
            ] else ...[
              const SizedBox(height: AppSpacing.sm),
              ArchiveBeliefCorrectionActions(
                onSaveThread: _saveThread,
                onNotMe: () => _dismiss(ArchiveBeliefThreadCopy.notMeThanks),
                onCloseButDifferent: () =>
                    _dismiss(ArchiveBeliefThreadCopy.closeThanks),
                onRecordMoreEvidence: widget.onRecordNext,
              ),
            ],
          ],
        ],
      ),
    );
  }
}
