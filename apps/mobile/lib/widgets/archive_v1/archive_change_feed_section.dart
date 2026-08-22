import 'package:archiveme_mobile/features/archive_change_feed/archive_change_feed_copy.dart';
import 'package:archiveme_mobile/features/archive_change_feed/archive_change_feed_models.dart';
import 'package:archiveme_mobile/features/archive_discovery_share/archive_discovery_share_moments.dart';
import 'package:archiveme_mobile/features/evidence_trail/evidence_trail_builder.dart';
import 'package:archiveme_mobile/features/evidence_trail/evidence_trail_navigation.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:archiveme_mobile/widgets/archive_discovery_share/share_discovery_button.dart';
import 'package:archiveme_mobile/widgets/evidence_trail/why_am_i_seeing_this_button.dart';
import 'package:flutter/material.dart';
import 'dart:async';

/// What changed since the last archive review.
class ArchiveChangeFeedSection extends StatelessWidget {
  const ArchiveChangeFeedSection({
    required this.feed, required this.entries, super.key,
  });

  final ArchiveChangeFeedView feed;
  final List<JournalEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (!feed.hasBaseline) {
      return _panel(
        child: Text(
          feed.emptyMessage ?? ArchiveChangeFeedCopy.noBaseline,
          style: const TextStyle(color: AppTheme.muted, height: 1.45),
        ),
      );
    }

    if (!feed.hasChanges) {
      return _panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _title(),
            if (feed.newReflectionCount > 0) ...[
              const SizedBox(height: 8),
              Text(
                '${ArchiveChangeFeedCopy.newReflectionsLabel}: ${feed.newReflectionCount}',
                style: const TextStyle(color: AppTheme.muted, fontSize: 13),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              feed.emptyMessage ?? ArchiveChangeFeedCopy.noChanges,
              style: const TextStyle(color: AppTheme.muted, height: 1.45),
            ),
          ],
        ),
      );
    }

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(),
          if (feed.newReflectionCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              '${ArchiveChangeFeedCopy.newReflectionsLabel}: ${feed.newReflectionCount}',
              style: const TextStyle(color: AppTheme.muted, fontSize: 13),
            ),
          ],
          const SizedBox(height: 14),
          if (feed.beliefsStrengthened.isNotEmpty)
            _subsection(
              ArchiveChangeFeedCopy.beliefsStrengthenedTitle,
              feed.beliefsStrengthened
                  .map((row) => _beliefTile(context, row))
                  .toList(),
            ),
          if (feed.beliefsWeakened.isNotEmpty)
            _subsection(
              ArchiveChangeFeedCopy.beliefsWeakenedTitle,
              feed.beliefsWeakened
                  .map((row) => _beliefTile(context, row))
                  .toList(),
            ),
          if (feed.contradictionsAppeared.isNotEmpty)
            _subsection(
              ArchiveChangeFeedCopy.contradictionsAppearedTitle,
              feed.contradictionsAppeared
                  .map((row) => _contradictionTile(context, row))
                  .toList(),
            ),
          if (feed.contradictionsResolved.isNotEmpty)
            _subsection(
              ArchiveChangeFeedCopy.contradictionsResolvedTitle,
              feed.contradictionsResolved
                  .map((row) => _contradictionTile(context, row))
                  .toList(),
            ),
          if (feed.themesIncreasing.isNotEmpty)
            _subsection(
              ArchiveChangeFeedCopy.themesIncreasingTitle,
              feed.themesIncreasing
                  .map((row) => _themeTile(context, row))
                  .toList(),
            ),
          if (feed.themesDecreasing.isNotEmpty)
            _subsection(
              ArchiveChangeFeedCopy.themesDecreasingTitle,
              feed.themesDecreasing
                  .map((row) => _themeTile(context, row))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _title() {
    return Text(
      ArchiveChangeFeedCopy.sectionTitle,
      style: VoiceMemoryTypography.sectionLabelStyle(
        
      ),
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VoiceMemoryColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VoiceMemoryColors.border),
      ),
      child: child,
    );
  }

  Widget _subsection(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: AppTheme.foreground,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _beliefTile(BuildContext context, ArchiveChangeBeliefRow row) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"${row.statement}"',
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${ArchiveChangeFeedCopy.confidenceLabel}: '
            '${row.confidenceBefore}% → ${row.confidenceNow}%',
            style: const TextStyle(color: AppTheme.muted, fontSize: 12),
          ),
          Text(
            '${ArchiveChangeFeedCopy.evidenceLabel}: ${row.evidenceCount} · '
            '${ArchiveChangeFeedCopy.counterEvidenceLabel}: ${row.counterEvidenceCount}',
            style: const TextStyle(color: AppTheme.muted, fontSize: 12),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: WhyAmISeeingThisButton(
              compact: true,
              onPressed: () {
                final payload = buildEvidenceTrailForChangeBelief(
                  row: row,
                  entries: entries,
                );
                unawaited(showEvidenceTrailSheet(
                  context,
                  payload: payload,
                  surface: 'change_feed_belief',
                ));
              },
            ),
          ),
          if (ArchiveDiscoveryShareMoments.fromBeliefWeakened(row)
              case final shareCard?) ...[
            ShareDiscoveryButton(
              card: shareCard,
              surface: 'archive_change_feed_belief',
            ),
          ],
        ],
      ),
    );
  }

  Widget _contradictionTile(
    BuildContext context,
    ArchiveChangeContradictionRow row,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(row.youSay, style: const TextStyle(fontSize: 13, height: 1.4)),
          Text(
            'vs ${row.but}',
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppTheme.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${ArchiveChangeFeedCopy.evidenceLabel}: ${row.evidenceCount} recordings · '
            '${ArchiveChangeFeedCopy.confidenceLabel}: ${row.confidenceScore}%',
            style: const TextStyle(color: AppTheme.muted, fontSize: 12),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: WhyAmISeeingThisButton(
              compact: true,
              onPressed: () {
                final payload = buildEvidenceTrailForChangeContradiction(
                  row: row,
                  entries: entries,
                );
                unawaited(showEvidenceTrailSheet(
                  context,
                  payload: payload,
                  surface: 'change_feed_contradiction',
                ));
              },
            ),
          ),
          if (ArchiveDiscoveryShareMoments.fromChangeContradiction(row)
              case final shareCard?) ...[
            ShareDiscoveryButton(
              card: shareCard,
              surface: 'archive_change_feed_contradiction',
            ),
          ],
        ],
      ),
    );
  }

  Widget _themeTile(BuildContext context, ArchiveChangeThemeRow row) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row.label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            ArchiveChangeFeedCopy.mentionTrendLabel(row.mentionSeries),
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.foreground,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          _MentionTrendChart(series: row.mentionSeries),
          const SizedBox(height: 4),
          Text(
            'At last review: ${row.mentionsAtReview} · Now: ${row.mentionsNow} · '
            'New since review: ${row.newMentionsSinceReview}',
            style: const TextStyle(color: AppTheme.muted, fontSize: 12),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: WhyAmISeeingThisButton(
              compact: true,
              onPressed: () {
                final payload = buildEvidenceTrailForChangeTheme(
                  row: row,
                  entries: entries,
                );
                unawaited(showEvidenceTrailSheet(
                  context,
                  payload: payload,
                  surface: 'change_feed_theme',
                ));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MentionTrendChart extends StatelessWidget {
  const _MentionTrendChart({required this.series});

  final List<int> series;

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) return const SizedBox.shrink();
    final max = series.reduce((a, b) => a > b ? a : b);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < series.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: max == 0
                    ? 4.0
                    : (series[i] / max * 36).clamp(6.0, 36.0),
                decoration: BoxDecoration(
                  color: VoiceMemoryColors.primaryIndigo.withValues(
                    alpha: 0.75,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${series[i]}',
                style: const TextStyle(fontSize: 11, color: AppTheme.muted),
              ),
            ],
          ),
        ],
      ],
    );
  }
}