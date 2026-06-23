import 'package:flutter/material.dart';

import '../design/archive_mobile_typography.dart';
import '../features/archive_home/archive_home_priority_copy.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_cards.dart';

/// Collapsible secondary Archive Home tools — keeps the top area calm.
class ArchiveHomeMoreToolsSection extends StatefulWidget {
  const ArchiveHomeMoreToolsSection({
    super.key,
    required this.children,
    this.initiallyExpanded = false,
  });

  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  State<ArchiveHomeMoreToolsSection> createState() =>
      _ArchiveHomeMoreToolsSectionState();
}

class _ArchiveHomeMoreToolsSectionState extends State<ArchiveHomeMoreToolsSection> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    if (widget.children.isEmpty) {
      return const SizedBox.shrink(key: Key('archive_home_more_tools_hidden'));
    }

    return Container(
      key: const Key('archive_home_more_tools_section'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: const Key('archive_home_more_tools_toggle'),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ArchiveHomePriorityCopy.moreArchiveToolsTitle,
                          style: ArchiveMobileTypography.listTitle(context),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          ArchiveHomePriorityCopy.moreArchiveToolsBody,
                          style: ArchiveMobileTypography.listSubtitle(context),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: widget.children,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
