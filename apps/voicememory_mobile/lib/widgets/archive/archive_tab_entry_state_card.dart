import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/archive_tab/archive_tab_four_state_engine.dart';
import '../../theme/app_spacing.dart';
import '../../theme/archive_semantic_colors.dart';
import '../../theme/voicememory_cards.dart';

/// Calm Archive tab card for the four early entry-count states.
class ArchiveTabEntryStateCard extends StatelessWidget {
  const ArchiveTabEntryStateCard({
    super.key,
    required this.model,
    this.onPrimary,
  });

  final ArchiveTabFourStateModel model;
  final VoidCallback? onPrimary;

  @override
  Widget build(BuildContext context) {
    final colors = ArchiveSemanticColors.of(context);
    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: colors.primaryText, height: 1.45);

    return Container(
      key: Key('archive_tab_entry_state_${model.state.name}'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: colors.elevatedSurface),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            model.body,
            key: const Key('archive_tab_entry_state_body'),
            style: bodyStyle,
          ),
          if (model.showPrimaryCta && onPrimary != null) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 48,
              width: double.infinity,
              child: FilledButton(
                key: Key(
                  model.state == ArchiveTabFourState.twoRelated
                      ? 'archive_tab_view_evidence_cta'
                      : 'archive_tab_record_moment_cta',
                ),
                onPressed: onPrimary,
                child: Text(model.primaryCta!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
