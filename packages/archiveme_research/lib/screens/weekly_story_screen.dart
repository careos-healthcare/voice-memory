import 'package:flutter/material.dart';

import 'package:archiveme_mobile/design/warm_archive_copy.dart';
import 'package:archiveme_mobile/features/archive_state_object/archive_state_object.dart';
import 'package:archiveme_mobile/features/retention/retention_analytics.dart';
import 'package:archiveme_mobile/features/weekly_story/weekly_story_engine.dart';
import 'package:archiveme_mobile/features/weekly_story/weekly_story_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/features/archive_explanations/explanation_models.dart';
import 'package:archiveme_mobile/widgets/archive_why_button.dart';
import 'package:archiveme_mobile/widgets/pushed_screen_shell.dart';

/// Full weekly archive story — evidence-backed only.
class WeeklyStoryScreen extends StatefulWidget {
  const WeeklyStoryScreen({super.key});

  @override
  State<WeeklyStoryScreen> createState() => _WeeklyStoryScreenState();
}

class _WeeklyStoryScreenState extends State<WeeklyStoryScreen> {
  List<JournalEntry> _entries = [];
  WeeklyArchiveStory? _story;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    RetentionAnalytics.weeklyStoryOpened();
    _load();
  }

  Future<void> _load() async {
    final entries = await AppServices.instance.journal.loadAll();
    final state = buildArchiveStateObjectV3(entries: entries);
    final story = const WeeklyStoryEngine().build(
      entries: entries,
      state: state,
    );
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _story = story;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: 'Your Week',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _story == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _entries.length < WeeklyStoryEngine.minEntriesForCard
                      ? 'Record at least ${WeeklyStoryEngine.minEntriesForCard} reflections '
                            'for a weekly story.'
                      : 'Not enough activity this week yet. Keep recording — '
                            'your story will fill in with real themes and beliefs.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.muted, height: 1.45),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'YOUR WEEK IN REFLECTION',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 0.8,
                          color: AppTheme.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ArchiveWhyButton(
                      ref: ArchiveInsightRef.weeklyStory(),
                      compact: true,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${_story!.reflectionCountThisWeek} reflections this week',
                  style: const TextStyle(color: AppTheme.muted),
                ),
                const SizedBox(height: 16),
                if (_story!.topThemes.isNotEmpty) ...[
                  Text(
                    WarmArchiveCopy.themeConcept,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  for (final t in _story!.topThemes) Text('• ${t.label}'),
                  const SizedBox(height: 16),
                ],
                if (_story!.growingThemes.isNotEmpty) ...[
                  for (final t in _story!.growingThemes)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        WarmArchiveCopy.themeReturningMoreOften(t.label),
                        style: const TextStyle(height: 1.45),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
                if (_story!.decliningThemes.isNotEmpty) ...[
                  for (final t in _story!.decliningThemes)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        WarmArchiveCopy.themeReturningLessOften(t.label),
                        style: const TextStyle(
                          height: 1.45,
                          color: AppTheme.muted,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
                if (_story!.primaryBelief != null) ...[
                  Text(
                    WarmArchiveCopy.beliefConcept,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '“${_story!.primaryBelief}”',
                    style: const TextStyle(height: 1.45, fontSize: 16),
                  ),
                ],
              ],
            ),
    );
  }
}
