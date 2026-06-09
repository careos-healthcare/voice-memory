import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/user_facing_date.dart';
import '../features/retention/retention_analytics.dart';
import '../models/journal_entry.dart';
import '../theme/voicememory_colors.dart';
import '../theme/voicememory_typography.dart';

/// Inline evidence list — real entries, dates, and excerpts.
class ArchiveEvidencePanel extends StatelessWidget {
  const ArchiveEvidencePanel({
    super.key,
    required this.entries,
    this.analyticsContext = 'insight',
    this.initiallyExpanded = false,
  });

  final List<JournalEntry> entries;
  final String analyticsContext;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return _ArchiveEvidencePanelBody(
      entries: entries,
      analyticsContext: analyticsContext,
      initiallyExpanded: initiallyExpanded,
    );
  }
}

class ArchiveEvidenceExpandable extends StatefulWidget {
  const ArchiveEvidenceExpandable({
    super.key,
    required this.entries,
    this.analyticsContext = 'insight',
    this.buttonLabel = 'Show Evidence',
  });

  final List<JournalEntry> entries;
  final String analyticsContext;
  final String buttonLabel;

  @override
  State<ArchiveEvidenceExpandable> createState() =>
      _ArchiveEvidenceExpandableState();
}

class _ArchiveEvidenceExpandableState extends State<ArchiveEvidenceExpandable> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton(
          onPressed: () {
            setState(() => _expanded = !_expanded);
            if (_expanded) {
              RetentionAnalytics.evidenceOpened(context: widget.analyticsContext);
            }
          },
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          child: Text(_expanded ? 'Hide Evidence' : widget.buttonLabel),
        ),
        if (_expanded)
          ArchiveEvidencePanel(
            entries: widget.entries,
            analyticsContext: widget.analyticsContext,
            initiallyExpanded: true,
          ),
      ],
    );
  }
}

class _ArchiveEvidencePanelBody extends StatelessWidget {
  const _ArchiveEvidencePanelBody({
    required this.entries,
    required this.analyticsContext,
    required this.initiallyExpanded,
  });

  final List<JournalEntry> entries;
  final String analyticsContext;
  final bool initiallyExpanded;

  static String _excerpt(JournalEntry e) {
    final t = e.transcript.trim();
    if (t.isEmpty) {
      final obs = e.reflection.concreteObservation.trim();
      if (obs.isNotEmpty) return '“$obs”';
      return '(No transcript)';
    }
    final line = t.length > 140 ? '${t.substring(0, 140)}…' : t;
    return '“$line”';
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...entries]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Semantics(
      label: 'Evidence, ${sorted.length} entries',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: VoiceMemoryColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: VoiceMemoryColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Evidence',
              style: VoiceMemoryTypography.sectionLabelStyle(
                accent: VoiceMemoryColors.primaryIndigo,
              ),
            ),
            const SizedBox(height: 8),
            for (final e in sorted.take(8))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () => context.push('/entry/${e.id}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatUserFacingDate(e.createdAt),
                        style: VoiceMemoryTypography.secondaryStyle(
                          color: VoiceMemoryColors.textSecondary,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _excerpt(e),
                        style: VoiceMemoryTypography.bodyStyle().copyWith(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Relative label for instant belief evidence bullets.
String archiveEvidenceRelativeLabel(DateTime entryDate, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  final entryDay = DateTime(
    entryDate.year,
    entryDate.month,
    entryDate.day,
  );
  final today = DateTime(clock.year, clock.month, clock.day);
  final days = today.difference(entryDay).inDays;
  if (days <= 0) return 'Entry from today';
  if (days == 1) return 'Entry from yesterday';
  return 'Entry from $days days ago';
}
