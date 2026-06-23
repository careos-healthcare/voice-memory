import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/screenshot_mode.dart';
import '../design/archive_mobile_typography.dart';
import '../features/activation/weekly_archive_review.dart';
import '../features/beta_feedback/beta_feedback_engine.dart';
import '../features/review_ritual/view_ritual_copy.dart';
import '../features/milestone_share/milestone_share_copy.dart';
import '../features/review_ritual/view_ritual_engine.dart';
import '../features/review_ritual/view_ritual_models.dart';
import '../features/review_ritual/view_ritual_store.dart';
import '../services/app_services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/pushed_screen_shell.dart';

/// Review ritual setup — local timing and focus only, no notifications.
class ReviewRitualScreen extends StatefulWidget {
  const ReviewRitualScreen({
    super.key,
    this.engine = const ReviewRitualEngine(),
    ReviewRitualResult? initialResult,
    this.weeklyReviewAvailable = false,
    this.realSavedMomentCount = 0,
  }) : _initialResult = initialResult;

  final ReviewRitualEngine engine;
  final bool weeklyReviewAvailable;
  final int realSavedMomentCount;
  final ReviewRitualResult? _initialResult;

  @override
  State<ReviewRitualScreen> createState() => _ReviewRitualScreenState();
}

class _ReviewRitualScreenState extends State<ReviewRitualScreen> {
  ReviewRitualResult? _result;
  ReviewRitualDaypart _daypart = ReviewRitualDaypart.evening;
  bool _focusRepeated = true;
  bool _focusChanged = true;
  bool _focusWatchNext = true;
  bool _loading = true;
  bool _justSaved = false;
  int _realSavedMomentCount = 0;
  bool _weeklyReviewAvailable = false;

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
        _result = widget.engine.build(
          ReviewRitualInput(
            realSavedMomentCount: 0,
            weeklyReviewAvailable: false,
            sampleMode: true,
          ),
        );
        _loading = false;
      });
      return;
    }

    await ReviewRitualStore.ensureLoaded();
    final entries = await AppServices.instance.journal.loadAll();
    final realSavedCount = BetaFeedbackEngine.realEntryCountFor(entries);
    final weeklyReviewAvailable = realSavedCount >= 5;
    final ritual = ReviewRitualStore.cached;
    if (ritual != null) {
      _daypart = ritual.selectedDaypart;
      _focusRepeated = ritual.focusRepeated;
      _focusChanged = ritual.focusChanged;
      _focusWatchNext = ritual.focusWatchNext;
    }
    if (!mounted) return;
    setState(() {
      _realSavedMomentCount = realSavedCount;
      _weeklyReviewAvailable = weeklyReviewAvailable;
      _result = widget.engine.build(
        ReviewRitualInput(
          realSavedMomentCount: realSavedCount,
          weeklyReviewAvailable: weeklyReviewAvailable,
          ritual: ritual,
        ),
      );
      _loading = false;
    });
  }

  Future<void> _save() async {
    final now = DateTime.now().toUtc();
    final existing = ReviewRitualStore.cached;
    await ReviewRitualStore.instance().save(
      ReviewRitual(
        selectedDay: ReviewRitualDay.sunday,
        selectedDaypart: _daypart,
        focusRepeated: _focusRepeated,
        focusChanged: _focusChanged,
        focusWatchNext: _focusWatchNext,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
    if (!mounted) return;
    setState(() {
      _justSaved = true;
      _result = widget.engine.build(
        ReviewRitualInput(
          realSavedMomentCount: _realSavedMomentCount,
          weeklyReviewAvailable: _weeklyReviewAvailable,
          ritual: ReviewRitualStore.cached,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: ReviewRitualCopy.screenTitle,
      fallbackRoute: ReviewRitualCopy.archiveHomeRoute,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              key: const Key('review_ritual_screen'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: _content(context, _result!),
            ),
    );
  }

  Widget _content(BuildContext context, ReviewRitualResult result) {
    final explainStyle = ArchiveMobileTypography.explanationBody(
      context,
      color: AppColors.textSecondary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          ReviewRitualCopy.chooseIntro,
          key: const Key('review_ritual_screen_intro'),
          style: ArchiveMobileTypography.listSubtitle(context),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          ReviewRitualCopy.noRemindersLine,
          key: const Key('review_ritual_screen_no_reminders'),
          style: explainStyle,
        ),
        if (result.insufficientEntries) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            ReviewRitualCopy.insufficientHelper,
            key: const Key('review_ritual_screen_insufficient'),
            style: explainStyle,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text(
          ReviewRitualCopy.daySunday,
          style: ArchiveMobileTypography.cardLabel(context),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: ReviewRitualDaypart.values.map((part) {
            final selected = _daypart == part;
            return ChoiceChip(
              key: Key('review_ritual_daypart_${part.name}'),
              label: Text(ReviewRitualCopy.daypartLabel(part)),
              selected: selected,
              onSelected: (_) => setState(() => _daypart = part),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          ReviewRitualCopy.focusIntro,
          style: ArchiveMobileTypography.cardLabel(context),
        ),
        const SizedBox(height: AppSpacing.sm),
        _FocusChip(
          key: const Key('review_ritual_focus_repeated'),
          label: ReviewRitualCopy.focusRepeated,
          selected: _focusRepeated,
          onChanged: (value) => setState(() => _focusRepeated = value),
        ),
        _FocusChip(
          key: const Key('review_ritual_focus_changed'),
          label: ReviewRitualCopy.focusChanged,
          selected: _focusChanged,
          onChanged: (value) => setState(() => _focusChanged = value),
        ),
        _FocusChip(
          key: const Key('review_ritual_focus_watch_next'),
          label: ReviewRitualCopy.focusWatchNext,
          selected: _focusWatchNext,
          onChanged: (value) => setState(() => _focusWatchNext = value),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          key: const Key('review_ritual_screen_save_button'),
          onPressed: _save,
          child: const Text(ReviewRitualCopy.saveRitualCta),
        ),
        if (_justSaved || result.hasRitual) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            ReviewRitualCopy.savedLocally,
            key: const Key('review_ritual_screen_saved'),
            style: explainStyle,
          ),
          Text(
            ReviewRitualCopy.changeAnytime,
            style: explainStyle,
          ),
        ],
        if (result.hasRitual) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            result.summaryLabel,
            key: const Key('review_ritual_screen_summary'),
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (result.weeklyReviewAvailable && !result.insufficientEntries)
          FilledButton(
            key: const Key('review_ritual_screen_weekly_review_button'),
            onPressed: () => context.push(WeeklyArchiveReviewNavigation.route),
            child: const Text(ReviewRitualCopy.openWeeklyReviewCta),
          ),
        if (_realSavedMomentCount >= 1) ...[
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            key: const Key('review_ritual_screen_milestone_share_button'),
            onPressed: () => context.push(MilestoneShareCopy.route),
            child: const Text(MilestoneShareCopy.openMilestoneCardsCta),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          key: const Key('review_ritual_screen_archive_home_button'),
          onPressed: () => context.push(ReviewRitualCopy.archiveHomeRoute),
          child: const Text(ReviewRitualCopy.openArchiveHomeCta),
        ),
      ],
    );
  }
}

class _FocusChip extends StatelessWidget {
  const _FocusChip({
    required this.label,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: onChanged,
      ),
    );
  }
}
