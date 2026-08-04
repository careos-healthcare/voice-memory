import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../billing/archive_entitlement_reader.dart';
import '../config/screenshot_mode.dart';
import '../config/screenshot_sample_data.dart';
import '../features/activation/activation_tracker.dart';
import '../features/moments/key_moment_model.dart';
import '../features/moments/key_moment_store.dart';
import '../features/moments/moment_tag_model.dart';
import '../product/consumer_ui_copy.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_typography.dart';

enum _MomentFilter { today, yesterday, thisWeek, search }

/// The Key Moments timeline — find and revisit the moments that mattered, by
/// day. Local-only, simple, and non-judgemental.
class KeyMomentsScreen extends StatefulWidget {
  const KeyMomentsScreen({
    super.key,
    this.loader,
    this.entitlementReader,
    this.firstLoopClosed,
  });

  /// Loads the moments to show. Defaults to the local store; injectable so
  /// widget tests never block on real file I/O.
  final Future<List<KeyMoment>> Function()? loader;

  /// Overrides Pro status for tests.
  final ArchiveEntitlementReader? entitlementReader;

  /// When null, loaded from first-loop coordinator.
  final bool? firstLoopClosed;

  @override
  State<KeyMomentsScreen> createState() => _KeyMomentsScreenState();
}

class _KeyMomentsScreenState extends State<KeyMomentsScreen> {
  static const Color _warmSurface = Color(0xFFFFFBF5);
  static const Color _warmBorder = Color(0xFFF5E6D3);

  final TextEditingController _searchController = TextEditingController();

  /// Tags offered as quick filters, in display order. `null` means "All".
  static const List<MomentTag> _tagFilters = [
    MomentTag.work,
    MomentTag.family,
    MomentTag.pressure,
    MomentTag.worry,
    MomentTag.tired,
    MomentTag.lighter,
  ];

  List<KeyMoment> _all = const [];
  _MomentFilter _filter = _MomentFilter.today;
  MomentTag? _tagFilter;
  String _query = '';
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
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

  List<KeyMoment> get _byDateOrSearch {
    final pool = _all;
    final now = DateTime.now();
    switch (_filter) {
      case _MomentFilter.today:
        return pool.where((m) => _isSameDay(m.date, now)).toList();
      case _MomentFilter.yesterday:
        final y = now.subtract(const Duration(days: 1));
        return pool.where((m) => _isSameDay(m.date, y)).toList();
      case _MomentFilter.thisWeek:
        final weekAgo = now.subtract(const Duration(days: 7));
        return pool.where((m) => m.date.isAfter(weekAgo)).toList();
      case _MomentFilter.search:
        final q = _query.trim().toLowerCase();
        if (q.isEmpty) return pool;
        return pool.where((m) {
          final haystack = [
            m.originalText,
            m.shortSummary,
            m.title,
            m.patternTitle ?? '',
            m.tags.join(' '),
            m.dayKey,
          ].join(' ').toLowerCase();
          return haystack.contains(q);
        }).toList();
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<KeyMoment> get _visible {
    final byDate = _byDateOrSearch;
    final tag = _tagFilter;
    if (tag == null) return byDate;
    return byDate.where((m) => m.hasTag(tag)).toList();
  }

  Future<void> _selectFilter(_MomentFilter filter) async {
    setState(() => _filter = filter);
    if (filter == _MomentFilter.search) {
      ActivationTracker.trackKeyMomentSearchUsed();
    }
  }

  String _dateLabel(DateTime date) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Key moments'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _filters(),
                  if (_filter == _MomentFilter.search) _searchField(),
                  _tagFilterRow(),
                  Expanded(child: _list()),
                ],
              ),
      ),
    );
  }

  Widget _filters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: Wrap(
        spacing: AppSpacing.xs,
        children: [
          _filterChip('Today', _MomentFilter.today),
          _filterChip('Yesterday', _MomentFilter.yesterday),
          _filterChip('This week', _MomentFilter.thisWeek),
          _filterChip('Search', _MomentFilter.search),
        ],
      ),
    );
  }

  Widget _tagFilterRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        0,
      ),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _tagChip('All', null),
            for (final tag in _tagFilters)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xs),
                child: _tagChip(tag.label, tag),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tagChip(String label, MomentTag? tag) {
    final selected = _tagFilter == tag;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _tagFilter = tag),
      backgroundColor: _warmSurface,
      selectedColor: AppColors.accentPrimary.withValues(alpha: 0.15),
      labelStyle:
          VoiceMemoryTypography.bodyStyle(
            color: selected ? AppColors.accentPrimary : AppColors.textSecondary,
          ).copyWith(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: _warmBorder),
      ),
    );
  }

  Widget _filterChip(String label, _MomentFilter filter) {
    final selected = _filter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => _selectFilter(filter),
      backgroundColor: _warmSurface,
      selectedColor: AppColors.accentPrimary.withValues(alpha: 0.15),
      labelStyle:
          VoiceMemoryTypography.bodyStyle(
            color: selected ? AppColors.accentPrimary : AppColors.textSecondary,
          ).copyWith(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: _warmBorder),
      ),
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _query = v),
        decoration: InputDecoration(
          hintText: 'Search your moments',
          prefixIcon: const Icon(Icons.search, size: 20),
          isDense: true,
          filled: true,
          fillColor: _warmSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: _warmBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: _warmBorder),
          ),
        ),
      ),
    );
  }

  Widget _list() {
    final items = _visible;
    if (items.isEmpty) return _emptyState();
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: _emptyState(),
          )
        else
          ...items.expand((moment) sync* {
            yield _momentCard(moment);
            yield const SizedBox(height: AppSpacing.sm);
          }),
      ],
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          ConsumerUiCopy.archiveMomentsMatterLine,
          textAlign: TextAlign.center,
          style: VoiceMemoryTypography.bodyStyle(
            color: AppColors.textSecondary,
          ).copyWith(fontSize: 15, height: 1.5),
        ),
      ),
    );
  }

  Widget _momentCard(KeyMoment moment) {
    final resultLabel = keyMomentResultLabel(moment.resultHint);
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
            _dateLabel(moment.date),
            style: VoiceMemoryTypography.metadataStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            moment.title,
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(
              fontSize: 16,
            ),
          ),
          if (moment.shortSummary.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              moment.shortSummary,
              style: VoiceMemoryTypography.bodyStyle(
                color: AppColors.textPrimary,
              ).copyWith(fontSize: 14, height: 1.4),
            ),
          ],
          if (moment.patternTitle != null || resultLabel != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                if (moment.patternTitle != null)
                  _tag(moment.patternTitle!, AppColors.accentPrimary),
                if (resultLabel != null)
                  _tag(resultLabel, AppColors.textSecondary),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _open(moment),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Open moment'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: VoiceMemoryTypography.metadataStyle(
          color: color,
        ).copyWith(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  void _open(KeyMoment moment) {
    ActivationTracker.trackKeyMomentOpened();
    context.push('/moment-detail', extra: moment);
  }
}
