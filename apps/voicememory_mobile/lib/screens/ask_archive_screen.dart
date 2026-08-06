import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../billing/archive_pro_feature_map.dart';
import '../billing/paywall_access.dart';
import '../config/screenshot_mode.dart';
import '../config/screenshot_sample_data.dart';
import '../features/activation/activation_tracker.dart';
import '../features/archive_search/archive_search_engine.dart';
import '../features/archive_search/archive_search_model.dart';
import '../features/archive_search/archive_search_parser.dart';
import '../features/moments/key_moment_model.dart';
import '../features/moments/key_moment_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_typography.dart';

/// Ask my Archive — local, guided search over saved moments. Not a chatbot:
/// every question resolves to a known, constrained intent.
class AskArchiveScreen extends StatefulWidget {
  const AskArchiveScreen({super.key, this.loader, this.entitlementReader});

  /// Loads the moments to search. Defaults to the local store; injectable so
  /// widget tests never block on real file I/O.
  final Future<List<KeyMoment>> Function()? loader;

  /// Hook for future Pro gating in tests.
  final Future<bool> Function()? entitlementReader;

  @override
  State<AskArchiveScreen> createState() => _AskArchiveScreenState();
}

class _AskArchiveScreenState extends State<AskArchiveScreen> {
  static const Color _warmSurface = Color(0xFFFFFBF5);
  static const Color _warmBorder = AppColors.warmBorder;

  static const ArchiveSearchEngine _engine = ArchiveSearchEngine();

  final TextEditingController _controller = TextEditingController();

  List<KeyMoment> _all = const [];
  List<ArchiveSearchResult> _results = const [];
  bool _loading = true;
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    ActivationTracker.trackAskArchiveOpened();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (ScreenshotMode.askArchivePreview) {
      setState(() {
        _all = ScreenshotSampleData.keyMomentsSample;
        _loading = false;
      });
      _runSearch(
        const ArchiveSearchQuery(intent: ArchiveSearchIntent.helpedBefore),
        fromSuggestedChip: true,
      );
      return;
    }
    if (ScreenshotMode.enabled) {
      setState(() {
        _all = ScreenshotSampleData.keyMomentsSample;
        _loading = false;
      });
      return;
    }
    final loader = widget.loader ?? () => KeyMomentStore.instance().loadAll();
    final moments = await loader();
    if (!mounted) return;
    setState(() {
      _all = moments;
      _loading = false;
    });
  }

  Future<List<KeyMoment>> _momentsForSearch({
    required ArchiveSearchQuery query,
    required bool fromSuggestedChip,
  }) async {
    if (widget.entitlementReader != null && await widget.entitlementReader!()) {
      return _all;
    }

    final trigger = await PaywallAccess.check(
      feature: ArchiveFeature.keyMomentsSearch,
      momentCount: _all.length,
      sourceRoute: '/ask-archive',
    );
    final gated = trigger != null;

    if (!gated) return _all;

    if (!fromSuggestedChip &&
        query.intent == ArchiveSearchIntent.freeText &&
        mounted) {
      await PaywallAccess.ensureAccess(
        context,
        feature: ArchiveFeature.keyMomentsSearch,
        momentCount: _all.length,
        sourceRoute: '/ask-archive',
      );
    }

    final sorted = [..._all]..sort((a, b) => b.date.compareTo(a.date));
    return sorted.take(ArchiveProFeatureMap.freeKeyMomentsLimit).toList();
  }

  Future<void> _runSearch(
    ArchiveSearchQuery query, {
    bool fromSuggestedChip = false,
  }) async {
    if (fromSuggestedChip) {
      ActivationTracker.trackAskArchiveSuggestedChipTapped();
    } else {
      ActivationTracker.trackAskArchiveSearchUsed();
    }

    final moments = await _momentsForSearch(
      query: query,
      fromSuggestedChip: fromSuggestedChip,
    );
    if (!mounted) return;

    setState(() {
      _searched = true;
      _results = _engine.search(query, moments);
    });
  }

  void _searchText() {
    final query = parseArchiveSearchQuery(_controller.text);
    _runSearch(query);
  }

  void _searchSuggested(ArchiveSuggestedSearch suggested) {
    _controller.text = suggested.label;
    _runSearch(suggested.query, fromSuggestedChip: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Ask my Archive'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  Text(
                    'Search your saved moments.',
                    style: VoiceMemoryTypography.bodyStyle(
                      color: AppColors.textSecondary,
                    ).copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _searchField(),
                  const SizedBox(height: AppSpacing.md),
                  _suggestedChips(),
                  const SizedBox(height: AppSpacing.lg),
                  ..._resultSection(),
                ],
              ),
      ),
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _controller,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _searchText(),
      decoration: InputDecoration(
        hintText: 'Search moments',
        prefixIcon: const Icon(Icons.search, size: 20),
        isDense: true,
        filled: true,
        fillColor: _warmSurface,
        suffixIcon: IconButton(
          icon: const Icon(Icons.arrow_forward, size: 20),
          onPressed: _searchText,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _warmBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _warmBorder),
        ),
      ),
    );
  }

  Widget _suggestedChips() {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final s in kArchiveSuggestedSearches)
          ActionChip(
            label: Text(s.label),
            onPressed: () => _searchSuggested(s),
            backgroundColor: _warmSurface,
            labelStyle: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textPrimary,
            ).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: _warmBorder),
            ),
          ),
      ],
    );
  }

  List<Widget> _resultSection() {
    if (!_searched) {
      return [
        Text(
          'Pick a question above, or search your moments.',
          style: VoiceMemoryTypography.bodyStyle(
            color: AppColors.textSecondary,
          ).copyWith(fontSize: 14, height: 1.5),
        ),
      ];
    }

    if (_results.isEmpty) {
      return [
        Text(
          'Record a few moments and ArchiveMe will have more to find.',
          style: VoiceMemoryTypography.bodyStyle(
            color: AppColors.textSecondary,
          ).copyWith(fontSize: 14, height: 1.5),
        ),
      ];
    }

    return [
      for (final result in _results) ...[
        _resultCard(result),
        const SizedBox(height: AppSpacing.sm),
      ],
    ];
  }

  Widget _resultCard(ArchiveSearchResult result) {
    final resultLabel = keyMomentResultLabel(result.resultHint);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _warmSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _warmBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _dayLabel(result.date),
            style: VoiceMemoryTypography.metadataStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.title,
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(
              fontSize: 16,
            ),
          ),
          if (result.body.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              result.body,
              style: VoiceMemoryTypography.bodyStyle(
                color: AppColors.textPrimary,
              ).copyWith(fontSize: 14, height: 1.4),
            ),
          ],
          if (result.tags.isNotEmpty || resultLabel != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              [?resultLabel, ...result.tags].join(' · '),
              style: VoiceMemoryTypography.metadataStyle(
                color: AppColors.textSecondary,
              ).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              if (result.momentId != null)
                TextButton(
                  onPressed: () => _openMoment(result),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Open moment'),
                ),
              if (result.nextCheck != null && result.nextCheck!.isNotEmpty)
                TextButton(
                  onPressed: () => _useCheck(result),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Use this check'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _openMoment(ArchiveSearchResult result) {
    ActivationTracker.trackAskArchiveResultOpened();
    KeyMoment? moment;
    for (final m in _all) {
      if (m.id == result.momentId) {
        moment = m;
        break;
      }
    }
    if (moment != null) {
      context.push('/moment-detail', extra: moment);
    }
  }

  void _useCheck(ArchiveSearchResult result) {
    ActivationTracker.trackAskArchiveUseCheckTapped();
    if (result.nextCheck case final check?) {
      context.go('/record', extra: {'prefillCheck': check});
    }
  }

  String _dayLabel(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) return '';
    final now = DateTime.now();
    if (_isSameDay(date, now)) return 'Today';
    if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
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
