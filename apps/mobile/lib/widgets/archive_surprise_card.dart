import 'package:archiveme_mobile/design/archive_mobile_spacing.dart';
import 'package:archiveme_mobile/features/archive_explanations/archive_explanation_navigation.dart';
import 'package:archiveme_mobile/features/surprise_engine/surprise_analytics.dart';
import 'package:archiveme_mobile/features/surprise_engine/surprise_coordinator.dart';
import 'package:archiveme_mobile/features/surprise_engine/surprise_copy.dart';
import 'package:archiveme_mobile/features/surprise_engine/surprise_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:archiveme_mobile/widgets/archive_evidence_panel.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';

/// Archive home hero — one surprise with Why, Evidence, and Timeline.
class ArchiveSurpriseCard extends StatefulWidget {
  const ArchiveSurpriseCard({
    required this.surprise, required this.entries, super.key,
    this.onDismissed,
  });

  final ArchiveSurprise surprise;
  final List<JournalEntry> entries;
  final VoidCallback? onDismissed;

  @override
  State<ArchiveSurpriseCard> createState() => _ArchiveSurpriseCardState();
}

class _ArchiveSurpriseCardState extends State<ArchiveSurpriseCard> {
  var _evidenceOpen = false;

  List<JournalEntry> get _evidenceEntries {
    final byId = {for (final e in widget.entries) e.id: e};
    return [
      for (final id in widget.surprise.evidenceIds)
        if (byId[id] != null) byId[id]!,
    ];
  }

  Future<void> _openWhy() async {
    await const SurpriseCoordinator().markOpened(widget.surprise);
    if (!mounted) return;
    openArchiveExplanation(
      context,
      ref: widget.surprise.insightRef,
      askCitedEntryIds: widget.surprise.evidenceIds,
    );
  }

  void _openTimeline() {
    final s = widget.surprise;
    if (s.type == SurpriseType.newLifeChapter &&
        s.chapterId != null &&
        s.chapterId!.isNotEmpty) {
      unawaited(context.push('/discover-yourself/chapter/${s.chapterId}'));
      return;
    }
    unawaited(context.push('/discover-yourself'));
  }

  Future<void> _share() async {
    await SurpriseAnalytics.shared(widget.surprise);
    final text = '${widget.surprise.headline}\n\n${widget.surprise.why}';
    await Share.share(text);
  }

  Future<void> _dismiss() async {
    await const SurpriseCoordinator().markIgnored(widget.surprise);
    widget.onDismissed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final surprise = widget.surprise;

    return Container(
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  SurpriseCopy.sectionHeadline,
                  style: VoiceMemoryTypography.sectionLabelStyle(
                    accent: VoiceMemoryColors.discoveryGold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                color: VoiceMemoryColors.textSecondary,
                tooltip: 'Not now',
                onPressed: _dismiss,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            SurpriseCopy.promptQuestion,
            style: VoiceMemoryTypography.metadataStyle(
              color: VoiceMemoryColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            surprise.headline,
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              TextButton(onPressed: _openWhy, child: const Text('Why?')),
              if (_evidenceEntries.isNotEmpty)
                TextButton(
                  onPressed: () =>
                      setState(() => _evidenceOpen = !_evidenceOpen),
                  child: Text(
                    _evidenceOpen ? 'Hide Evidence' : 'Show Evidence',
                  ),
                ),
              if (surprise.supportsTimeline)
                TextButton(
                  onPressed: _openTimeline,
                  child: const Text('Timeline'),
                ),
              TextButton(onPressed: _share, child: const Text('Share')),
            ],
          ),
          if (_evidenceOpen && _evidenceEntries.isNotEmpty) ...[
            const SizedBox(height: ArchiveMobileSpacing.sm),
            ArchiveEvidencePanel(
              entries: _evidenceEntries,
              analyticsContext: 'surprise:${surprise.type.name}',
              initiallyExpanded: true,
            ),
          ],
        ],
      ),
    );
  }
}