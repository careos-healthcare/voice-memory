import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/warm_archive_copy.dart';
import '../features/retention/retention_analytics.dart';
import '../features/weekly_story/weekly_story_models.dart';
import '../features/archive_explanations/explanation_models.dart';
import '../theme/app_theme.dart';
import 'archive_why_button.dart';

/// Discover / Archive teaser for the weekly reflection story.
class WeeklyArchiveStoryCard extends StatefulWidget {
  const WeeklyArchiveStoryCard({super.key, required this.story});

  final WeeklyArchiveStory story;

  @override
  State<WeeklyArchiveStoryCard> createState() => _WeeklyArchiveStoryCardState();
}

class _WeeklyArchiveStoryCardState extends State<WeeklyArchiveStoryCard> {
  var _loggedView = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loggedView) {
      _loggedView = true;
      RetentionAnalytics.weeklyStoryViewed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.story;
    return Semantics(
      label: 'Your week in reflection',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Your Week in Reflection',
                      style: TextStyle(
                        fontSize: 17,
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
              const SizedBox(height: 10),
              if (story.topThemes.isNotEmpty) ...[
                const Text(
                  'Most common themes:',
                  style: TextStyle(fontSize: 12, color: AppTheme.muted),
                ),
                for (final t in story.topThemes.take(3)) Text('• ${t.label}'),
              ],
              if (story.growingThemes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  WarmArchiveCopy.themeReturningMoreOften(
                    story.growingThemes.first.label,
                  ),
                  style: const TextStyle(height: 1.4),
                ),
              ],
              if (story.decliningThemes.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  WarmArchiveCopy.themeReturningLessOften(
                    story.decliningThemes.first.label,
                  ),
                  style: const TextStyle(height: 1.4, color: AppTheme.muted),
                ),
              ],
              if (story.primaryBelief != null) ...[
                const SizedBox(height: 8),
                Text(
                  WarmArchiveCopy.beliefConcept,
                  style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                ),
                Text(
                  '“${story.primaryBelief}”',
                  style: const TextStyle(height: 1.4),
                ),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  RetentionAnalytics.weeklyStoryOpened();
                  context.push('/weekly-story');
                },
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                child: const Text('View Full Story'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
