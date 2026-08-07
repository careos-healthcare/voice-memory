import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/archive_evidence/archive_evidence.dart';
import '../features/archive_narrative/archive_narrative_engine.dart';
import '../features/archive_narrative/narrative_summary_models.dart';
import '../models/journal_entry.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';

/// Archive section — evidence-backed "Your Story So Far" narrative.
class YourStorySoFarSection extends StatefulWidget {
  const YourStorySoFarSection({
    super.key,
    required this.entries,
    this.currentBelief,
    this.themeBaseline,
  });

  final List<JournalEntry> entries;
  final String? currentBelief;
  final Map<String, int>? themeBaseline;

  @override
  State<YourStorySoFarSection> createState() => _YourStorySoFarSectionState();
}

class _YourStorySoFarSectionState extends State<YourStorySoFarSection> {
  NarrativeSummary? _narrative;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(YourStorySoFarSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entries != widget.entries ||
        oldWidget.currentBelief != widget.currentBelief) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!archiveHasMinimumEvidence(widget.entries)) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);
    final evolutionService = AppServices.instance.beliefEvolution;
    final evolutionState = await evolutionService.refreshFromEntries(
      entries: widget.entries,
    );
    final timeline = evolutionService.buildTimeline(
      state: evolutionState,
      entries: widget.entries,
    );

    final narrative = const ArchiveNarrativeEngine().build(
      entries: widget.entries,
      currentBelief: widget.currentBelief,
      themeBaseline: widget.themeBaseline,
      beliefEvolution: timeline,
    );

    if (!mounted) return;
    setState(() {
      _narrative = narrative;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!archiveHasMinimumEvidence(widget.entries)) {
      return const SizedBox.shrink();
    }
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final narrative = _narrative;
    if (narrative == null || !narrative.hasNarrative) {
      return const SizedBox.shrink();
    }

    return _YourStorySoFarCard(narrative: narrative);
  }
}

class _YourStorySoFarCard extends StatefulWidget {
  const _YourStorySoFarCard({required this.narrative});

  final NarrativeSummary narrative;

  @override
  State<_YourStorySoFarCard> createState() => _YourStorySoFarCardState();
}

class _YourStorySoFarCardState extends State<_YourStorySoFarCard> {
  bool _evidenceExpanded = false;

  @override
  Widget build(BuildContext context) {
    final narrative = widget.narrative;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'YOUR STORY SO FAR',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 0.8,
            color: AppTheme.muted,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'A narrative drawn only from your recordings — expand to review the evidence.',
          style: TextStyle(color: AppTheme.muted, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 14),
        Material(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  narrative.summary,
                  style: const TextStyle(
                    color: AppTheme.foreground,
                    fontSize: 15,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (narrative.supportingThemes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Themes: ${narrative.supportingThemes.join(' · ')}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                  ),
                ],
                const SizedBox(height: 12),
                InkWell(
                  onTap: () =>
                      setState(() => _evidenceExpanded = !_evidenceExpanded),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          _evidenceExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 20,
                          color: AppTheme.muted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _evidenceExpanded ? 'Hide evidence' : 'Show evidence',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_evidenceExpanded) ...[
                  const SizedBox(height: 12),
                  if (narrative.supportingBeliefs.isNotEmpty) ...[
                    const Text(
                      'Supporting beliefs',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 0.6,
                        color: AppTheme.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final belief in narrative.supportingBeliefs)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '"$belief"',
                          style: const TextStyle(
                            color: AppTheme.muted,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ),
                  ],
                  if (narrative.supportingRecordingIds.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Recordings',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 0.6,
                        color: AppTheme.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final id in narrative.supportingRecordingIds)
                          OutlinedButton(
                            onPressed: () => context.push('/entry/$id'),
                            child: Text(
                              'Recording ${narrative.supportingRecordingIds.indexOf(id) + 1}',
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
