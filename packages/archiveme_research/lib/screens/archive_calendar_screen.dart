import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:voicememory_mobile/config/screenshot_mode.dart';
import 'package:voicememory_mobile/design/archive_mobile_typography.dart';
import 'package:voicememory_mobile/features/archive_calendar/archive_calendar_copy.dart';
import 'package:voicememory_mobile/features/archive_calendar/archive_calendar_engine.dart';
import 'package:voicememory_mobile/features/archive_calendar/archive_calendar_models.dart';
import 'package:voicememory_mobile/features/archive_watchlist/archive_watchlist_store.dart';
import 'package:voicememory_mobile/features/then_now/then_now_engine.dart';
import 'package:voicememory_mobile/features/review_ritual/view_ritual_copy.dart';
import 'package:voicememory_mobile/features/milestone_share/milestone_share_copy.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/services/journal_service.dart';
import 'package:voicememory_mobile/theme/app_colors.dart';
import 'package:voicememory_mobile/theme/app_spacing.dart';
import 'package:voicememory_mobile/widgets/pushed_screen_shell.dart';

/// Full Archive Calendar screen — activity counts and safe markers only.
class ArchiveCalendarScreen extends StatefulWidget {
  const ArchiveCalendarScreen({
    super.key,
    this.journalService,
    this.engine = const ArchiveCalendarEngine(),
    this.thenNowEngine = const ThenNowEngine(),
    this.watchlistStore,
    this._initialResult,
  });

  final JournalService? journalService;
  final ArchiveCalendarEngine engine;
  final ThenNowEngine thenNowEngine;
  final ArchiveWatchlistStore? watchlistStore;
  final ArchiveCalendarResult? _initialResult;

  @override
  State<ArchiveCalendarScreen> createState() => _ArchiveCalendarScreenState();
}

class _ArchiveCalendarScreenState extends State<ArchiveCalendarScreen> {
  ArchiveCalendarResult? _result;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget._initialResult != null) {
      _result = widget._initialResult;
      _loading = false;
      return;
    }
    _load();
  }

  Future<void> _load() async {
    if (ScreenshotMode.enabled) {
      if (!mounted) return;
      setState(() {
        _result = widget.engine.buildFromJournal(
          entries: const [],
          sampleMode: true,
        );
        _loading = false;
      });
      return;
    }

    final journal = widget.journalService ?? AppServices.instance.journal;
    final entries = await journal.loadAll();
    final watchlist =
        widget.watchlistStore ??
        ArchiveWatchlistStore(AppServices.instance.prefs);
    final watchItems = await watchlist.loadItems();
    final thenNow = widget.thenNowEngine.buildFromJournal(entries: entries);
    if (!mounted) return;
    setState(() {
      _result = widget.engine.buildFromJournal(
        entries: entries,
        weeklyReviewAvailable: entries.length >= 5,
        hasWatchTheme: watchItems.isNotEmpty,
        thenVsNowAvailable: thenNow.hasCard,
      );
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: ArchiveCalendarCopy.eyebrow,
      fallbackRoute: ArchiveCalendarCopy.archiveHomeRoute,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              key: const Key('archive_calendar_screen'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: _result!.isEmpty
                  ? _emptyState(context, _result!)
                  : _activeState(context, _result!),
            ),
    );
  }

  Widget _emptyState(BuildContext context, ArchiveCalendarResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          result.emptyTitle,
          key: const Key('archive_calendar_screen_empty_title'),
          style: ArchiveMobileTypography.listTitle(context),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          result.emptyBody,
          key: const Key('archive_calendar_screen_empty_body'),
          style: ArchiveMobileTypography.explanationBody(
            context,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          key: const Key('archive_calendar_screen_save_button'),
          onPressed: () => context.push(result.recordRoute),
          child: const Text(ArchiveCalendarCopy.saveMomentCta),
        ),
      ],
    );
  }

  Widget _activeState(BuildContext context, ArchiveCalendarResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          ArchiveCalendarCopy.subtitle,
          key: const Key('archive_calendar_screen_subtitle'),
          style: ArchiveMobileTypography.listSubtitle(context),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          result.privacyLine,
          key: const Key('archive_calendar_screen_privacy'),
          style: ArchiveMobileTypography.explanationBody(
            context,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          result.monthlyTotalLabel,
          key: const Key('archive_calendar_screen_monthly_total'),
          style: ArchiveMobileTypography.cardLabel(context),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          result.weekSummaryLabel,
          key: const Key('archive_calendar_screen_week_summary'),
          style: ArchiveMobileTypography.listSubtitle(context),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          result.mostActiveDayLabel,
          key: const Key('archive_calendar_screen_most_active_day'),
          style: ArchiveMobileTypography.explanationBody(
            context,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final day in result.days) ...[
          _DayRow(day: day, onTap: () => _showDayDetail(context, day, result)),
          const SizedBox(height: AppSpacing.sm),
        ],
        Text(
          result.helperText,
          key: const Key('archive_calendar_screen_helper'),
          style: ArchiveMobileTypography.explanationBody(
            context,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton(
          key: const Key('archive_calendar_screen_review_ritual_button'),
          onPressed: () => context.push(ReviewRitualCopy.route),
          child: const Text(ReviewRitualCopy.openReviewRitualCta),
        ),
        if (result.activeDayCount >= 1) ...[
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            key: const Key('archive_calendar_screen_milestone_share_button'),
            onPressed: () => context.push(MilestoneShareCopy.route),
            child: const Text(MilestoneShareCopy.openMilestoneCardsCta),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        FilledButton(
          key: const Key('archive_calendar_screen_record_button'),
          onPressed: () => context.push(result.recordRoute),
          child: const Text(ArchiveCalendarCopy.saveMomentCta),
        ),
      ],
    );
  }

  void _showDayDetail(
    BuildContext context,
    ArchiveCalendarDaySummary day,
    ArchiveCalendarResult result,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                day.dayLabel,
                key: const Key('archive_calendar_day_detail_title'),
                style: ArchiveMobileTypography.listTitle(context),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                ArchiveCalendarCopy.momentCountLabel(day.momentCount),
                key: const Key('archive_calendar_day_detail_count'),
                style: ArchiveMobileTypography.listSubtitle(context),
              ),
              if (day.isToday)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    'Today',
                    style: ArchiveMobileTypography.cardLabel(context),
                  ),
                ),
              if (day.isMostActiveDay)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    'Most active day',
                    style: ArchiveMobileTypography.cardLabel(context),
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              for (final marker in day.markerLabels)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(
                    marker,
                    style: ArchiveMobileTypography.explanationBody(context),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                key: const Key('archive_calendar_day_detail_archive_home'),
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push(result.archiveHomeRoute);
                },
                child: Text(result.dayDetailArchiveHomeCta),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                key: const Key('archive_calendar_day_detail_record'),
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push(result.recordRoute);
                },
                child: Text(result.dayDetailRecordCta),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, required this.onTap});

  final ArchiveCalendarDaySummary day;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      day.dayLabel,
                      style: ArchiveMobileTypography.listSubtitle(context),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      ArchiveCalendarCopy.momentCountLabel(day.momentCount),
                      style: ArchiveMobileTypography.explanationBody(
                        context,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (day.isToday)
                Text(
                  'Today',
                  style: ArchiveMobileTypography.cardLabel(context),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
