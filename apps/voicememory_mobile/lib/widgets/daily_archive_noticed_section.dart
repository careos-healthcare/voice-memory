import 'package:flutter/material.dart';

import '../features/archive_explanations/archive_explanation_navigation.dart';
import '../features/archive_state_object/archive_state_object.dart';
import '../features/daily_discoveries/daily_discovery_engine.dart';
import '../features/daily_discoveries/daily_discovery_models.dart';
import '../features/daily_discoveries/daily_discovery_store.dart';
import '../models/journal_entry.dart';
import '../services/app_services.dart';
import '../services/product_analytics.dart';
import '../theme/voicememory_colors.dart';
import '../theme/voicememory_typography.dart';

/// Archive home — one high-value discovery for today when new entries arrive.
class DailyArchiveNoticedSection extends StatefulWidget {
  const DailyArchiveNoticedSection({
    super.key,
    required this.entries,
    this.state,
  });

  final List<JournalEntry> entries;
  final ArchiveStateObjectV3? state;

  @override
  State<DailyArchiveNoticedSection> createState() =>
      _DailyArchiveNoticedSectionState();
}

class _DailyArchiveNoticedSectionState extends State<DailyArchiveNoticedSection> {
  DailyDiscovery? _discovery;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(DailyArchiveNoticedSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entries.length != widget.entries.length) {
      _load();
    } else if (widget.entries.isNotEmpty && oldWidget.entries.isNotEmpty) {
      final oldSorted = [...oldWidget.entries]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final newSorted = [...widget.entries]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      if (oldSorted.last.id != newSorted.last.id) _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final store = DailyDiscoveryStore(AppServices.instance.prefs);
    final discovery = await const DailyDiscoveryEngine().loadTodayDiscovery(
      store: store,
      entries: widget.entries,
      state: widget.state,
    );
    if (!mounted) return;
    setState(() {
      _discovery = discovery;
      _loading = false;
    });
    if (discovery != null) {
      ProductAnalytics.trackStrings('daily_discovery_surfaced', {
        'type': discovery.type.name,
        'id': discovery.id,
      });
    }
  }

  Future<void> _openWhy(BuildContext context, DailyDiscovery discovery) async {
    ProductAnalytics.trackStrings('daily_discovery_why_opened', {
      'type': discovery.type.name,
    });
    openArchiveExplanation(
      context,
      ref: discovery.insightRef,
      askPrompt: discovery.insightRef.askPrompt,
    );
    final store = DailyDiscoveryStore(AppServices.instance.prefs);
    await const DailyDiscoveryEngine().acknowledgeDiscovery(
      store: store,
      discovery: discovery,
      entries: widget.entries,
      state: widget.state,
    );
    if (mounted) setState(() => _discovery = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _discovery == null) return const SizedBox.shrink();

    final d = _discovery!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'YOUR ARCHIVE NOTICED',
          style: VoiceMemoryTypography.sectionLabelStyle(
            accent: VoiceMemoryColors.discoveryGold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Today',
          style: VoiceMemoryTypography.metadataStyle(
            color: VoiceMemoryColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: VoiceMemoryColors.discoveryGoldBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: VoiceMemoryColors.discoveryGoldBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '“${d.summary}”',
                style: VoiceMemoryTypography.bodyStyle().copyWith(
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _openWhy(context, d),
                style: TextButton.styleFrom(
                  foregroundColor: VoiceMemoryColors.primaryIndigo,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(48, 44),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Why?',
                  style: VoiceMemoryTypography.bodyStyle(
                    color: VoiceMemoryColors.primaryIndigo,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
