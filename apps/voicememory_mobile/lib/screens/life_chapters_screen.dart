import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/archive_evidence/archive_evidence.dart';
import '../features/life_chapters/life_chapter_engine.dart';
import '../features/life_chapters/life_chapter_models.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';
import '../widgets/pushed_screen_shell.dart';

/// Chronological life chapters inferred from archive evidence.
class LifeChaptersScreen extends StatefulWidget {
  const LifeChaptersScreen({super.key});

  @override
  State<LifeChaptersScreen> createState() => _LifeChaptersScreenState();
}

class _LifeChaptersScreenState extends State<LifeChaptersScreen> {
  LifeChapterResult? _result;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries = await AppServices.instance.journal.loadAll();
    final result = const LifeChapterEngine().build(entries: entries);
    if (!mounted) return;
    setState(() {
      _result = result;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: 'Life Chapters',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                children: [
                  const Text(
                    'LIFE CHAPTERS',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 0.9,
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _subtitle(_result!),
                    style: const TextStyle(
                      color: AppTheme.muted,
                      height: 1.45,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ..._buildBody(_result!),
                ],
              ),
            ),
    );
  }

  String _subtitle(LifeChapterResult result) {
    if (!result.hasMinimumArchiveEvidence) {
      final need =
          archiveMinEvidenceReflections - result.evidenceReflectionCount;
      return 'Record $need more reflections with enough spoken detail before '
          'the archive can group life chapters from evidence.';
    }
    if (!result.hasChapters) {
      return 'No chapters met the evidence threshold yet. Periods need at least '
          '${LifeChapterEngine.minEntriesPerChapter} recordings and a recurring theme.';
    }
    return 'Periods grouped from your recordings in chronological order — '
        'nothing invented without evidence.';
  }

  List<Widget> _buildBody(LifeChapterResult result) {
    if (!result.hasMinimumArchiveEvidence || !result.hasChapters) {
      return [
        OutlinedButton(
          onPressed: () => context.go('/record'),
          child: const Text('Record reflection'),
        ),
      ];
    }
    return result.chapters.map((c) => _ChapterCard(chapter: c)).toList();
  }
}

class _ChapterCard extends StatelessWidget {
  const _ChapterCard({required this.chapter});

  final LifeChapter chapter;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                chapter.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                chapter.dateRangeLabel,
                style: const TextStyle(fontSize: 12, color: AppTheme.muted),
              ),
              const SizedBox(height: 12),
              _labelValue('Theme summary', chapter.themeSummary),
              if (chapter.primaryBelief != null) ...[
                const SizedBox(height: 10),
                _labelValue('Key belief', '"${chapter.primaryBelief}"'),
              ],
              if (chapter.importantQuotes.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text(
                  'Evidence',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 0.6,
                    color: AppTheme.muted,
                  ),
                ),
                const SizedBox(height: 8),
                for (final q in chapter.importantQuotes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () => context.push('/entry/${q.entryId}'),
                      borderRadius: BorderRadius.circular(6),
                      child: Text(
                        '"${q.quote}"',
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final id in chapter.evidenceIds)
                    OutlinedButton(
                      onPressed: () => context.push('/entry/$id'),
                      child: Text(
                        'Recording ${chapter.evidenceIds.indexOf(id) + 1}',
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _labelValue(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: 0.6,
            color: AppTheme.muted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.muted,
            height: 1.4,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
