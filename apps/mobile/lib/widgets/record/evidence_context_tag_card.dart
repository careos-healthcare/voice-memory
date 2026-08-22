import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_context.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// One optional context tag after a save — a single light question, never a
/// form. Skipping is always equal to tagging; nothing is required and the
/// card never returns. One tag only, picked from a fixed short list.
class EvidenceContextTagCard extends StatefulWidget {
  const EvidenceContextTagCard({
    required this.onSaveTag, required this.onSkip, super.key,
  });

  /// Called with the single chosen tag.
  final ValueChanged<PressureContext> onSaveTag;

  final VoidCallback onSkip;

  static const String title = 'Add context?';
  static const String helperLine =
      'This helps ArchiveMe connect future evidence.';
  static const String skipLabel = 'Skip';
  static const String saveLabel = 'Save context';

  /// The short fixed tag list — no taxonomy, no custom tags.
  static const List<PressureContext> tags = [
    PressureContext.work,
    PressureContext.family,
    PressureContext.money,
    PressureContext.health,
    PressureContext.stopping,
    PressureContext.deadline,
    PressureContext.people,
    PressureContext.energy,
  ];

  @override
  State<EvidenceContextTagCard> createState() => _EvidenceContextTagCardState();
}

class _EvidenceContextTagCardState extends State<EvidenceContextTagCard> {
  PressureContext? _selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('evidence_context_tag_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF6F5FA),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            EvidenceContextTagCard.title,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            EvidenceContextTagCard.helperLine,
            style: ArchiveMobileTypography.responsiveHelper(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final tag in EvidenceContextTagCard.tags)
                ChoiceChip(
                  key: Key('evidence_context_tag_${tag.id}'),
                  label: Text(tag.label),
                  selected: _selected == tag,
                  onSelected: (selected) =>
                      setState(() => _selected = selected ? tag : null),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                key: const Key('evidence_context_tag_skip'),
                onPressed: widget.onSkip,
                child: const Text(EvidenceContextTagCard.skipLabel),
              ),
              FilledButton(
                key: const Key('evidence_context_tag_save'),
                // Theme FilledButtons default to full width; override here so
                // this action can sit beside Skip inside a Wrap on narrow screens.
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                ),
                // Disabled until exactly one tag is chosen — never demanded.
                onPressed: _selected == null
                    ? null
                    : () => widget.onSaveTag(_selected!),
                child: const Text(
                  EvidenceContextTagCard.saveLabel,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}