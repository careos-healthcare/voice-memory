import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/billing/archive_pro_feature_map.dart';
import 'package:voicememory_mobile/billing/paywall_access.dart';
import 'package:voicememory_mobile/billing/paywall_trigger_model.dart';
import 'package:voicememory_mobile/billing/pro_value_preview_engine.dart';
import 'package:voicememory_mobile/config/screenshot_mode.dart';
import 'package:voicememory_mobile/config/screenshot_sample_data.dart';
import 'package:voicememory_mobile/features/activation/activation_tracker.dart';
import 'package:voicememory_mobile/features/archive_memory/archive_evolution_store.dart';
import 'package:voicememory_mobile/features/archive_review/archive_range_review_engine.dart';
import 'package:voicememory_mobile/features/archive_review/archive_range_review_model.dart';
import 'package:voicememory_mobile/features/archive_review/archive_range_review_store.dart';
import 'package:voicememory_mobile/features/moments/key_moment_model.dart';
import 'package:voicememory_mobile/features/moments/key_moment_store.dart';
import 'package:voicememory_mobile/features/pattern_map/pattern_map_engine.dart';
import 'package:voicememory_mobile/features/pattern_map/pattern_map_model.dart';
import 'package:voicememory_mobile/features/pattern_memory/pattern_memory_store.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/features/tomorrow_return/tomorrow_check_in_coordinator.dart';
import 'package:voicememory_mobile/theme/app_colors.dart';
import 'package:voicememory_mobile/theme/app_spacing.dart';
import 'package:voicememory_mobile/theme/voicememory_typography.dart';
import 'package:voicememory_mobile/widgets/archive/archive_range_selector.dart';
import 'package:voicememory_mobile/widgets/billing/pro_value_preview_card.dart';
import 'package:voicememory_mobile/widgets/patterns/archive_range_review_card.dart';

/// Review what repeated, changed, or helped in a chosen date range.
class ArchiveRangeReviewScreen extends StatefulWidget {
  const ArchiveRangeReviewScreen({
    super.key,
    this.momentsLoader,
    this.reviewBuilder,
    this.onUseCheck,
    this.entitlementReader,
    this.firstLoopClosed,
    this.now,
    this.skipPersistence = false,
  });

  final Future<List<KeyMoment>> Function()? momentsLoader;
  final ArchiveRangeReview Function({
    required List<KeyMoment> moments,
    required DateTime now,
    ArchiveReviewRangePreset preset,
    PatternMap? map,
  })?
  reviewBuilder;
  final Future<void> Function(String nextCheck)? onUseCheck;
  final ArchiveEntitlementReader? entitlementReader;
  final bool? firstLoopClosed;
  final DateTime? now;

  /// When true, skips writing to [ArchiveRangeReviewStore] (widget tests).
  final bool skipPersistence;

  @override
  State<ArchiveRangeReviewScreen> createState() =>
      _ArchiveRangeReviewScreenState();
}

class _ArchiveRangeReviewScreenState extends State<ArchiveRangeReviewScreen> {
  ArchiveReviewRangePreset _preset = ArchiveReviewRangePreset.thisWeek;
  ArchiveRangeReview? _review;
  List<KeyMoment> _moments = const [];
  List<KeyMoment> _rangeMoments = const [];
  bool _loading = true;
  bool _checkSet = false;
  bool _memoryGated = false;
  PaywallTriggerContext? _gateTrigger;
  bool _previewDismissed = false;

  ArchiveEntitlementReader get _entitlementReader =>
      widget.entitlementReader ?? ArchiveEntitlementReader.forAccessCheck();

  DateTime get _now =>
      widget.now ??
      (ScreenshotMode.archiveReviewPreview
          ? ScreenshotSampleData.archiveReviewPreviewDay
          : DateTime.now());

  @override
  void initState() {
    super.initState();
    ActivationTracker.trackArchiveRangeReviewOpened();
    _load();
  }

  Future<void> _load() async {
    final moments = widget.momentsLoader != null
        ? await widget.momentsLoader!()
        : (ScreenshotMode.archiveReviewPreview
              ? ScreenshotSampleData.archiveReviewMomentsSample
              : await KeyMomentStore.instance().loadAll());

    final memory = ScreenshotMode.archiveReviewPreview
        ? ScreenshotSampleData.patternMemorySample
        : (widget.momentsLoader != null
              ? null
              : await PatternMemoryStore(
                  AppServices.instance.prefs,
                ).loadActive());
    final timeline = ScreenshotMode.archiveReviewPreview
        ? ScreenshotSampleData.archiveEvolutionTimelineSample
        : (widget.momentsLoader != null
              ? null
              : await ArchiveEvolutionStore.instance().loadLatest());
    final map = memory != null
        ? buildPatternMap(memory: memory, moments: moments)
        : null;

    final isPro = await _entitlementReader.isPro;
    final loopClosed =
        widget.firstLoopClosed ?? await PaywallAccess.isFirstLoopClosed();
    final gatedPreset =
        _preset == ArchiveReviewRangePreset.thisMonth ||
        _preset == ArchiveReviewRangePreset.last30Days;
    final trigger = gatedPreset && !isPro && loopClosed
        ? await PaywallAccess.check(
            feature: ArchiveFeature.monthlyReview,
            entitlementReader: _entitlementReader,
            firstLoopClosed: loopClosed,
            momentCount: moments.length,
            sourceRoute: '/archive-review',
          )
        : null;

    final review = widget.reviewBuilder != null
        ? widget.reviewBuilder!(
            moments: moments,
            now: _now,
            preset: _preset,
            map: map,
          )
        : buildArchiveRangeReview(
            moments: moments,
            now: _now,
            preset: _preset,
            memory: memory,
            map: map,
            timeline: timeline,
          );

    if (!widget.skipPersistence) {
      await ArchiveRangeReviewStore.instance().saveLatest(review);
      await ArchiveRangeReviewStore.instance().appendHistory(review);
    }
    if (review.hasEnoughData) {
      ActivationTracker.trackArchiveRangeReviewShown();
    }

    final rangeMoments = _momentsForReview(moments, review);

    if (!mounted) return;
    setState(() {
      _moments = moments;
      _review = review;
      _rangeMoments = rangeMoments;
      _memoryGated = trigger != null;
      _gateTrigger = trigger;
      _loading = false;
    });
  }

  List<KeyMoment> _momentsForReview(
    List<KeyMoment> all,
    ArchiveRangeReview review,
  ) {
    final byId = {for (final m in all) m.id: m};
    return review.keyMomentIds
        .map((id) => byId[id])
        .whereType<KeyMoment>()
        .toList();
  }

  Future<void> _onPresetSelected(ArchiveReviewRangePreset preset) async {
    if (preset == _preset) return;
    ActivationTracker.trackArchiveRangeReviewPresetChanged();
    setState(() {
      _preset = preset;
      _loading = true;
      _checkSet = false;
    });
    await _load();
  }

  Future<void> _useCheck(String nextCheck) async {
    final useCheck = widget.onUseCheck ?? _defaultUseCheck;
    await useCheck(nextCheck);
    ActivationTracker.trackArchiveRangeReviewUseCheckTapped();
    if (!mounted) return;
    setState(() => _checkSet = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tomorrow\u2019s check is set.')),
    );
  }

  Future<void> _defaultUseCheck(String nextCheck) async {
    final memory = await PatternMemoryStore(
      AppServices.instance.prefs,
    ).loadActive();
    await TomorrowCheckInCoordinator.createForTomorrow(
      patternTitle: memory?.patternTitle ?? '',
      specificPrompt: '',
      checkInQuestion: nextCheck,
    );
  }

  Future<void> _openUnlockPaywall() async {
    await PaywallAccess.ensureAccess(
      context,
      feature: ArchiveFeature.monthlyReview,
      momentCount: _moments.length,
      sourceRoute: '/archive-review',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Archive review')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                ArchiveRangeSelector(
                  selected: _preset,
                  onPresetSelected: _onPresetSelected,
                ),
                const SizedBox(height: AppSpacing.md),
                if (_review != null)
                  ArchiveRangeReviewCard(
                    review: _review!,
                    onUseCheck:
                        _review!.hasNextCheck && !_checkSet && !_memoryGated
                        ? _useCheck
                        : null,
                  ),
                if (_memoryGated &&
                    _gateTrigger != null &&
                    !_previewDismissed) ...[
                  const SizedBox(height: AppSpacing.md),
                  ProValuePreviewCard(
                    preview: buildProValuePreview(_gateTrigger!),
                    onUnlock: _openUnlockPaywall,
                    onDismiss: () => setState(() => _previewDismissed = true),
                  ),
                ],
                if (_review != null &&
                    _review!.hasEnoughData &&
                    !_memoryGated) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Key moments from this period',
                    style: VoiceMemoryTypography.cardTitleStyle().copyWith(
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ..._rangeMoments.map(_momentTile),
                ],
                if (_review != null &&
                    _review!.hasNextCheck &&
                    !_checkSet &&
                    !_memoryGated) ...[
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: () => _useCheck(_review!.nextCheck!.trim()),
                      child: const Text('Use this check'),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () => context.push('/moments'),
                    child: const Text('Find moments'),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _momentTile(KeyMoment moment) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        moment.title,
        style: VoiceMemoryTypography.bodyStyle(
          color: AppColors.textPrimary,
        ).copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        moment.shortSummary.trim().isNotEmpty
            ? moment.shortSummary.trim()
            : moment.dayKey,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: VoiceMemoryTypography.metadataStyle(
          color: AppColors.textSecondary,
        ),
      ),
      onTap: () => context.push('/moment-detail', extra: moment),
    );
  }
}
