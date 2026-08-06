import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:voicememory_mobile/design/archive_mobile_spacing.dart';
import 'package:voicememory_mobile/features/archive_explanation_v2/archive_explanation_v2_analytics.dart';
import 'package:voicememory_mobile/features/archive_explanation_v2/archive_interpretation_engine.dart';
import 'package:voicememory_mobile/features/archive_explanation_v2/archive_interpretation_models.dart';
import 'package:voicememory_mobile/features/archive_explanation_v2/archive_interpretation_store.dart';
import 'package:voicememory_mobile/features/archive_explanations/archive_explanation_analytics.dart';
import 'package:voicememory_mobile/features/archive_explanations/archive_explanation_engine.dart';
import 'package:voicememory_mobile/features/archive_explanations/archive_explanation_navigation.dart';
import 'package:voicememory_mobile/features/archive_explanations/explanation_models.dart';
import 'package:voicememory_mobile/features/archive_state_object/archive_state_object.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/voicememory_colors.dart';
import 'package:voicememory_mobile/theme/voicememory_typography.dart';
import 'package:voicememory_mobile/widgets/archive_interpretation_body.dart';
import 'package:voicememory_mobile/widgets/pushed_screen_shell.dart';

/// Evidence-backed interpretation journey for any archive insight.
class ArchiveExplanationScreen extends StatefulWidget {
  const ArchiveExplanationScreen({
    super.key,
    required this.routeId,
    this.routeArgs,
  });

  final String routeId;
  final ArchiveExplanationRouteArgs? routeArgs;

  @override
  State<ArchiveExplanationScreen> createState() =>
      _ArchiveExplanationScreenState();
}

ArchiveInsightRef? _contradictionRefFromId(String id) {
  if (id.contains('|')) {
    final parts = id.split('|');
    if (parts.length == 2) {
      return ArchiveInsightRef.contradiction(
        entryIdA: parts[0],
        entryIdB: parts[1],
      );
    }
  }
  if (id.startsWith('ctr-')) {
    final body = id.substring(4);
    final dash = body.indexOf('-');
    if (dash > 0 && dash < body.length - 1) {
      return ArchiveInsightRef.contradiction(
        entryIdA: body.substring(0, dash),
        entryIdB: body.substring(dash + 1),
      );
    }
  }
  return null;
}

class _ArchiveExplanationScreenState extends State<ArchiveExplanationScreen> {
  final _explanationEngine = const ArchiveExplanationEngine();
  final _interpretationEngine = const ArchiveInterpretationEngine();
  ArchiveInterpretation? _interpretation;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await AppServices.instance.journal.loadAll();
    final state = buildArchiveStateObjectV3(entries: entries);
    final decodedId = decodeArchiveExplanationRouteId(widget.routeId);
    final ref =
        widget.routeArgs?.ref ?? ArchiveInsightRef.parseRouteId(decodedId);
    if (ref == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final explanation = _explanationEngine.buildExplanation(
      ref: ref,
      entries: entries,
      state: state,
      askPromptAnswer: widget.routeArgs?.askPrompt,
      askCitedIds: widget.routeArgs?.askCitedEntryIds,
    );

    if (explanation == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final interpretation = _interpretationEngine.build(
      ref: ref,
      explanation: explanation,
      entries: entries,
    );

    final prefs = AppServices.instance.prefs;
    final store = ArchiveInterpretationStore(prefs);
    await store.markInterpretationViewed(
      insightId: explanation.insightId,
      kind: explanation.kind.name,
    );
    await ArchiveExplanationV2Analytics.interpretationOpened(
      insightId: explanation.insightId,
      kind: explanation.kind.name,
    );
    ArchiveExplanationAnalytics.whyOpened(insightKind: explanation.kind.name);
    if (interpretation != null && interpretation.hasTimeline) {
      ArchiveExplanationAnalytics.timelineOpened();
    }

    if (!mounted) return;
    setState(() {
      _interpretation = interpretation;
      _loading = false;
    });
  }

  Color _accentFor(ArchiveInsightKind kind) => switch (kind) {
    ArchiveInsightKind.belief ||
    ArchiveInsightKind.beliefChange ||
    ArchiveInsightKind.askArchive => VoiceMemoryColors.beliefIndigo,
    ArchiveInsightKind.theme => VoiceMemoryColors.themeLavender,
    ArchiveInsightKind.blindSpot => VoiceMemoryColors.blindSpotAmber,
    ArchiveInsightKind.contradiction => VoiceMemoryColors.contradictionRose,
    ArchiveInsightKind.chapter => VoiceMemoryColors.chapterBlue,
    ArchiveInsightKind.weeklyStory => VoiceMemoryColors.discoveryGold,
    ArchiveInsightKind.surprise => VoiceMemoryColors.discoveryGold,
    ArchiveInsightKind.challenge => VoiceMemoryColors.discoveryGold,
  };

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: 'Archive Explanation',
      showBottomDone: false,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _interpretation == null
          ? Center(
              child: Padding(
                padding: ArchiveMobileSpacing.pagePadding,
                child: Text(
                  'Not enough archive evidence to explain this insight yet.',
                  textAlign: TextAlign.center,
                  style: VoiceMemoryTypography.bodyStyle(
                    color: VoiceMemoryColors.textSecondary,
                  ),
                ),
              ),
            )
          : ArchiveInterpretationBody(
              interpretation: _interpretation!,
              accent: _accentFor(_interpretation!.kind),
              onOpenEntry: (id) => context.push('/entry/$id'),
              onOpenTheme: (key) {
                ArchiveExplanationAnalytics.relatedThemeOpened(themeKey: key);
                openArchiveExplanation(
                  context,
                  ref: ArchiveInsightRef.theme(key),
                );
              },
              onOpenContradiction: (id) {
                ArchiveExplanationAnalytics.contradictionOpened();
                final ref = _contradictionRefFromId(id);
                if (ref != null) {
                  openArchiveExplanation(context, ref: ref);
                }
              },
              onOpenBlindSpot: (id) => openArchiveExplanation(
                context,
                ref: ArchiveInsightRef.blindSpot(id),
              ),
              onRecordToExplore: () => context.go('/record'),
            ),
    );
  }
}
