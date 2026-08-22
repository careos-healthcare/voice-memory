import 'package:flutter/material.dart';

import 'package:archiveme_mobile/billing/archive_entitlement_reader.dart';
import 'package:archiveme_mobile/billing/archive_pro_feature_map.dart';
import 'package:archiveme_mobile/billing/paywall_access.dart';
import 'package:archiveme_mobile/billing/paywall_trigger_model.dart';
import 'package:archiveme_mobile/billing/pro_value_preview_engine.dart';
import 'package:archiveme_mobile/config/screenshot_mode.dart';
import 'package:archiveme_mobile/config/screenshot_sample_data.dart';
import 'package:archiveme_mobile/features/activation/activation_tracker.dart';
import 'package:archiveme_mobile/features/export/private_recap_engine.dart';
import 'package:archiveme_mobile/features/moments/key_moment_store.dart';
import 'package:archiveme_mobile/features/pattern_map/pattern_map_engine.dart';
import 'package:archiveme_mobile/features/pattern_map/pattern_map_model.dart';
import 'package:archiveme_mobile/features/pattern_memory/pattern_memory_coordinator.dart';
import 'package:archiveme_mobile/features/tomorrow_return/tomorrow_check_in_coordinator.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:archiveme_mobile/widgets/billing/pro_value_preview_card.dart';
import 'package:archiveme_mobile/widgets/export/private_recap_actions.dart';
import 'package:archiveme_mobile/widgets/patterns/pattern_map_card.dart';

/// A single screen that shows one clear map of a recurring pattern.
class PatternMapScreen extends StatefulWidget {
  const PatternMapScreen({
    super.key,
    this.loader,
    this.onUseCheck,
    this.entitlementReader,
    this.firstLoopClosed,
    this.momentCountLoader,
  });

  /// Loads the map to show. Defaults to building from pattern memory + key
  /// moments. Injectable so widget tests never block on real file I/O.
  final Future<PatternMap?> Function()? loader;

  /// Creates tomorrow's check-in for [nextCheck]. Defaults to the coordinator.
  final Future<void> Function(String nextCheck)? onUseCheck;

  final ArchiveEntitlementReader? entitlementReader;
  final bool? firstLoopClosed;
  final Future<int> Function()? momentCountLoader;

  @override
  State<PatternMapScreen> createState() => _PatternMapScreenState();
}

class _PatternMapScreenState extends State<PatternMapScreen> {
  PatternMap? _map;
  bool _loading = true;
  bool _checkSet = false;
  bool _firstLoopClosed = false;
  bool _memoryGated = false;
  int _momentCount = 0;
  PaywallTriggerContext? _gateTrigger;
  bool _previewDismissed = false;

  ArchiveEntitlementReader get _entitlementReader =>
      widget.entitlementReader ?? ArchiveEntitlementReader.forAccessCheck();

  @override
  void initState() {
    super.initState();
    ActivationTracker.trackPatternMapOpened();
    _load();
  }

  Future<void> _load() async {
    final loader = widget.loader ?? _defaultLoad;
    final map = await loader();
    final loopClosed =
        widget.firstLoopClosed ?? await PaywallAccess.isFirstLoopClosed();
    final momentCount = widget.momentCountLoader != null
        ? await widget.momentCountLoader!()
        : (ScreenshotMode.enabled
              ? ScreenshotSampleData.keyMomentsSample.length
              : (await KeyMomentStore.instance().loadAll()).length);
    final trigger = map != null
        ? await PaywallAccess.check(
            feature: ArchiveFeature.patternMap,
            entitlementReader: _entitlementReader,
            firstLoopClosed: loopClosed,
            momentCount: momentCount,
            sourceRoute: '/pattern-map',
          )
        : null;
    if (!mounted) return;
    setState(() {
      _map = map;
      _loading = false;
      _firstLoopClosed = loopClosed;
      _momentCount = momentCount;
      _memoryGated = trigger != null;
      _gateTrigger = trigger;
    });
    if (map != null) ActivationTracker.trackPatternMapShown();
  }

  Future<PatternMap?> _defaultLoad() async {
    if (ScreenshotMode.patternMapPreview) {
      return ScreenshotSampleData.patternMapSample;
    }
    final memory = await PatternMemoryCoordinator.loadActive();
    if (memory == null) return null;
    final moments = ScreenshotMode.enabled
        ? ScreenshotSampleData.keyMomentsSample
        : await KeyMomentStore.instance().loadAll();
    return buildPatternMap(memory: memory, moments: moments);
  }

  Future<void> _useCheck(String nextCheck) async {
    ActivationTracker.trackPatternMapUseCheckTapped();
    final handler = widget.onUseCheck ?? _defaultUseCheck;
    await handler(nextCheck);
    if (!mounted) return;
    setState(() => _checkSet = true);
  }

  Future<void> _defaultUseCheck(String nextCheck) async {
    await TomorrowCheckInCoordinator.createForTomorrow(
      patternTitle: _map?.patternTitle ?? '',
      specificPrompt: '',
      checkInQuestion: nextCheck,
    );
  }

  Future<void> _openUnlockPaywall() async {
    final trigger = await PaywallAccess.check(
      feature: ArchiveFeature.patternMap,
      entitlementReader: _entitlementReader,
      firstLoopClosed: _firstLoopClosed,
      momentCount: _momentCount,
      sourceRoute: '/pattern-map',
    );
    if (trigger == null || !mounted) return;
    PaywallAccess.openPaywall(context, trigger);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Pattern map'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _map == null
            ? _emptyState()
            : SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'A simple view of one pattern over time.',
                      style: VoiceMemoryTypography.bodyStyle(
                        color: AppColors.textSecondary,
                      ).copyWith(fontSize: 14, height: 1.4),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PatternMapCard(
                      map: _map!,
                      showTitle: false,
                      onUseCheck: _memoryGated || _checkSet ? null : _useCheck,
                    ),
                    if (_memoryGated &&
                        _gateTrigger != null &&
                        !_previewDismissed) ...[
                      const SizedBox(height: AppSpacing.md),
                      ProValuePreviewCard(
                        preview: buildProValuePreview(_gateTrigger!),
                        onUnlock: _openUnlockPaywall,
                        onDismiss: () =>
                            setState(() => _previewDismissed = true),
                      ),
                    ],
                    if (!_memoryGated && _checkSet) ...[
                      const SizedBox(height: AppSpacing.md),
                      _confirmation(),
                    ],
                    if (!_memoryGated) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Keep a private copy',
                        style: VoiceMemoryTypography.bodyStyle(
                          color: AppColors.textSecondary,
                        ).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      PrivateRecapActions(
                        recap: PrivateRecapEngine.fromPatternMap(_map!),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          'Record a few moments and your pattern map will appear here.',
          textAlign: TextAlign.center,
          style: VoiceMemoryTypography.bodyStyle(
            color: AppColors.textSecondary,
          ).copyWith(fontSize: 15, height: 1.5),
        ),
      ),
    );
  }

  Widget _confirmation() {
    return Row(
      children: [
        const Icon(Icons.check_circle, color: AppColors.success, size: 18),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            'Tomorrow\u2019s check is set.',
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.success,
            ).copyWith(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
