import 'package:flutter/material.dart';

import '../features/archive_explanations/archive_explanation_navigation.dart';
import '../features/daily_discoveries/daily_discovery_models.dart';
import '../features/living_archive/living_archive_copy.dart';
import '../models/journal_entry.dart';
import '../services/product_analytics.dart';
import '../theme/voicememory_colors.dart';
import '../theme/voicememory_typography.dart';
import 'archive_evidence_panel.dart';

/// Shown on Record after a successful save — one evidence-backed archive discovery.
class ImmediateDiscoveryCard extends StatefulWidget {
  const ImmediateDiscoveryCard({
    super.key,
    required this.entries,
    this.discovery,
    this.loading = false,
  });

  final List<JournalEntry> entries;
  final DailyDiscovery? discovery;
  final bool loading;

  static const String stillLearningCopy = LivingArchiveCopy.stillLearning;

  @override
  State<ImmediateDiscoveryCard> createState() => _ImmediateDiscoveryCardState();
}

class _ImmediateDiscoveryCardState extends State<ImmediateDiscoveryCard> {
  var _evidenceOpen = false;

  List<JournalEntry> get _evidenceEntries {
    final ids = widget.discovery?.evidenceIds ?? const <String>[];
    if (ids.isEmpty) return const [];
    final byId = {for (final e in widget.entries) e.id: e};
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  bool get _hasDiscovery =>
      !widget.loading &&
      widget.discovery != null &&
      widget.discovery!.summary.trim().isNotEmpty;

  String get _headline {
    if (widget.loading) return 'Noticing what changed…';
    final d = widget.discovery;
    if (d == null) return LivingArchiveCopy.stillLearning;
    return LivingArchiveCopy.curiosityHeadlineForDailyType(d.type);
  }

  String get _bodyLine {
    if (widget.loading) return '';
    final summary = widget.discovery?.summary.trim();
    if (summary != null && summary.isNotEmpty) return summary;
    return LivingArchiveCopy.oneMoreRecording;
  }

  @override
  void didUpdateWidget(ImmediateDiscoveryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.discovery?.id != widget.discovery?.id) {
      _evidenceOpen = false;
    }
  }

  void _openWhy() {
    final d = widget.discovery;
    if (d == null) return;
    ProductAnalytics.trackStrings('immediate_discovery_why_opened', {
      'type': d.type.name,
    });
    openArchiveExplanation(
      context,
      ref: d.insightRef,
      askPrompt: d.insightRef.askPrompt,
    );
  }

  void _openEvidence() {
    if (_evidenceEntries.isEmpty) return;
    setState(() => _evidenceOpen = true);
    ProductAnalytics.trackStrings('immediate_discovery_evidence_opened', {
      'type': widget.discovery?.type.name ?? 'none',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'YOUR ARCHIVE NOTICED',
          style: VoiceMemoryTypography.sectionLabelStyle(
            accent: VoiceMemoryColors.discoveryGold,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: VoiceMemoryColors.discoveryGoldBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: VoiceMemoryColors.discoveryGoldBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.loading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    color: VoiceMemoryColors.discoveryGold,
                    backgroundColor: VoiceMemoryColors.border,
                  ),
                ),
              Text(
                _headline,
                style: VoiceMemoryTypography.cardTitleStyle().copyWith(
                  color: _hasDiscovery
                      ? VoiceMemoryColors.textPrimary
                      : VoiceMemoryColors.textSecondary,
                ),
              ),
              if (_bodyLine.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _hasDiscovery ? '“$_bodyLine”' : _bodyLine,
                  style: VoiceMemoryTypography.bodyStyle(
                    color: VoiceMemoryColors.textSecondary,
                  ).copyWith(height: 1.45),
                ),
              ],
              if (_hasDiscovery) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton(
                      onPressed: _openWhy,
                      style: TextButton.styleFrom(
                        foregroundColor: VoiceMemoryColors.primaryIndigo,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(48, 44),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Why?',
                        style: VoiceMemoryTypography.bodyStyle(
                          color: VoiceMemoryColors.primaryIndigo,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed:
                          _evidenceEntries.isEmpty ? null : _openEvidence,
                      style: TextButton.styleFrom(
                        foregroundColor: VoiceMemoryColors.primaryIndigo,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(48, 44),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Show Evidence',
                        style: VoiceMemoryTypography.bodyStyle(
                          color: VoiceMemoryColors.primaryIndigo,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
              if (_evidenceOpen && _evidenceEntries.isNotEmpty) ...[
                const SizedBox(height: 8),
                ArchiveEvidencePanel(
                  entries: _evidenceEntries,
                  analyticsContext: 'immediate_discovery',
                  initiallyExpanded: true,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
