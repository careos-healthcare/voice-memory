import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/user_facing_date.dart';
import '../features/discover/chapter_engine.dart';
import '../features/discover/discover_analytics.dart';
import '../features/discover/discover_models.dart';
import '../models/journal_entry.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';
import '../features/archive_explanations/explanation_models.dart';
import '../widgets/archive_why_button.dart';
import '../widgets/pushed_screen_shell.dart';

/// Detail view for a life chapter opened from Discover Yourself.
class DiscoverChapterDetailScreen extends StatefulWidget {
  const DiscoverChapterDetailScreen({super.key, required this.chapterId});

  final String chapterId;

  @override
  State<DiscoverChapterDetailScreen> createState() =>
      _DiscoverChapterDetailScreenState();
}

class _DiscoverChapterDetailScreenState
    extends State<DiscoverChapterDetailScreen> {
  DiscoverChapterSummary? _chapter;
  List<JournalEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    DiscoverAnalytics.chapterOpened(chapterId: widget.chapterId);
    _load();
  }

  Future<void> _load() async {
    final all = await AppServices.instance.journal.loadAll();
    final chapters = const DiscoverChapterEngine().build(all);
    DiscoverChapterSummary? chapter;
    for (final c in chapters) {
      if (c.id == widget.chapterId) {
        chapter = c;
        break;
      }
    }
    final byId = {for (final e in all) e.id: e};
    final linked = chapter == null
        ? <JournalEntry>[]
        : [
            for (final id in chapter.entryIds)
              if (byId.containsKey(id)) byId[id]!,
          ];

    if (!mounted) return;
    setState(() {
      _chapter = chapter;
      _entries = linked;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final chapter = _chapter;
    return PushedScreenShell(
      title: chapter?.title ?? 'Chapter',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : chapter == null
              ? const Center(
                  child: Text(
                    'Chapter not found.',
                    style: TextStyle(color: AppTheme.muted),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                  children: [
                    Text(
                      '${formatUserFacingDate(chapter.startDate)} – ${formatUserFacingDate(chapter.endDate)}',
                      style: const TextStyle(color: AppTheme.muted, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            chapter.summary,
                            style: const TextStyle(fontSize: 15, height: 1.45),
                          ),
                        ),
                        ArchiveWhyButton(
                          ref: ArchiveInsightRef.chapter(widget.chapterId),
                          compact: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${chapter.entryCount} entries in this chapter',
                      semanticsLabel:
                          '${chapter.entryCount} entries in this chapter',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (final e in _entries)
                      Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          minVerticalPadding: 12,
                          title: Text(
                            formatUserFacingDate(e.createdAt),
                            style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                          ),
                          subtitle: Text(
                            e.transcript.trim().length > 160
                                ? '${e.transcript.trim().substring(0, 160)}…'
                                : e.transcript.trim(),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => context.push('/entry/${e.id}'),
                        ),
                      ),
                  ],
                ),
    );
  }
}
