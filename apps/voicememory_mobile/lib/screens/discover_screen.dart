import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/archive_state_object/archive_state_object.dart';
import '../features/discover/discover_local.dart';
import '../models/entitlement.dart';
import '../models/journal_entry.dart';
import '../services/app_services.dart';
import '../design/empty_archive_experience.dart';
import '../design/warm_archive_copy.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/archive_mobile_page_template.dart';
import '../widgets/archive_watch_card_mobile.dart';
import '../widgets/value_moment_paywall.dart';
import '../widgets/top_themes_section.dart';
import '../features/theme_tracking/theme_tracker_service.dart';
import '../widgets/early_archive_insight_card.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  List<JournalEntry> _entries = [];
  Map<String, int>? _themeBaseline;
  DiscoverLocalFeed? _feed;
  PremiumEntitlements? _entitlements;
  bool _showPaywall = false;
  bool _gateContinuity = false;

  @override
  void initState() {
    super.initState();
    final seeded = peekJournalEntriesSync(AppServices.instance.journalStore);
    if (isIntentionalEmptyArchive(seeded)) {
      _entries = seeded;
      _feed = DiscoverLocalEngine.build(entries: seeded, baselineThemes: null);
    }
    _load();
  }

  Future<void> _load() async {
    final s = AppServices.instance;
    await s.paywall.recordDiscoverVisit();
    final entries = await s.journal.loadEligible();

    if (!mounted) return;
    if (isIntentionalEmptyArchive(entries)) {
      setState(() {
        _entries = entries;
        _feed = DiscoverLocalEngine.build(
          entries: entries,
          baselineThemes: null,
        );
      });
      return;
    }
    final baselineRaw = await s.prefs.discoverBaseline;
    final baseline = baselineRaw?.map(
      (k, v) => MapEntry(k, (v as num).toInt()),
    );
    final themeBaseline = ThemeTrackerService.canonicalBaselineFromStored(
      baseline,
    );
    var feed = DiscoverLocalEngine.build(
      entries: entries,
      baselineThemes: baseline,
    );
    if (!feed.hasBaseline && entries.isNotEmpty) {
      await s.prefs.setDiscoverBaseline(
        DiscoverLocalEngine.baselineFromEntries(entries),
      );
      feed = DiscoverLocalEngine.build(
        entries: entries,
        baselineThemes: DiscoverLocalEngine.baselineFromEntries(entries),
      );
    }
    await s.paywall.markFirstDiscoverSeen();
    final ent = await s.billing.loadEntitlements();
    final showPaywall = await s.paywall.shouldShowPostDiscover(
      entitlements: ent,
    );
    final gate = await s.paywall.shouldGateContinuity(entitlements: ent);
    if (mounted) {
      setState(() {
        _entries = entries;
        _themeBaseline = themeBaseline;
        _feed = feed;
        _entitlements = ent;
        _showPaywall = showPaywall;
        _gateContinuity = gate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = _feed;
    final state = buildArchiveStateObjectV3(entries: _entries);

    if (isIntentionalEmptyArchive(_entries)) {
      return Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: const [
              SliverFillRemaining(
                hasScrollBody: false,
                child: IntentionalEmptyArchiveView(fillViewport: false),
              ),
            ],
          ),
        ),
      );
    }

    return ArchiveMobilePageTemplate(
      backgroundColor: AppColors.backgroundPrimary,
      showArchiveExplanation: true,
      onRefresh: _load,
      eyebrow: 'Discover',
      title: 'What changed',
      lead: 'Belief changes, new evidence, and what to watch.',
      actionArea: TextButton(
        onPressed: () => context.go('/archive-belief'),
        child: const Text('Back to Archive'),
      ),
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state != null &&
              !state.hasMinimumEvidence &&
              !isIntentionalEmptyArchive(_entries)) ...[
            EmptyArchivePanel.needMoreEvidence(),
            const SizedBox(height: 16),
          ] else if (state != null &&
              state.hasMinimumEvidence &&
              !isIntentionalEmptyArchive(_entries)) ...[
            Text(
              state.changeSummary,
              style: const TextStyle(color: AppTheme.muted, height: 1.45),
            ),
            const SizedBox(height: 16),
          ],
          TopThemesSection(entries: _entries, baselineCounts: _themeBaseline),
          const SizedBox(height: 16),
          EarlyArchiveInsightSection(entries: _entries, surface: 'discover'),
          const SizedBox(height: 20),
          if (feed == null)
            const Center(child: CircularProgressIndicator())
          else if (!feed.hasBaseline)
            const Text(
              'Return after another reflection to see what may have changed.',
              style: TextStyle(color: AppTheme.muted),
            )
          else if (feed.totalChanges == 0 && feed.evidenceMovements.isEmpty)
            const Text(
              'No stories have shifted in your archive yet.',
              style: TextStyle(color: AppTheme.muted),
            )
          else if (_gateContinuity)
            ValueMomentPaywallCard(
              surface: PaywallSurface.archiveContinuity,
              reflectionCount: _entries.length,
              entitlements: _entitlements,
              shouldShow: true,
            )
          else ...[
            _changes(WarmArchiveCopy.beliefChangesSectionTitle, [
              ...feed.strengthened,
              ...feed.weakened,
              ...feed.newItems,
            ]),
            _changes('New evidence', feed.evidenceMovements),
            if (state != null) ...[
              const SizedBox(height: 8),
              ArchiveWatchCardMobile(line: state.watchItem),
            ],
            ValueMomentPaywallCard(
              surface: PaywallSurface.discover,
              reflectionCount: _entries.length,
              entitlements: _entitlements,
              shouldShow: _showPaywall,
              onDismissed: () => setState(() => _showPaywall = false),
            ),
          ],
        ],
      ),
    );
  }

  Widget _changes(String title, List<DiscoverChangeItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          for (final item in items)
            ListTile(
              title: Text(item.title),
              subtitle: Text(item.detail),
              dense: true,
            ),
        ],
      ),
    );
  }
}
