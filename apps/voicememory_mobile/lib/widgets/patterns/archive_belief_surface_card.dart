import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/archive_reactivity/archive_belief_surface.dart';
import '../../theme/archive_loop_theme.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// Archive belief proof surface — what the archive currently believes from evidence.
class ArchiveBeliefSurfaceCard extends StatelessWidget {
  const ArchiveBeliefSurfaceCard({
    super.key,
    required this.surface,
    required this.onSurface,
  });

  final ArchiveBeliefSurface surface;
  final String onSurface;

  @override
  Widget build(BuildContext context) {
    if (!surface.shouldDisplay) return const SizedBox.shrink();

    ArchiveBeliefSurfaceLog.shown(surface: onSurface);

    return Container(
      key: Key('archive_belief_surface_card_$onSurface'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: ArchiveLoopTheme.cardDecoration(
        background: ArchiveLoopTheme.loopCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            surface.isPreview
                ? ArchiveBeliefSurfaceCopy.previewTitle
                : ArchiveBeliefSurfaceCopy.cardTitle,
            key: const Key('archive_belief_surface_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context)
                .copyWith(color: ArchiveLoopTheme.loopTextPrimary),
          ),
          if (surface.isPreview) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              ArchiveBeliefSurfaceCopy.previewLabel,
              key: const Key('archive_belief_surface_preview_label'),
              style: VoiceMemoryTypography.metadataStyle(
                color: ArchiveLoopTheme.loopAccentSoft,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (!surface.isPreview) ...[
            _Section(
              label: ArchiveBeliefSurfaceCopy.beliefLabel,
              body: surface.beliefSummary,
              bodyKey: const Key('archive_belief_surface_belief'),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          _Section(
            label: ArchiveBeliefSurfaceCopy.evidenceLabel,
            body: surface.evidenceSummary,
            bodyKey: const Key('archive_belief_surface_evidence'),
          ),
          const SizedBox(height: AppSpacing.sm),
          _Section(
            label: ArchiveBeliefSurfaceCopy.whatChangedLabel,
            body: surface.whatChangedSummary,
            bodyKey: const Key('archive_belief_surface_what_changed'),
          ),
          if (surface.confidenceLabel.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              surface.confidenceLabel,
              key: const Key('archive_belief_surface_confidence'),
              style: VoiceMemoryTypography.metadataStyle(
                color: ArchiveLoopTheme.loopTextSecondary,
              ),
            ),
          ],
          if (surface.isPreview && surface.previewBullets.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            for (final bullet in surface.previewBullets) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: VoiceMemoryTypography.bodyStyle(
                      color: ArchiveLoopTheme.loopTextSecondary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      bullet,
                      style: VoiceMemoryTypography.bodyStyle(
                        color: ArchiveLoopTheme.loopTextPrimary,
                      ).copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
          ],
          if (surface.recordNextPrompt?.trim().isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                key: const Key('archive_belief_surface_record_cta'),
                style: ArchiveLoopTheme.primaryCtaStyle(context),
                onPressed: () {
                  ArchiveBeliefSurfaceLog.promptTapped();
                  context.go(ArchiveBeliefSurfaceResolver.recordRouteFor(surface));
                },
                child: Text(ArchiveBeliefSurfaceCopy.recordNextCta),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.body,
    required this.bodyKey,
  });

  final String label;
  final String body;
  final Key bodyKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: VoiceMemoryTypography.metadataStyle(
            color: ArchiveLoopTheme.loopTextSecondary,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          body,
          key: bodyKey,
          style: VoiceMemoryTypography.bodyStyle(
            color: ArchiveLoopTheme.loopTextPrimary,
          ).copyWith(height: 1.45),
        ),
      ],
    );
  }
}
