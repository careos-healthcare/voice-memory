import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/archive_evidence/archive_evidence.dart';
import '../models/journal_entry.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';
import '../widgets/archive_mobile_page_template.dart';
import '../widgets/belief_dossier_compact.dart';

/// Deferred archive tools — not linked from production navigation (see [ArchiveToolRoutes]).
class ArchiveToolScreen extends StatefulWidget {
  const ArchiveToolScreen({super.key, required this.tool});

  final String tool;

  @override
  State<ArchiveToolScreen> createState() => _ArchiveToolScreenState();
}

class _ToolCopy {
  const _ToolCopy({
    required this.eyebrow,
    required this.title,
    required this.lead,
  });

  final String eyebrow;
  final String title;
  final String lead;
}

const _toolCopy = <String, _ToolCopy>{
  'belief-survival': _ToolCopy(
    eyebrow: 'Archive',
    title: 'Belief survival',
    lead:
        'How your working belief has held up as new reflections arrive. '
        'Metrics come from your recorded transcripts on this device.',
  ),
  'accuracy': _ToolCopy(
    eyebrow: 'Archive',
    title: 'Archive accuracy',
    lead:
        'Whether your archive’s read on a belief has matched what happened next. '
        'Full accuracy tracking is not available on mobile yet.',
  ),
  'contradictions': _ToolCopy(
    eyebrow: 'Archive',
    title: 'Contradiction history',
    lead:
        'Moments when new reflections pushed against what the archive believed. '
        'Use Pattern Review for the deepest contradiction read on device.',
  ),
};

class _ArchiveToolScreenState extends State<ArchiveToolScreen> {
  List<JournalEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await AppServices.instance.journal.loadAll();
    if (mounted) setState(() => _entries = entries);
  }

  @override
  Widget build(BuildContext context) {
    final copy = _toolCopy[widget.tool];
    if (copy == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: const Text('Archive'),
        ),
        body: const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'This archive view is not available.',
              style: TextStyle(color: AppTheme.muted),
            ),
          ),
        ),
      );
    }

    final body = switch (widget.tool) {
      'belief-survival' => _beliefSurvivalBody(),
      'accuracy' => _accuracyBody(),
      'contradictions' => _contradictionsBody(),
      _ => const SizedBox.shrink(),
    };

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(copy.title, style: const TextStyle(fontSize: 16)),
      ),
      body: SafeArea(
        child: ArchiveMobilePageTemplate(
          onRefresh: _load,
          eyebrow: copy.eyebrow,
          title: copy.title,
          lead: copy.lead,
          mainContent: body,
          actionArea: TextButton(
            onPressed: () => context.go('/archive-belief'),
            child: const Text(
              'Back to Archive',
              style: TextStyle(color: AppTheme.muted),
            ),
          ),
        ),
      ),
    );
  }

  Widget _beliefSurvivalBody() {
    final eligible = archiveEligibleEvidenceEntries(_entries);
    final evidenceCount = eligible.length;

    if (!archiveHasMinimumEvidence(_entries)) {
      final need = archiveMinEvidenceReflections - evidenceCount;
      return Text(
        need > 0
            ? '$evidenceCount of $archiveMinEvidenceReflections reflections with enough '
                  'transcript detail to track belief survival. Record $need more to continue.'
            : 'Add reflections with at least $archiveMinTranscriptChars characters of '
                  'transcript before belief survival can be shown.',
        style: const TextStyle(color: AppTheme.muted, height: 1.45),
      );
    }

    final belief = archiveBeliefFromReflections(_entries);
    final first = eligible.first.createdAt.toLocal();
    final last = eligible.last.createdAt.toLocal();
    final spanDays = last.difference(first).inDays + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (belief != null) BeliefDossierCompact(beliefText: belief),
        const SizedBox(height: 12),
        Text(
          '$evidenceCount reflection${evidenceCount == 1 ? '' : 's'} support this belief '
          'over $spanDays day${spanDays == 1 ? '' : 's'} on this device.',
          style: const TextStyle(color: AppTheme.muted, height: 1.45),
        ),
        const SizedBox(height: 8),
        const Text(
          'Contradiction survival and confidence movement are tracked on the full archive '
          'experience; this device shows reflection-backed counts only.',
          style: TextStyle(color: AppTheme.muted, height: 1.45, fontSize: 13),
        ),
      ],
    );
  }

  Widget _accuracyBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Archive accuracy is not computed on mobile yet.',
          style: TextStyle(color: AppTheme.muted, height: 1.45),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => context.go('/archive-belief'),
          child: const Text('View archive home'),
        ),
      ],
    );
  }

  Widget _contradictionsBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'A full contradiction timeline is not on mobile yet. Pattern Review surfaces '
          'the strongest tension the archive can support from your reflections.',
          style: TextStyle(color: AppTheme.muted, height: 1.45),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => context.go('/blind-spots'),
          child: const Text('Open pattern review'),
        ),
      ],
    );
  }
}
