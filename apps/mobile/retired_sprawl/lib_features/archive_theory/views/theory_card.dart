import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/archive_theory/theory_tracker_models.dart';
import 'package:archiveme_mobile/features/archive_theory/views/citation_badge.dart';
import 'package:archiveme_mobile/features/archive_theory/views/theory_page_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

class TheoryCard extends StatefulWidget {
  const TheoryCard({
    required this.theory,
    super.key,
    this.defaultExpanded = false,
    this.onCitationTap,
    this.onConnectionMapTap,
    this.onXRayTap,
    this.showXRay = false,
  });

  final TrackedTheory theory;
  final bool defaultExpanded;
  final CitationPlaybackCallback? onCitationTap;
  final VoidCallback? onConnectionMapTap;
  final VoidCallback? onXRayTap;
  final bool showXRay;

  @override
  State<TheoryCard> createState() => _TheoryCardState();
}

class _TheoryCardState extends State<TheoryCard> {
  late bool _expanded = widget.defaultExpanded;
  TheoryFeedbackReaction? _reaction;
  var _saved = false;

  @override
  Widget build(BuildContext context) {
    final theory = widget.theory;

    return Container(
      key: Key('theory_card_${theory.id}'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
          color: AppColors.surfaceAlt.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warmBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            theory.statement,
            style: ArchiveMobileTypography.listTitle(context),
          ),
          if (theory.resolutionNote != null) ...[
            const SizedBox(height: 6),
            Text(
              theory.resolutionNote!,
              style: ArchiveMobileTypography.explanationBody(context).copyWith(
                color: AppColors.warning,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${TheoryPageCopy.confidenceLabel}: ${theory.confidence}%'
            '${theory.previousConfidence != null ? ' (${theory.previousConfidence}% → ${theory.confidence}%)' : ''}',
            style: ArchiveMobileTypography.responsiveHelper(context),
          ),
          if (widget.onConnectionMapTap != null &&
              _hasConnectionGraph(theory)) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: Key('theory_connection_map_button_${theory.id}'),
                onPressed: widget.onConnectionMapTap,
                icon: const Icon(Icons.hub_outlined, size: 18),
                label: const Text('Connection map'),
              ),
            ),
          ],
          if (widget.showXRay && theory.inspection != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: Key('theory_xray_button_${theory.id}'),
                onPressed: widget.onXRayTap,
                icon: const Icon(Icons.radar, size: 18),
                label: const Text('X-Ray'),
              ),
            ),
          ],
          if (theory.whatChanged.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              TheoryPageCopy.whatChangedLabel,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            ...theory.whatChanged.map(
              (line) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  line,
                  style: ArchiveMobileTypography.explanationBody(context).copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Text(_expanded ? TheoryPageCopy.hideEvidence : TheoryPageCopy.showEvidence),
          ),
          if (_expanded) ...[
            const Divider(),
            if (theory.supportingEvidence.isNotEmpty) ...[
              Text(
                TheoryPageCopy.supportingLabel,
                style: ArchiveMobileTypography.cardLabel(context),
              ),
              ...theory.supportingEvidence.map(_quote),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(
              TheoryPageCopy.yourRead,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: TheoryFeedbackReaction.values.map((option) {
                final selected = _reaction == option;
                return ChoiceChip(
                  label: Text(TheoryPageCopy.feedbackLabels[option] ?? option.name),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      _reaction = option;
                      _saved = true;
                    });
                  },
                );
              }).toList(),
            ),
            if (_saved)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  TheoryPageCopy.feedbackSaved,
                  style: ArchiveMobileTypography.responsiveHelper(context),
                ),
              ),
          ],
        ],
      ),
    );
  }

  bool _hasConnectionGraph(TrackedTheory theory) {
    if (theory.supportingEvidence.isNotEmpty ||
        theory.contradictingEvidence.isNotEmpty) {
      return true;
    }
    final chunks = theory.inspection?.retrievedChunks;
    return chunks != null && chunks.isNotEmpty;
  }

  Widget _quote(TheoryEvidenceQuote quote) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  quote.dateLabel,
                  style: ArchiveMobileTypography.responsiveHelper(context),
                ),
              ),
              if (widget.onCitationTap != null)
                CitationBadge(
                  quote: quote,
                  onTap: widget.onCitationTap!,
                  compact: true,
                ),
            ],
          ),
          Text(
            '“${quote.quote}”',
            style: ArchiveMobileTypography.explanationBody(context).copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}