import 'package:flutter/material.dart';

import '../features/archive_state_delta/archive_state_snapshot.dart';
import '../features/belief_evolution/belief_evolution_models.dart';
import '../models/journal_entry.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';
import 'belief_evolution_timeline.dart';

/// Archive section — loads evolution from journal + persists locally.
class BeliefEvolutionSection extends StatefulWidget {
  const BeliefEvolutionSection({
    super.key,
    required this.entries,
    this.baseline,
  });

  final List<JournalEntry> entries;
  final ArchiveStateSnapshot? baseline;

  @override
  State<BeliefEvolutionSection> createState() => _BeliefEvolutionSectionState();
}

class _BeliefEvolutionSectionState extends State<BeliefEvolutionSection> {
  BeliefEvolutionTimeline? _timeline;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(BeliefEvolutionSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entries != widget.entries ||
        oldWidget.baseline != widget.baseline) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final service = AppServices.instance.beliefEvolution;
    final state = await service.refreshFromEntries(
      entries: widget.entries,
      legacySnapshot: widget.baseline,
    );
    final timeline = service.buildTimeline(
      state: state,
      entries: widget.entries,
    );
    if (!mounted) return;
    setState(() {
      _timeline = timeline;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
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

    final timeline = _timeline;
    if (timeline == null || timeline.isEmpty) {
      return const SizedBox.shrink();
    }

    final first = timeline.firstBelief;
    final current = timeline.currentBelief;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'BELIEF EVOLUTION',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 0.8,
            color: AppTheme.muted,
          ),
        ),
        const SizedBox(height: 8),
        if (first != null && current != null)
          Text(
            timeline.hasEvolution
                ? 'From “${_truncate(first.beliefText)}” to “${_truncate(current.beliefText)}”.'
                : 'Tracking your working belief and supporting recordings.',
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        const SizedBox(height: 16),
        BeliefEvolutionTimelineWidget(timeline: timeline),
      ],
    );
  }

  String _truncate(String text) {
    if (text.length <= 48) return text;
    return '${text.substring(0, 48).trim()}…';
  }
}
