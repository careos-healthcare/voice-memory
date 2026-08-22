import 'package:archiveme_mobile/features/evidence_artifact/domain/evidence_proof_models.dart';
import 'package:archiveme_mobile/features/evidence_artifact/evidence_artifact_copy.dart';
import 'package:archiveme_mobile/features/evidence_artifact/widgets/evidence_share_card.dart';
import 'package:archiveme_mobile/features/pattern_match_quality/pattern_match_quality_copy.dart';
import 'package:archiveme_mobile/features/pattern_match_quality/pattern_match_quality_model.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Interactive proof card — occurrence math, confidence band, and citation trail.
class EvidenceProofArtifactView extends StatefulWidget {
  const EvidenceProofArtifactView({
    required this.artifact, super.key,
    this.openShareOnLaunch = false,
  });

  final EvidenceProofArtifact artifact;
  final bool openShareOnLaunch;

  @override
  State<EvidenceProofArtifactView> createState() =>
      _EvidenceProofArtifactViewState();
}

class _EvidenceProofArtifactViewState extends State<EvidenceProofArtifactView> {
  bool _redactQuotes = false;
  bool _sharing = false;
  final GlobalKey<State<StatefulWidget>> _shareBoundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.openShareOnLaunch) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _shareProofCard());
    }
  }

  Future<void> _shareProofCard() async {
    if (_sharing) return;
    setState(() => _sharing = true);

    await Future<void>.delayed(const Duration(milliseconds: 120));

    try {
      await EvidenceShareCard.sharePngViaSheet(
        boundaryKey: _shareBoundaryKey,
        artifact: widget.artifact,
      );
    } catch (_, stackTrace) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not share proof card.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final artifact = widget.artifact;
    final dateFormat = DateFormat('EEE, MMM d · h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text(EvidenceArtifactCopy.screenTitle),
        actions: [
          IconButton(
            key: const Key('evidence_proof_share_button'),
            tooltip: EvidenceArtifactCopy.shareProofCard,
            onPressed: _sharing ? null : _shareProofCard,
            icon: _sharing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_outlined),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _buildInteractiveCard(artifact, dateFormat),
              const SizedBox(height: AppSpacing.lg),
              SwitchListTile(
                key: const Key('evidence_proof_redact_toggle'),
                contentPadding: EdgeInsets.zero,
                title: const Text(EvidenceArtifactCopy.redactQuotes),
                subtitle: const Text(EvidenceArtifactCopy.redactQuotesHint),
                value: _redactQuotes,
                onChanged: (value) => setState(() => _redactQuotes = value),
              ),
            ],
          ),
          Positioned(
            left: -2000,
            top: 0,
            child: EvidenceShareCard(
              exportKey: _shareBoundaryKey,
              artifact: artifact,
              redactQuotes: _redactQuotes,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveCard(
    EvidenceProofArtifact artifact,
    DateFormat dateFormat,
  ) {
    final bandPalette = _paletteFor(artifact.confidenceBand);

    return Container(
      width: double.infinity,
      decoration: VoiceMemoryCards.standard(),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              artifact.subjectTitle,
              style: VoiceMemoryTypography.cardTitleStyle().copyWith(
                fontSize: 22,
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                _FrequencyBadge(label: artifact.stats.frequencyBadgeLabel),
                _ConfidenceBadge(palette: bandPalette),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              artifact.stats.timespanLabel,
              style: VoiceMemoryTypography.bodyStyle().copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (artifact.stats.totalFrequency > 1) ...[
              const SizedBox(height: 4),
              Text(
                '${EvidenceArtifactCopy.densityLabel}: '
                '${artifact.stats.occurrenceDensityPerWeek} '
                '${EvidenceArtifactCopy.densityUnit}',
                style: VoiceMemoryTypography.secondaryStyle(),
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            Text(
              PatternMatchQualityCopy.explanationFor(artifact.confidenceBand),
              style: VoiceMemoryTypography.secondaryStyle().copyWith(
                height: 1.4,
              ),
            ),
            if (artifact.confidencePercent != null) ...[
              const SizedBox(height: 4),
              Text(
                'Archive confidence: ${artifact.confidencePercent}%',
                style: VoiceMemoryTypography.secondaryStyle(),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text(
              EvidenceArtifactCopy.timelineSection,
              style: VoiceMemoryTypography.sectionLabelStyle(),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (!artifact.hasCitations)
              Text(
                EvidenceArtifactCopy.noCitations,
                style: VoiceMemoryTypography.secondaryStyle(),
              )
            else
              for (var i = 0; i < artifact.citations.length; i++)
                _TimelineEntry(
                  citation: artifact.citations[i],
                  dateLabel: dateFormat.format(artifact.citations[i].recordedAt),
                  redactQuotes: _redactQuotes,
                  showDivider: i < artifact.citations.length - 1,
                  onOpenEntry: () =>
                      context.push('/entry/${artifact.citations[i].entryId}'),
                ),
          ],
        ),
      ),
    );
  }
}

class _FrequencyBadge extends StatelessWidget {
  const _FrequencyBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: VoiceMemoryColors.primaryIndigo.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: VoiceMemoryColors.primaryIndigo.withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        label,
        style: VoiceMemoryTypography.bodyStyle(
          color: VoiceMemoryColors.primaryIndigo,
        ).copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge({required this.palette});

  final _BandPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        palette.label,
        style: VoiceMemoryTypography.bodyStyle(
          color: palette.foreground,
        ).copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({
    required this.citation,
    required this.dateLabel,
    required this.redactQuotes,
    required this.showDivider,
    required this.onOpenEntry,
  });

  final EvidenceProofCitation citation;
  final String dateLabel;
  final bool redactQuotes;
  final bool showDivider;
  final VoidCallback onOpenEntry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  dateLabel,
                  style: VoiceMemoryTypography.secondaryStyle().copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ActionChip(
                key: Key('evidence_proof_entry_chip_${citation.entryId}'),
                label: const Text(EvidenceArtifactCopy.openEntry),
                onPressed: onOpenEntry,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            redactQuotes
                ? EvidenceArtifactCopy.redactedQuote
                : citation.quote,
            style: VoiceMemoryTypography.bodyStyle().copyWith(
              height: 1.45,
              fontStyle:
                  redactQuotes ? FontStyle.italic : FontStyle.normal,
              color: redactQuotes
                  ? VoiceMemoryColors.textSecondary
                  : VoiceMemoryColors.textPrimary,
            ),
          ),
          if (showDivider)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Divider(color: VoiceMemoryColors.border.withValues(alpha: 0.6)),
            ),
        ],
      ),
    );
  }
}

class _BandPalette {
  const _BandPalette({
    required this.label,
    required this.background,
    required this.border,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color border;
  final Color foreground;
}

_BandPalette _paletteFor(PatternMatchConfidenceBand band) {
  return switch (band) {
    PatternMatchConfidenceBand.weak => const _BandPalette(
      label: 'Weak',
      background: VoiceMemoryColors.surfaceSecondary,
      border: VoiceMemoryColors.border,
      foreground: VoiceMemoryColors.textSecondary,
    ),
    PatternMatchConfidenceBand.emerging => _BandPalette(
      label: 'Emerging',
      background: VoiceMemoryColors.discoveryGoldBackground,
      border: VoiceMemoryColors.blindSpotAmber.withValues(alpha: 0.45),
      foreground: VoiceMemoryColors.blindSpotAmber,
    ),
    PatternMatchConfidenceBand.solid => _BandPalette(
      label: 'Solid',
      background: VoiceMemoryColors.beliefIndigo.withValues(alpha: 0.1),
      border: VoiceMemoryColors.beliefIndigo.withValues(alpha: 0.35),
      foreground: VoiceMemoryColors.beliefIndigo,
    ),
    PatternMatchConfidenceBand.strong => _BandPalette(
      label: 'Strong',
      background: VoiceMemoryColors.success.withValues(alpha: 0.12),
      border: VoiceMemoryColors.success.withValues(alpha: 0.4),
      foreground: VoiceMemoryColors.success,
    ),
  };
}