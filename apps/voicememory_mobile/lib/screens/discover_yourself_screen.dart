import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/archive_mobile_spacing.dart';
import '../design/empty_archive_experience.dart';
import '../design/user_facing_date.dart';
import '../features/archive_state_object/archive_state_object.dart';
import '../features/discover/discover_analytics.dart';
import '../features/discover/discover_engine.dart';
import '../features/discover/discover_models.dart';
import '../features/retention/archive_discovery_service.dart';
import '../features/retention/archive_progress_identity.dart';
import '../features/weekly_story/weekly_story_engine.dart';
import '../features/weekly_story/weekly_story_models.dart';
import '../models/journal_entry.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';
import '../design/warm_archive_copy.dart';
import '../theme/discover_section_style.dart';
import '../theme/voicememory_colors.dart';
import '../theme/voicememory_typography.dart';
import '../theme/voicememory_cards.dart';
import '../widgets/archive_discovery_banner.dart';
import '../widgets/archive_evidence_panel.dart';
import '../widgets/archive_progress_identity_card.dart';
import '../widgets/weekly_archive_story_card.dart';
import '../widgets/archive_why_button.dart';
import '../widgets/your_archive_noticed_section.dart';
import '../widgets/early_archive_insight_card.dart';
import '../widgets/daily_archive_noticed_section.dart';
import '../widgets/archive_challenge_section.dart';
import '../features/archive_explanations/explanation_models.dart';

/// Self-discovery dashboard — longitudinal insights from the local archive.
class DiscoverYourselfScreen extends StatefulWidget {
  const DiscoverYourselfScreen({super.key});

  @override
  State<DiscoverYourselfScreen> createState() => _DiscoverYourselfScreenState();
}

class _DiscoverYourselfScreenState extends State<DiscoverYourselfScreen> {
  final _engine = const DiscoverYourselfEngine();
  List<JournalEntry> _entries = [];
  DiscoverYourselfSnapshot? _snapshot;
  ArchiveStateObjectV3? _state;
  Map<String, int>? _themeBaseline;
  bool _loadingInsights = false;
  bool _intentionalEmpty = false;
  String? _selectedAskPrompt;
  DiscoverArchiveAnswer? _askAnswer;
  ArchiveDiscoveryNotice? _discoveryNotice;
  ArchiveProgressIdentity? _progressIdentity;
  ArchiveProgressIdentity? _previousProgressIdentity;
  WeeklyArchiveStory? _weeklyStory;

  @override
  void initState() {
    super.initState();
    _seedFromLocalJournal();
    _load();
  }

  void _seedFromLocalJournal() {
    final entries = peekJournalEntriesSync(AppServices.instance.journalStore);
    if (!isIntentionalEmptyArchive(entries)) return;
    _applyIntentionalEmptyState(entries);
  }

  void _applyIntentionalEmptyState(List<JournalEntry> entries) {
    final state = buildArchiveStateObjectV3(entries: entries);
    final snapshot = _engine.build(
      entries: entries,
      state: state,
      themeBaseline: _themeBaseline,
      useCache: true,
    );
    _entries = entries;
    _state = state;
    _snapshot = snapshot;
    _intentionalEmpty = true;
    _loadingInsights = false;
    _progressIdentity = const ArchiveProgressIdentityBuilder().build(
      entries,
      currentBelief: state?.belief,
    );
  }

  Future<void> _load({bool invalidateCache = false}) async {
    if (invalidateCache) _engine.cache.invalidate();
    final entries = await AppServices.instance.journal.loadAll();

    if (!mounted) return;

    if (isIntentionalEmptyArchive(entries)) {
      setState(() => _applyIntentionalEmptyState(entries));
      DiscoverAnalytics.discoverOpened(reflectionCount: entries.length);
      return;
    }

    setState(() {
      _entries = entries;
      _intentionalEmpty = false;
      _loadingInsights = _snapshot == null;
    });

    final state = buildArchiveStateObjectV3(entries: entries);
    final snapshot = _engine.build(
      entries: entries,
      state: state,
      themeBaseline: _themeBaseline,
      useCache: !invalidateCache,
    );

    if (!mounted) return;
    if (snapshot.themes.isNotEmpty) {
      _themeBaseline = {
        for (final t in snapshot.themes) t.themeKey: t.frequency,
      };
    }

    final identity = const ArchiveProgressIdentityBuilder().build(
      entries,
      currentBelief: state?.belief,
    );
    final notice = await ArchiveDiscoveryService(
      AppServices.instance.prefs,
    ).loadActiveNotice(entries: entries, state: state);
    final weekly = const WeeklyStoryEngine().build(
      entries: entries,
      state: state,
    );

    if (!mounted) return;
    setState(() {
      _previousProgressIdentity = _progressIdentity;
      _progressIdentity = identity;
      _discoveryNotice = notice;
      _weeklyStory = weekly;
      _entries = entries;
      _state = state;
      _snapshot = snapshot;
      _loadingInsights = false;
      _intentionalEmpty = false;
    });
    DiscoverAnalytics.discoverOpened(reflectionCount: entries.length);
  }

  void _onAskPrompt(String prompt) {
    final answer = _engine.answerArchiveQuestion(
      prompt: prompt,
      entries: _entries,
      state: _state,
    );
    DiscoverAnalytics.archiveQuestionAsked(prompt: prompt);
    setState(() {
      _selectedAskPrompt = prompt;
      _askAnswer = answer;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_intentionalEmpty) {
      return Scaffold(
        body: RefreshIndicator(
          onRefresh: () => _load(invalidateCache: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: IntentionalEmptyArchiveView(
                  onRecord: () => goToFirstRecording(context),
                  fillViewport: false,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_loadingInsights || _snapshot == null) {
      return Scaffold(
        body: RefreshIndicator(
          onRefresh: () => _load(invalidateCache: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Loading your archive…',
                      style: VoiceMemoryTypography.bodyStyle(
                        color: VoiceMemoryColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final snapshot = _snapshot!;
    final mode = snapshot.mode;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _load(invalidateCache: true),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: ArchiveMobileSpacing.pagePadding,
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Text(
                    'Discover Yourself',
                    style: VoiceMemoryTypography.pageTitleStyle(),
                  ),
                  if (_entries.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Belief changes, themes, and chapters from your recordings.',
                      style: VoiceMemoryTypography.bodyStyle(
                        color: VoiceMemoryColors.textSecondary,
                      ),
                    ),
                  ],
                  if (_entries.isNotEmpty) ...[
                    const SizedBox(height: ArchiveMobileSpacing.lg),
                    DailyArchiveNoticedSection(
                      entries: _entries,
                      state: _state,
                    ),
                  ],
                  if (_entries.isNotEmpty) ...[
                    ArchiveChallengeSection(entries: _entries, state: _state),
                  ],
                  if (_progressIdentity != null) ...[
                    const SizedBox(height: ArchiveMobileSpacing.lg),
                    ArchiveProgressIdentityCard(
                      identity: _progressIdentity!,
                      previous: _previousProgressIdentity,
                    ),
                  ],
                  if (_discoveryNotice != null) ...[
                    const SizedBox(height: ArchiveMobileSpacing.md),
                    ArchiveDiscoveryBanner(
                      notice: _discoveryNotice!,
                      onViewed: () => setState(() => _discoveryNotice = null),
                    ),
                  ],
                  if (_entries.isNotEmpty) ...[
                    const SizedBox(height: ArchiveMobileSpacing.lg),
                    YourArchiveNoticedSection(entries: _entries, state: _state),
                  ],
                  if (_entries.isNotEmpty) ...[
                    const SizedBox(height: ArchiveMobileSpacing.lg),
                    EarlyArchiveInsightSection(
                      entries: _entries,
                      surface: 'discover_yourself',
                    ),
                  ],
                  if (_entries.isNotEmpty &&
                      mode.emptyStateMessage.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _EmptyBanner(message: mode.emptyStateMessage),
                  ],
                  if (snapshot.belief != null) ...[
                    const SizedBox(height: ArchiveMobileSpacing.lg),
                    _BeliefSection(
                      card: snapshot.belief!,
                      entries: _entries,
                      state: _state,
                    ),
                  ],
                  if (snapshot.beliefChanges.isNotEmpty) ...[
                    const SizedBox(height: ArchiveMobileSpacing.lg),
                    _BeliefChangesSection(
                      changes: snapshot.beliefChanges,
                      entries: _entries,
                      state: _state,
                    ),
                  ],
                  if (snapshot.themes.isNotEmpty) ...[
                    const SizedBox(height: ArchiveMobileSpacing.lg),
                    _ThemesSection(themes: snapshot.themes, entries: _entries),
                  ],
                  if (snapshot.showFullSections &&
                      snapshot.contradictions.isNotEmpty) ...[
                    const SizedBox(height: ArchiveMobileSpacing.lg),
                    _ContradictionsSection(
                      items: snapshot.contradictions,
                      entries: _entries,
                    ),
                  ],
                  if (snapshot.showFullSections &&
                      snapshot.blindSpots.isNotEmpty) ...[
                    const SizedBox(height: ArchiveMobileSpacing.lg),
                    _BlindSpotsSection(
                      spots: snapshot.blindSpots,
                      entries: _entries,
                    ),
                  ],
                  if (snapshot.showFullSections &&
                      snapshot.chapters.isNotEmpty) ...[
                    const SizedBox(height: ArchiveMobileSpacing.lg),
                    _ChaptersSection(
                      chapters: snapshot.chapters,
                      entries: _entries,
                      onOpen: (id) =>
                          context.push('/discover-yourself/chapter/$id'),
                    ),
                  ],
                  if (_weeklyStory != null) ...[
                    const SizedBox(height: ArchiveMobileSpacing.lg),
                    WeeklyArchiveStoryCard(story: _weeklyStory!),
                  ],
                  if (snapshot.showEarlyInsights) ...[
                    const SizedBox(height: ArchiveMobileSpacing.lg),
                    _AskArchiveSection(
                      prompts: snapshot.askPrompts,
                      selectedPrompt: _selectedAskPrompt,
                      answer: _askAnswer,
                      entries: _entries,
                      onPrompt: _onAskPrompt,
                    ),
                  ],
                  const SizedBox(height: 48),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label, {this.tooltip, this.kind});

  final String label;
  final String? tooltip;
  final DiscoverSectionKind? kind;

  @override
  Widget build(BuildContext context) {
    final style = kind != null ? DiscoverSectionStyle.forKind(kind!) : null;
    final title = Row(
      children: [
        if (style != null) ...[
          Icon(style.icon, size: 18, color: style.accent),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            label,
            style: VoiceMemoryTypography.sectionLabelStyle(
              accent: style?.accent ?? VoiceMemoryColors.primaryIndigo,
            ),
          ),
        ),
      ],
    );
    if (tooltip == null) return Semantics(header: true, child: title);
    return Semantics(
      header: true,
      label: label,
      child: Tooltip(message: tooltip!, child: title),
    );
  }
}

class _EmptyBanner extends StatelessWidget {
  const _EmptyBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message, style: const TextStyle(height: 1.45)),
      ),
    );
  }
}

class _BeliefSection extends StatelessWidget {
  const _BeliefSection({required this.card, required this.entries, this.state});

  final DiscoverBeliefCard card;
  final List<JournalEntry> entries;
  final ArchiveStateObjectV3? state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          WarmArchiveCopy.beliefSectionTitle,
          tooltip: 'A story the archive hears often in your recordings',
          kind: DiscoverSectionKind.belief,
        ),
        const SizedBox(height: 8),
        Container(
          decoration: VoiceMemoryCards.standard(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      card.statement,
                      style: VoiceMemoryTypography.cardTitleStyle(),
                    ),
                  ),
                  ArchiveWhyButton(
                    ref: ArchiveInsightRef.belief(),
                    entries: entries,
                    state: state,
                    surface: 'discover_belief',
                    compact: true,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                WarmArchiveCopy.confidenceStrengthLine(card.confidencePercent),
                semanticsLabel: WarmArchiveCopy.confidenceStrengthSemantics(
                  card.confidencePercent,
                ),
              ),
              Text('Evidence: ${card.evidenceCount} entries'),
              if (card.firstObserved != null)
                Text(
                  'First observed: ${formatUserFacingMonthYear(card.firstObserved!)}',
                ),
              if (card.lastReinforced != null)
                Text(
                  'Last reinforced: ${formatUserFacingMonthYear(card.lastReinforced!)}',
                ),
              ArchiveEvidenceExpandable(
                entries: card.supportingEntries,
                analyticsContext: 'belief',
                buttonLabel: 'Show Evidence',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

ArchiveInsightRef _whyRefForBeliefChange(DiscoverBeliefChange c, int index) {
  switch (c.type) {
    case 'newBeliefEmerging':
    case 'confidenceIncrease':
      return ArchiveInsightRef.beliefChange(index);
    default:
      return ArchiveInsightRef.belief();
  }
}

class _BeliefChangesSection extends StatelessWidget {
  const _BeliefChangesSection({
    required this.changes,
    required this.entries,
    this.state,
  });

  final List<DiscoverBeliefChange> changes;
  final List<JournalEntry> entries;
  final ArchiveStateObjectV3? state;

  @override
  Widget build(BuildContext context) {
    final byId = {for (final e in entries) e.id: e};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          WarmArchiveCopy.beliefChangesSectionTitle,
          tooltip: 'Stories that shifted across your recordings',
          kind: DiscoverSectionKind.beliefChanges,
        ),
        const SizedBox(height: 8),
        ...changes.asMap().entries.map((entry) {
          final index = entry.key;
          final c = entry.value;
          final evidence = [
            for (final id in c.evidenceEntryIds)
              if (byId[id] != null) byId[id]!,
          ];
          final whyRef = _whyRefForBeliefChange(c, index);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.headline,
                      style: VoiceMemoryTypography.metadataStyle(
                        color: VoiceMemoryColors.beliefChangeGold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '“${c.beliefStatement}”',
                      style: VoiceMemoryTypography.cardTitleStyle(),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      WarmArchiveCopy.confidenceConcept,
                      style: VoiceMemoryTypography.metadataStyle(),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      WarmArchiveCopy.beliefChangeNarrative(
                        priorLabel: c.priorLabel,
                        priorPercent: c.priorPercent,
                        currentLabel: c.currentLabel,
                        currentPercent: c.currentPercent,
                      ),
                      style: VoiceMemoryTypography.bodyStyle().copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ArchiveWhyButton(
                          ref: whyRef,
                          entries: entries,
                          state: state,
                          surface: 'discover_belief_change',
                          compact: true,
                        ),
                        const Spacer(),
                        Text(
                          '${c.evidenceEntryIds.length} recordings',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.muted,
                          ),
                        ),
                      ],
                    ),
                    if (evidence.isNotEmpty)
                      ArchiveEvidenceExpandable(
                        entries: evidence,
                        analyticsContext: 'belief_change',
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _ThemesSection extends StatelessWidget {
  const _ThemesSection({required this.themes, required this.entries});

  final List<DiscoverThemeInsight> themes;
  final List<JournalEntry> entries;

  @override
  Widget build(BuildContext context) {
    final byId = {for (final e in entries) e.id: e};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          WarmArchiveCopy.themesSectionTitle,
          kind: DiscoverSectionKind.themes,
        ),
        const SizedBox(height: 8),
        ...themes.map((t) {
          final evidence = [
            for (final id in t.evidenceEntryIds)
              if (byId[id] != null) byId[id]!,
          ];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          t.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        '${t.frequency} · ${WarmArchiveCopy.themeTrendBrief(t.trend)}',
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 12,
                        ),
                      ),
                      ArchiveWhyButton(
                        ref: ArchiveInsightRef.theme(t.themeKey),
                        entries: entries,
                        surface: 'discover_theme',
                        compact: true,
                      ),
                    ],
                  ),
                  if (evidence.isNotEmpty)
                    ArchiveEvidenceExpandable(
                      entries: evidence,
                      analyticsContext: 'theme:${t.themeKey}',
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _ContradictionsSection extends StatelessWidget {
  const _ContradictionsSection({required this.items, required this.entries});

  final List<DiscoverContradictionInsight> items;
  final List<JournalEntry> entries;

  @override
  Widget build(BuildContext context) {
    final byId = {for (final e in entries) e.id: e};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          WarmArchiveCopy.contradictionsSectionTitle,
          kind: DiscoverSectionKind.contradictions,
        ),
        const SizedBox(height: 8),
        const Text(
          WarmArchiveCopy.contradictionsLead,
          style: TextStyle(fontSize: 13, color: AppTheme.muted),
        ),
        const SizedBox(height: 8),
        ...items.map((c) {
          final evidence = [
            if (byId[c.entryIdA] != null) byId[c.entryIdA]!,
            if (byId[c.entryIdB] != null) byId[c.entryIdB]!,
          ];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '“${c.statementA}”',
                    style: const TextStyle(fontSize: 15),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text('vs', style: TextStyle(color: AppTheme.muted)),
                  ),
                  Text(
                    '“${c.statementB}”',
                    style: const TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${formatUserFacingDate(c.dateA)} · ${formatUserFacingDate(c.dateB)}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                  ),
                  Text(
                    WarmArchiveCopy.confidenceStrengthLine(c.confidenceScore),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ArchiveWhyButton(
                      ref: ArchiveInsightRef.contradiction(
                        entryIdA: c.entryIdA,
                        entryIdB: c.entryIdB,
                      ),
                      entries: entries,
                      surface: 'discover_contradiction',
                      compact: true,
                    ),
                  ),
                  if (evidence.isNotEmpty)
                    ArchiveEvidenceExpandable(
                      entries: evidence,
                      analyticsContext: 'contradiction',
                    ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 4),
        const Text(
          'Contradictions are normal. They often reveal competing needs.',
          style: TextStyle(fontSize: 13, color: AppTheme.muted, height: 1.4),
        ),
      ],
    );
  }
}

class _BlindSpotsSection extends StatelessWidget {
  const _BlindSpotsSection({required this.spots, required this.entries});

  final List<DiscoverBlindSpotCard> spots;
  final List<JournalEntry> entries;

  @override
  Widget build(BuildContext context) {
    final byId = {for (final e in entries) e.id: e};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          'BLIND SPOTS',
          kind: DiscoverSectionKind.blindSpots,
        ),
        const SizedBox(height: 8),
        ...spots.map((s) {
          final evidence = [
            for (final id in s.entryIds)
              if (byId[id] != null) byId[id]!,
          ];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          s.headline,
                          style: const TextStyle(fontSize: 15, height: 1.35),
                        ),
                      ),
                      ArchiveWhyButton(
                        ref: ArchiveInsightRef.blindSpot(s.id),
                        entries: entries,
                        surface: 'discover_blind_spot',
                        compact: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${WarmArchiveCopy.confidenceStrengthLine(s.confidence)} · '
                    '${s.evidenceCount} recordings',
                    style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                  ),
                  const SizedBox(height: 4),
                  Text(s.observation),
                  if (evidence.isNotEmpty)
                    ArchiveEvidenceExpandable(
                      entries: evidence,
                      analyticsContext: 'blind_spot:${s.id}',
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _ChaptersSection extends StatelessWidget {
  const _ChaptersSection({
    required this.chapters,
    required this.entries,
    required this.onOpen,
  });

  final List<DiscoverChapterSummary> chapters;
  final List<JournalEntry> entries;
  final void Function(String id) onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          'LIFE CHAPTERS',
          kind: DiscoverSectionKind.chapters,
        ),
        const SizedBox(height: 8),
        ...chapters.map((c) {
          final byId = {for (final e in entries) e.id: e};
          final evidence = [
            for (final id in c.entryIds)
              if (byId[id] != null) byId[id]!,
          ];
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppTheme.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(width: 2, height: 48, color: AppTheme.accent),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(c.title),
                            subtitle: Text(
                              '${formatUserFacingMonthYear(c.startDate)} – ${formatUserFacingMonthYear(c.endDate)}\n'
                              '${c.summary}\n${c.entryCount} entries',
                            ),
                            isThreeLine: true,
                            onTap: () => onOpen(c.id),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ArchiveWhyButton(
                              ref: ArchiveInsightRef.chapter(c.id),
                              entries: entries,
                              surface: 'discover_chapter',
                              compact: true,
                            ),
                          ),
                          if (evidence.isNotEmpty)
                            ArchiveEvidenceExpandable(
                              entries: evidence.take(4).toList(),
                              analyticsContext: 'chapter:${c.id}',
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _AskArchiveSection extends StatelessWidget {
  const _AskArchiveSection({
    required this.prompts,
    required this.selectedPrompt,
    required this.answer,
    required this.entries,
    required this.onPrompt,
  });

  final List<String> prompts;
  final String? selectedPrompt;
  final DiscoverArchiveAnswer? answer;
  final List<JournalEntry> entries;
  final void Function(String prompt) onPrompt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          'ASK YOUR ARCHIVE',
          kind: DiscoverSectionKind.askArchive,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: prompts.map((p) {
            return ActionChip(
              label: Text(p),
              onPressed: () => onPrompt(p),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.standard,
            );
          }).toList(),
        ),
        if (answer != null && selectedPrompt != null) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          selectedPrompt!,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      ArchiveWhyButton(
                        ref: ArchiveInsightRef.askArchive(selectedPrompt!),
                        entries: entries,
                        askPrompt: selectedPrompt,
                        askCitedEntryIds: answer!.citedEntryIds,
                        surface: 'discover_ask',
                        compact: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final line in answer!.answerLines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(line, style: const TextStyle(height: 1.4)),
                    ),
                  if (answer!.citedEntryIds.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ArchiveEvidenceExpandable(
                      entries: [
                        for (final id in answer!.citedEntryIds)
                          if (entries.any((e) => e.id == id))
                            entries.firstWhere((e) => e.id == id),
                      ],
                      analyticsContext: 'ask_archive',
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
