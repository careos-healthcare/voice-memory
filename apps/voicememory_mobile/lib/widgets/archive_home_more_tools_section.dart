import 'package:flutter/material.dart';

import '../design/archive_mobile_typography.dart';
import '../features/archive_home/archive_home_priority_copy.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_cards.dart';
import '../theme/voicememory_colors.dart';

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

class _ArchiveHomeMoreToolsSectionState
    extends State<ArchiveHomeMoreToolsSection> {
  late bool _expanded = widget.initiallyExpanded;

  void _toggleExpanded() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    if (widget.children.isEmpty) {
      return const SizedBox.shrink(key: Key('archive_home_more_tools_hidden'));
    }

    final radius = BorderRadius.circular(VoiceMemoryCards.radius);
    final cardDecoration = VoiceMemoryCards.standard(
      background: AppColors.surfaceAlt,
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: cardDecoration.borderRadius,
        boxShadow: cardDecoration.boxShadow,
      ),
      child: Material(
        key: const Key('more_archive_tools_card'),
        color: AppColors.surfaceAlt,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: VoiceMemoryColors.border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              label: ArchiveHomePriorityCopy.moreArchiveToolsTitle,
              expanded: _expanded,
              onTap: _toggleExpanded,
              child: InkWell(
                key: const Key('more_archive_tools_toggle'),
                onTap: _toggleExpanded,
                borderRadius: BorderRadius.vertical(
                  top: radius.topLeft,
                  bottom: _expanded ? Radius.zero : radius.bottomLeft,
                ),
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
                              style: ArchiveMobileTypography.listSubtitle(
                                context,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.expand_more,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              clipBehavior: Clip.hardEdge,
              child: _expanded
                  ? Column(
                      key: const Key('more_archive_tools_expanded_content'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
                    )
                  : const SizedBox(
                      key: ValueKey('more_archive_tools_collapsed'),
                      width: double.infinity,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
