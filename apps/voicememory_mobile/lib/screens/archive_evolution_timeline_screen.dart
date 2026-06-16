import 'package:flutter/material.dart';

import '../billing/archive_entitlement_reader.dart';
import '../billing/archive_pro_feature_map.dart';
import '../billing/paywall_access.dart';
import '../billing/paywall_trigger_model.dart';
import '../billing/pro_value_preview_engine.dart';
import '../config/screenshot_mode.dart';
import '../config/screenshot_sample_data.dart';
import '../features/activation/activation_tracker.dart';
import '../features/archive_memory/archive_evolution_coordinator.dart';
import '../features/archive_memory/archive_evolution_model.dart';
import '../features/tomorrow_return/tomorrow_check_in_coordinator.dart';
import '../product/consumer_ui_copy.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_typography.dart';
import '../widgets/billing/pro_value_preview_card.dart';

/// Full vertical timeline for one recurring pattern.
class ArchiveEvolutionTimelineScreen extends StatefulWidget {
  const ArchiveEvolutionTimelineScreen({
    super.key,
    this.loader,
    this.onUseCheck,
    this.entitlementReader,
    this.firstLoopClosed,
  });

  final Future<ArchiveEvolutionTimeline?> Function()? loader;
  final Future<void> Function(String nextCheck)? onUseCheck;
  final ArchiveEntitlementReader? entitlementReader;
  final bool? firstLoopClosed;

  @override
  State<ArchiveEvolutionTimelineScreen> createState() =>
      _ArchiveEvolutionTimelineScreenState();
}

class _ArchiveEvolutionTimelineScreenState
    extends State<ArchiveEvolutionTimelineScreen> {
  ArchiveEvolutionTimeline? _timeline;
  bool _loading = true;
  bool _checkSet = false;
  bool _memoryGated = false;
  bool _firstLoopClosed = false;
  PaywallTriggerContext? _gateTrigger;
  bool _previewDismissed = false;

  ArchiveEntitlementReader get _entitlementReader =>
      widget.entitlementReader ?? ArchiveEntitlementReader.forAccessCheck();

  @override
  void initState() {
    super.initState();
    ActivationTracker.trackArchiveTimelineOpened();
    _load();
  }

  Future<void> _load() async {
    final loader = widget.loader ?? _defaultLoad;
    final timeline = await loader();
    final loopClosed =
        widget.firstLoopClosed ?? await PaywallAccess.isFirstLoopClosed();
    final trigger = timeline != null
        ? await PaywallAccess.check(
            feature: ArchiveFeature.archiveTimeline,
            entitlementReader: _entitlementReader,
            firstLoopClosed: loopClosed,
            sourceRoute: '/archive-timeline',
          )
        : null;
    if (!mounted) return;
    setState(() {
      _timeline = timeline;
      _loading = false;
      _firstLoopClosed = loopClosed;
      _memoryGated = trigger != null;
      _gateTrigger = trigger;
    });
    if (timeline != null) ActivationTracker.trackArchiveTimelineShown();
  }

  Future<ArchiveEvolutionTimeline?> _defaultLoad() async {
    if (ScreenshotMode.archiveTimelinePreview) {
      return ScreenshotSampleData.archiveEvolutionTimelineSample;
    }
    return ArchiveEvolutionCoordinator.loadLatest();
  }

  Future<void> _useCheck(String nextCheck) async {
    ActivationTracker.trackArchiveTimelineUseCheckTapped();
    final handler = widget.onUseCheck ?? _defaultUseCheck;
    await handler(nextCheck);
    if (!mounted) return;
    setState(() => _checkSet = true);
  }

  Future<void> _defaultUseCheck(String nextCheck) async {
    await TomorrowCheckInCoordinator.createForTomorrow(
      patternTitle: _timeline?.patternTitle ?? '',
      specificPrompt: '',
      checkInQuestion: nextCheck,
    );
  }

  Future<void> _openUnlockPaywall() async {
    final trigger = await PaywallAccess.check(
      feature: ArchiveFeature.archiveTimeline,
      entitlementReader: _entitlementReader,
      firstLoopClosed: _firstLoopClosed,
      sourceRoute: '/archive-timeline',
    );
    if (trigger == null || !mounted) return;
    PaywallAccess.openPaywall(context, trigger);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        title: const Text('Pattern timeline'),
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _timeline == null
          ? _emptyState()
          : _content(_timeline!),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Text(
        'Record a few moments and ArchiveMe will build this.',
        style: VoiceMemoryTypography.bodyStyle(color: AppColors.textSecondary),
      ),
    );
  }

  Widget _content(ArchiveEvolutionTimeline timeline) {
    final events = _memoryGated
        ? timeline.events.take(4).toList()
        : timeline.events;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          timeline.patternTitle,
          style: VoiceMemoryTypography.cardTitleStyle().copyWith(fontSize: 20),
        ),
        if (timeline.firstSeenDate != null ||
            timeline.lastSeenDate != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            _rangeLabel(timeline),
            style: VoiceMemoryTypography.metadataStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 12),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        for (var i = 0; i < events.length; i++) ...[
          _eventTile(events[i], isLast: i == events.length - 1),
        ],
        if (_memoryGated && _gateTrigger != null && !_previewDismissed) ...[
          const SizedBox(height: AppSpacing.md),
          ProValuePreviewCard(
            preview: buildProValuePreview(_gateTrigger!),
            onUnlock: _openUnlockPaywall,
            onDismiss: () => setState(() => _previewDismissed = true),
          ),
        ],
        if (!_memoryGated && timeline.hasNextCheck) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Next check',
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            timeline.nextCheck!,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textPrimary,
            ).copyWith(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _checkSet
                  ? null
                  : () => _useCheck(timeline.nextCheck!),
              child: Text(
                _checkSet
                    ? ConsumerUiCopy.resultNextCheckConfirmation
                    : 'Use this check',
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _eventTile(ArchiveEvolutionEvent event, {required bool isLast}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              _dateLabel(event.date),
              style: VoiceMemoryTypography.metadataStyle(
                color: AppColors.textSecondary,
              ).copyWith(fontSize: 12),
            ),
          ),
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.accentPrimary,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: const Color(0xFFF5E6D3)),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: VoiceMemoryTypography.bodyStyle(
                      color: AppColors.textPrimary,
                    ).copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    event.body,
                    style: VoiceMemoryTypography.bodyStyle(
                      color: AppColors.textSecondary,
                    ).copyWith(fontSize: 14, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _rangeLabel(ArchiveEvolutionTimeline timeline) {
    final first = timeline.firstSeenDate;
    final last = timeline.lastSeenDate;
    if (first == null || last == null) return '';
    if (_isSameDay(first, last)) {
      return 'First seen ${_dateLabel(first)}';
    }
    return 'First seen ${_dateLabel(first)} · last ${_dateLabel(last)}';
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) return 'today';
    if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return 'yesterday';
    }
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
