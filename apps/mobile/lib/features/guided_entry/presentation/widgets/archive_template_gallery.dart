import 'dart:async';

import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/guided_entry/presentation/archive_template_materializer.dart';
import 'package:archiveme_mobile/features/guided_entry/presentation/models/archive_entry_template.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:archiveme_mobile/widgets/archive/view_evidence_inline_link.dart';
import 'package:flutter/material.dart';

/// Horizontal page cards for a blank editor, in the style of a template gallery.
class ArchiveTemplateGallery extends StatefulWidget {
  const ArchiveTemplateGallery({
    required this.onOpenTemplate,
    super.key,
    this.onViewEvidence,
    this.templates = ArchiveEntryTemplates.all,
    this.now,
  });

  /// Persists the template, then opens its page in the editor.
  final Future<void> Function(ArchiveEntryTemplate template) onOpenTemplate;

  /// Reachable evidence affordance for the line the archive engine scored.
  final void Function(ArchiveTemplateDraft draft)? onViewEvidence;

  final List<ArchiveEntryTemplate> templates;

  /// Clock used to preview how the moments line up. Saving uses its own clock.
  final DateTime? now;

  @override
  State<ArchiveTemplateGallery> createState() => _ArchiveTemplateGalleryState();
}

class _ArchiveTemplateGalleryState extends State<ArchiveTemplateGallery> {
  String? _openingId;

  Future<void> _open(ArchiveEntryTemplate template) async {
    if (_openingId != null) return;
    setState(() => _openingId = template.id);
    try {
      await widget.onOpenTemplate(template);
    } finally {
      if (mounted) setState(() => _openingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('archive_template_gallery'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Start from a template',
          style: ArchiveMobileTypography.sectionTitle(context),
        ),
        const SizedBox(height: 4),
        Text(
          'Each page opens with moments that already line up.',
          style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
            color: VoiceMemoryColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 272,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: widget.templates.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              final template = widget.templates[index];
              final draft = ArchiveTemplateMaterializer.materialize(
                template,
                now: widget.now,
              );
              return _TemplateCard(
                draft: draft,
                opening: _openingId == template.id,
                onOpen: () => unawaited(_open(template)),
                onViewEvidence: widget.onViewEvidence == null
                    ? null
                    : () => widget.onViewEvidence!(draft),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.draft,
    required this.opening,
    required this.onOpen,
    required this.onViewEvidence,
  });

  final ArchiveTemplateDraft draft;
  final bool opening;
  final VoidCallback onOpen;
  final VoidCallback? onViewEvidence;

  @override
  Widget build(BuildContext context) {
    final template = draft.template;
    final pattern = draft.pattern;
    return SizedBox(
      width: 260,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: VoiceMemoryColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: VoiceMemoryColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: InkWell(
                  key: Key('archive_template_card_${template.id}'),
                  onTap: opening ? null : onOpen,
                  borderRadius: BorderRadius.circular(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                          color: VoiceMemoryColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        template.pageBody,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: VoiceMemoryColors.textSecondary,
                        ),
                      ),
                      if (pattern != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          pattern.statement,
                          key: Key('archive_template_pattern_${template.id}'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                            color: VoiceMemoryColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${pattern.evidenceCount} moments line up',
                          style: const TextStyle(
                            fontSize: 12,
                            color: VoiceMemoryColors.textSecondary,
                          ),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        opening ? 'Saving…' : 'Open in editor',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: VoiceMemoryColors.primaryIndigo,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (pattern != null)
                ViewEvidenceInlineLink(
                  entryIds: draft.evidenceEntryIds,
                  surface: 'archive_template_card',
                  claimContext: pattern.statement,
                  onViewEvidence: onViewEvidence,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
