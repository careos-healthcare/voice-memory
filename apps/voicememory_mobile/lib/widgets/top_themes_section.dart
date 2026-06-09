import 'package:flutter/material.dart';

import '../design/warm_archive_copy.dart';
import '../features/theme_tracking/theme_track.dart';
import '../features/theme_tracking/theme_tracker_service.dart';
import '../models/journal_entry.dart';
import '../theme/app_theme.dart';
import '../theme/voicememory_colors.dart';
import '../features/archive_explanations/archive_explanation_navigation.dart';
import '../features/archive_explanations/explanation_models.dart';
import '../theme/voicememory_typography.dart';
import 'archive_why_button.dart';

/// Top Themes table — Discover and Archive.
class TopThemesSection extends StatelessWidget {
  const TopThemesSection({
    super.key,
    required this.entries,
    this.baselineCounts,
  });

  final List<JournalEntry> entries;
  final Map<String, int>? baselineCounts;

  @override
  Widget build(BuildContext context) {
    final result = const ThemeTrackerService().track(
      entries: entries,
      baselineCounts: baselineCounts,
    );

    if (!result.hasThemes) {
      return const Text(
        'Themes will appear after reflections mention patterns like approval, '
        'confidence, career, or relationships.',
        style: TextStyle(color: AppTheme.muted, height: 1.45, fontSize: 12),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          WarmArchiveCopy.topThemesSectionTitle,
          style: VoiceMemoryTypography.sectionLabelStyle(
            accent: VoiceMemoryColors.themeLavender,
          ),
        ),
        const SizedBox(height: 10),
        _ThemesTable(themes: result.topThemes, entries: entries),
      ],
    );
  }
}

class _ThemesTable extends StatelessWidget {
  const _ThemesTable({
    required this.themes,
    required this.entries,
  });

  final List<ArchiveTheme> themes;
  final List<JournalEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          children: [
            const _TableHeader(),
            const Divider(height: 16, color: AppTheme.muted),
            for (var i = 0; i < themes.length; i++) ...[
              _ThemeRow(theme: themes[i], entries: entries),
              if (i < themes.length - 1)
                const Divider(height: 12, color: VoiceMemoryColors.border),
            ],
          ],
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          flex: 3,
          child: Text('Theme', style: _headerStyle),
        ),
        Expanded(
          flex: 2,
          child: Text('Occurrences', style: _headerStyle, textAlign: TextAlign.center),
        ),
        Expanded(
          flex: 2,
          child: Text('Trend', style: _headerStyle, textAlign: TextAlign.end),
        ),
      ],
    );
  }

  static const _headerStyle = TextStyle(
    fontSize: 11,
    color: AppTheme.muted,
    fontWeight: FontWeight.w600,
  );
}

class _ThemeRow extends StatelessWidget {
  const _ThemeRow({
    required this.theme,
    required this.entries,
  });

  final ArchiveTheme theme;
  final List<JournalEntry> entries;

  @override
  Widget build(BuildContext context) {
    final trendColor = switch (theme.trend) {
      ThemeTrend.up => VoiceMemoryColors.themeLavender,
      ThemeTrend.down => VoiceMemoryColors.contradictionRose,
      ThemeTrend.stable => AppTheme.muted,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 3,
          child: Text(
            theme.name,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.foreground,
            ),
          ),
        ),
        if (themeKeyForDisplayName(theme.name) != null)
          ArchiveWhyButton(
            ref: ArchiveInsightRef.theme(themeKeyForDisplayName(theme.name)!),
            entries: entries,
            surface: 'discover_top_themes',
            compact: true,
          ),
        Expanded(
          flex: 2,
          child: Text(
            '${theme.frequency}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppTheme.muted),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            '${theme.trendGlyph} ${theme.trendLabel}',
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: trendColor,
            ),
          ),
        ),
      ],
    );
  }
}
