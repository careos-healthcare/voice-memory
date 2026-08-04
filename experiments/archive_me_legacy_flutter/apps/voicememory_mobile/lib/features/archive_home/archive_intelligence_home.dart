import 'package:flutter/material.dart';

import '../../design/archive_mobile_spacing.dart';
import 'archive_intelligence_presentation.dart';
import 'ui/archive_next_action_section.dart';
import 'ui/archive_reasoning_section.dart';
import 'ui/supporting_moments_section.dart';
import 'ui/what_changed_section.dart';

class ArchiveIntelligenceHome extends StatelessWidget {
  const ArchiveIntelligenceHome({
    super.key,
    required this.presentation,
    required this.onRefresh,
    required this.onOpenMoment,
    required this.onAction,
  });

  final ArchiveIntelligencePresentation presentation;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onOpenMoment;
  final ValueChanged<ArchiveIntelligenceAction> onAction;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        key: const Key('archive_intelligence_home'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: ArchiveMobileSpacing.pagePadding,
        children: presentation.isEmpty
            ? [
                _ArchiveIntelligenceEmptyState(
                  section: presentation.sections.single,
                  onAction: onAction,
                ),
              ]
            : [
                WhatChangedSection(
                  section: presentation.section(
                    ArchiveIntelligenceSectionId.whatChanged,
                  )!,
                ),
                ArchiveReasoningSection(
                  section: presentation.section(
                    ArchiveIntelligenceSectionId.reasoning,
                  )!,
                ),
                SupportingMomentsSection(
                  section: presentation.section(
                    ArchiveIntelligenceSectionId.supportingMoments,
                  )!,
                  onOpenMoment: onOpenMoment,
                ),
                ArchiveNextActionSection(
                  section: presentation.section(
                    ArchiveIntelligenceSectionId.nextAction,
                  )!,
                  onAction: onAction,
                ),
              ],
      ),
    );
  }
}

class _ArchiveIntelligenceEmptyState extends StatelessWidget {
  const _ArchiveIntelligenceEmptyState({
    required this.section,
    required this.onAction,
  });

  final ArchiveIntelligenceSection section;
  final ValueChanged<ArchiveIntelligenceAction> onAction;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: section.title,
      child: Card(
        key: const Key('archive_intelligence_empty'),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                section.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(section.body, style: Theme.of(context).textTheme.bodyLarge),
              if (section.actionLabel != null) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => onAction(section.action),
                  icon: const Icon(Icons.mic_none),
                  label: Text(section.actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
