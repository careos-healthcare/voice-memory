import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/onboarding/record_return_pro_state.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// D. Change can begin — explains the next value step when two or more
/// entries exist but no real returned/faded/changed insight is ready yet.
class ChangeStartsCard extends StatefulWidget {
  const ChangeStartsCard({
    required this.entryCount, required this.onViewArchive, required this.onSearchArchive, required this.onSeen, super.key,
  });

  final int entryCount;
  final VoidCallback onViewArchive;
  final VoidCallback onSearchArchive;
  final VoidCallback onSeen;

  @override
  State<ChangeStartsCard> createState() => _ChangeStartsCardState();
}

class _ChangeStartsCardState extends State<ChangeStartsCard> {
  @override
  void initState() {
    super.initState();
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.changeCanBeginSeen,
      entryCount: widget.entryCount,
      stage: RecordReturnProStage.changeStart.id,
      source: 'record',
      oncePerSession: true,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onSeen());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('change_starts_card'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF4F8FC),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            RecordReturnProCopy.changeTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            RecordReturnProCopy.changeBody,
            style: ArchiveMobileTypography.body(
              context,
            ).copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            key: const Key('change_starts_view_archive'),
            onPressed: widget.onViewArchive,
            child: const Text(RecordReturnProCopy.changeViewArchive),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            key: const Key('change_starts_search_archive'),
            onPressed: widget.onSearchArchive,
            child: const Text(RecordReturnProCopy.changeSearchArchive),
          ),
        ],
      ),
    );
  }
}