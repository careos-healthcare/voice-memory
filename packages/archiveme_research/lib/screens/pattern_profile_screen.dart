import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:archiveme_mobile/features/activation/activation_tracker.dart';
import 'package:archiveme_mobile/features/archive_memory/memory_quality_coordinator.dart';
import 'package:archiveme_mobile/features/archive_memory/memory_quality_model.dart';
import 'package:archiveme_mobile/features/pattern_profile/pattern_profile_coordinator.dart';
import 'package:archiveme_mobile/features/pattern_profile/pattern_profile_model.dart';
import 'package:archiveme_mobile/features/feedback/archive_feedback_model.dart';
import 'package:archiveme_mobile/features/tomorrow_return/tomorrow_check_in_coordinator.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:archiveme_mobile/widgets/feedback/archive_feedback_chips.dart';
import 'package:archiveme_mobile/widgets/patterns/memory_quality_chip.dart';

/// One place to see a single recurring pattern — memory, map, timeline, and
/// related moments without opening four separate screens.
class PatternProfileScreen extends StatefulWidget {
  const PatternProfileScreen({
    super.key,
    this.loader,
    this.qualityLoader,
    this.onUseCheck,
    this.showFeedback = true,
  });

  final Future<PatternProfile?> Function()? loader;
  final Future<MemoryQuality> Function()? qualityLoader;
  final Future<void> Function(String nextCheck, String patternTitle)?
  onUseCheck;

  /// When true, shows one feedback row at the bottom of the profile.
  final bool showFeedback;

  @override
  State<PatternProfileScreen> createState() => _PatternProfileScreenState();
}

class _PatternProfileScreenState extends State<PatternProfileScreen> {
  static const Color _warmSurface = Color(0xFFFFFBF5);
  static const Color _warmBorder = AppColors.warmBorder;

  PatternProfile? _profile;
  MemoryQuality? _quality;
  bool _loading = true;
  bool _checkSet = false;

  @override
  void initState() {
    super.initState();
    ActivationTracker.trackPatternProfileOpened();
    _load();
  }

  Future<void> _load() async {
    final loader = widget.loader ?? PatternProfileCoordinator.load;
    final qualityLoader = widget.qualityLoader ?? MemoryQualityCoordinator.load;
    final results = await Future.wait([loader(), qualityLoader()]);
    if (!mounted) return;
    setState(() {
      _profile = results[0] as PatternProfile?;
      _quality = results[1] as MemoryQuality;
      _loading = false;
    });
  }

  Future<void> _useCheck(String nextCheck) async {
    final profile = _profile;
    if (profile == null) return;
    ActivationTracker.trackPatternProfileUseCheckTapped();
    final handler = widget.onUseCheck ?? _defaultUseCheck;
    await handler(nextCheck, profile.patternTitle);
    if (!mounted) return;
    setState(() => _checkSet = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ConsumerUiCopy.resultNextCheckConfirmation)),
    );
  }

  Future<void> _defaultUseCheck(String nextCheck, String patternTitle) async {
    await TomorrowCheckInCoordinator.createForTomorrow(
      patternTitle: patternTitle,
      specificPrompt: '',
      checkInQuestion: nextCheck,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Pattern profile'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _profile == null
            ? _emptyState()
            : _content(_profile!),
      ),
    );
  }

  Widget _emptyState() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(
          'Record a few moments and ArchiveMe will build this pattern.',
          style: VoiceMemoryTypography.bodyStyle(
            color: AppColors.textSecondary,
          ).copyWith(fontSize: 15, height: 1.5),
        ),
      ],
    );
  }

  Widget _content(PatternProfile profile) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(
          profile.patternTitle,
          style: VoiceMemoryTypography.cardTitleStyle().copyWith(fontSize: 22),
        ),
        if (_quality != null && _quality!.shouldShow) ...[
          const SizedBox(height: AppSpacing.xs),
          MemoryQualityChip(quality: _quality!),
        ] else if (profile.clarityLabel != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            profile.clarityLabel!,
            style: VoiceMemoryTypography.metadataStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (profile.hasMemorySummary) ...[
          _section(
            'What ArchiveMe remembers',
            profile.archiveMemorySummary!.primaryMemoryLine,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (profile.hasMap) ...[
          _mapPreview(profile),
          const SizedBox(height: AppSpacing.md),
        ],
        if (profile.hasTimeline) ...[
          _timelinePreview(profile),
          const SizedBox(height: AppSpacing.md),
        ],
        if (profile.hasKeyMoments) ...[
          _momentsPreview(profile),
          const SizedBox(height: AppSpacing.md),
        ],
        if (profile.hasNextCheck) ...[
          _section('Next check', profile.nextCheck!, emphasize: true),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _checkSet
                  ? null
                  : () => _useCheck(profile.nextCheck!.trim()),
              child: Text(
                _checkSet
                    ? ConsumerUiCopy.resultNextCheckConfirmation
                    : 'Use this check',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            if (profile.hasTimeline)
              OutlinedButton(
                onPressed: () {
                  ActivationTracker.trackPatternProfileOpenTimelineTapped();
                  context.push('/archive-timeline');
                },
                child: const Text('Open timeline'),
              ),
            if (profile.hasKeyMoments)
              OutlinedButton(
                onPressed: () {
                  ActivationTracker.trackPatternProfileFindMomentsTapped();
                  context.push('/moments');
                },
                child: const Text('Find related moments'),
              ),
          ],
        ),
        if (widget.showFeedback) ...[
          const SizedBox(height: AppSpacing.lg),
          ArchiveFeedbackChips(
            targetType: ArchiveFeedbackTargetType.patternProfile,
            targetId: profile.patternTitle,
            patternTitle: profile.patternTitle,
            resultHint: profile.nextCheck,
          ),
        ],
      ],
    );
  }

  Widget _section(String label, String body, {bool emphasize = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _warmSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _warmBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: VoiceMemoryTypography.metadataStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            body,
            style: VoiceMemoryTypography.bodyStyle(color: AppColors.textPrimary)
                .copyWith(
                  fontSize: emphasize ? 16 : 14,
                  fontWeight: emphasize ? FontWeight.w600 : FontWeight.w400,
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }

  Widget _mapPreview(PatternProfile profile) {
    final map = profile.patternMap!;
    return _section(
      'Pattern map',
      [
        if (map.oftenFeelsLike != null) 'Often feels: ${map.oftenFeelsLike}',
        if (map.getsLighterWhen != null)
          'Gets lighter when: ${map.getsLighterWhen}',
        if (map.getsHeavierWhen != null)
          'Gets heavier when: ${map.getsHeavierWhen}',
      ].join('\n'),
    );
  }

  Widget _timelinePreview(PatternProfile profile) {
    final events = profile.archiveEvolutionTimeline!.events.take(3);
    final lines = events
        .map((e) => '${_dayLabel(e.date)} · ${e.title}')
        .join('\n');
    return _section('Pattern timeline', lines);
  }

  Widget _momentsPreview(PatternProfile profile) {
    final lines = profile.keyMoments
        .map((m) => '${_dayLabel(m.date)} · ${m.title}')
        .join('\n');
    return _section('Key moments', lines);
  }

  String _dayLabel(DateTime date) {
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
}
