import 'package:archiveme_mobile/features/archive_evidence/archive_belief_correction_store.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_belief_thread_engine.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_belief_thread_model.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_heuristics.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_threshold.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_intelligence_tier.dart';
import 'package:archiveme_mobile/features/archive_thought_map/archive_thought_map_copy.dart';
import 'package:archiveme_mobile/features/archive_thought_map/archive_thought_map_evidence_builder.dart';
import 'package:archiveme_mobile/features/archive_thought_map/archive_thought_map_models.dart';
import 'package:archiveme_mobile/features/first_session/first_session_pattern_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Builds a local thought map preview from existing archive engines only.
class ArchiveThoughtMapEngine {
  const ArchiveThoughtMapEngine({
    ArchiveBeliefThreadEngine? beliefEngine,
    ArchiveEvidenceHeuristics? heuristics,
    FirstSessionPatternEngine? patternEngine,
  }) : _beliefEngine = beliefEngine ?? const ArchiveBeliefThreadEngine(),
       _heuristics = heuristics ?? const ArchiveEvidenceHeuristics(),
       _patternEngine = patternEngine ?? const FirstSessionPatternEngine();

  final ArchiveBeliefThreadEngine _beliefEngine;
  final ArchiveEvidenceHeuristics _heuristics;
  final FirstSessionPatternEngine _patternEngine;

  ArchiveThoughtMapPreview build(
    List<JournalEntry> entries, {
    ArchiveIntelligenceTier tier = ArchiveIntelligenceTier.freeMedium,
  }) {
    final thread = _beliefEngine.build(entries, tier: tier);
    if (!thread.hasEnoughData ||
        ArchiveBeliefCorrectionStore.isDismissed(thread.suggestionId)) {
      return ArchiveThoughtMapPreview.hidden;
    }

    final analysis = _heuristics.analyze(entries, tier: tier);
    final nodes = _buildNodes(thread, analysis, entries);
    final attachedSnippets = nodes
        .expand((node) => node.snippets.map((s) => s.excerpt))
        .toList();
    final threshold = ArchiveEvidenceThreshold.evaluate(
      entries,
      suggestionId: thread.suggestionId,
      analysis: analysis,
      attachedSnippets: attachedSnippets,
    );
    if (!threshold.canNameThread) {
      return ArchiveThoughtMapPreview.hidden;
    }

    final evidenceNodes = nodes.where((n) => n.snippets.isNotEmpty).toList();
    if (evidenceNodes.length < 3) {
      return ArchiveThoughtMapPreview.hidden;
    }

    final savedCount = ArchiveEvidenceThreshold.meaningfulEntryCount(entries);
    final capped = evidenceNodes.take(5).toList();
    final generatedTitle = _threadTitle(thread);
    return ArchiveThoughtMapPreview(
      shouldShow: true,
      threadTitle: ArchiveBeliefCorrectionStore.displayThreadTitle(
        threadId: thread.suggestionId,
        generatedTitle: generatedTitle,
      ),
      nodes: capped,
      connectors: _connectorsFor(capped.length),
      savedMomentCount: savedCount,
      changeLine: _changeLine(thread.whatChanged, analysis),
      suggestionId: thread.suggestionId,
      stageLabel: threshold.stage.label,
    );
  }

  List<ArchiveThoughtMapNode> _buildNodes(
    ArchiveBeliefThread thread,
    ArchiveEvidenceAnalysis analysis,
    List<JournalEntry> entries,
  ) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    final latest = eligible.isNotEmpty ? eligible.last : entries.last;
    final latestPattern = _patternEngine.build(latest);
    final latestText = latest.transcript.toLowerCase();

    final nodes = <ArchiveThoughtMapNode>[];

    final trigger = _triggerValue(analysis, latestText, latestPattern.title);
    if (trigger != null) {
      nodes.add(
        ArchiveThoughtMapEvidenceBuilder.buildNode(
          suggestionId: thread.suggestionId,
          kind: ArchiveThoughtMapNodeKind.trigger,
          label: ArchiveThoughtMapCopy.triggerLabel,
          value: trigger,
          eligible: eligible,
          analysis: analysis,
          thread: thread,
        ),
      );
    }

    final thought = _thoughtValue(thread, analysis);
    if (thought != null) {
      nodes.add(
        ArchiveThoughtMapEvidenceBuilder.buildNode(
          suggestionId: thread.suggestionId,
          kind: ArchiveThoughtMapNodeKind.thought,
          label: ArchiveThoughtMapCopy.thoughtLabel,
          value: thought,
          eligible: eligible,
          analysis: analysis,
          thread: thread,
        ),
      );
    }

    final behaviour = _behaviourValue(analysis, latestText);
    if (behaviour != null) {
      nodes.add(
        ArchiveThoughtMapEvidenceBuilder.buildNode(
          suggestionId: thread.suggestionId,
          kind: ArchiveThoughtMapNodeKind.behaviour,
          label: ArchiveThoughtMapCopy.behaviourLabel,
          value: behaviour,
          eligible: eligible,
          analysis: analysis,
          thread: thread,
        ),
      );
    }

    final relief = _reliefValue(thread.whatChanged, analysis);
    if (relief != null) {
      nodes.add(
        ArchiveThoughtMapEvidenceBuilder.buildNode(
          suggestionId: thread.suggestionId,
          kind: ArchiveThoughtMapNodeKind.relief,
          label: ArchiveThoughtMapCopy.reliefLabel,
          value: relief,
          eligible: eligible,
          analysis: analysis,
          thread: thread,
        ),
      );
    }

    final cost = _costValue(analysis, thread);
    if (cost != null) {
      nodes.add(
        ArchiveThoughtMapEvidenceBuilder.buildNode(
          suggestionId: thread.suggestionId,
          kind: ArchiveThoughtMapNodeKind.cost,
          label: ArchiveThoughtMapCopy.costLabel,
          value: cost,
          eligible: eligible,
          analysis: analysis,
          thread: thread,
        ),
      );
    }

    final alternative = thread.whatToTest.trim();
    if (alternative.isNotEmpty) {
      nodes.add(
        ArchiveThoughtMapEvidenceBuilder.buildNode(
          suggestionId: thread.suggestionId,
          kind: ArchiveThoughtMapNodeKind.alternative,
          label: ArchiveThoughtMapCopy.alternativeLabel,
          value: alternative,
          eligible: eligible,
          analysis: analysis,
          thread: thread,
        ),
      );
    }

    return nodes;
  }

  String _threadTitle(ArchiveBeliefThread thread) {
    final belief = thread.currentBelief.trim();
    if (belief.isEmpty) return 'A thread from your saved moments';
    return belief.replaceAll(RegExp(r'^["“]|["”]$'), '').trim();
  }

  String? _triggerValue(
    ArchiveEvidenceAnalysis analysis,
    String latestText,
    String patternTitle,
  ) {
    if (analysis.windowEntries.isNotEmpty) {
      final contexts = analysis.windowEntries
          .map((e) => _contextFromText(e.transcript.toLowerCase()))
          .whereType<String>()
          .toSet()
          .toList();
      if (contexts.isNotEmpty) {
        return contexts.length == 1
            ? contexts.first
            : '${contexts.first}, then ${contexts.last}';
      }
    }
    if (patternTitle.trim().isNotEmpty && patternTitle.length <= 72) {
      return patternTitle.trim();
    }
    if (latestText.contains('work') || latestText.contains('deadline')) {
      return 'Work pressure building';
    }
    if (latestText.contains('yes') || latestText.contains('capacity')) {
      return 'A new ask before checking capacity';
    }
    return null;
  }

  String? _thoughtValue(
    ArchiveBeliefThread thread,
    ArchiveEvidenceAnalysis analysis,
  ) {
    final belief = thread.currentBelief.trim();
    if (belief.isNotEmpty) return _shorten(belief, 96);
    if (analysis.repeatedPressurePhrases.isNotEmpty) {
      return _shorten(
        'Pressure to ${analysis.repeatedPressurePhrases.first}',
        96,
      );
    }
    return null;
  }

  String? _behaviourValue(ArchiveEvidenceAnalysis analysis, String latestText) {
    if (analysis.repeatedPressurePhrases.any((p) => p.contains('say yes'))) {
      return 'Said yes before checking capacity';
    }
    if (latestText.contains('said yes') || latestText.contains('agreed')) {
      return 'Agreed before pausing';
    }
    if (analysis.repeatedPressurePhrases.isNotEmpty) {
      return _shorten(
        'Kept going to ${analysis.repeatedPressurePhrases.first}',
        96,
      );
    }
    if (analysis.possibleRepeat) {
      return 'Repeated the same response again';
    }
    return null;
  }

  String? _reliefValue(String whatChanged, ArchiveEvidenceAnalysis analysis) {
    final changed = whatChanged.toLowerCase();
    if (changed.contains('noticed it earlier') ||
        changed.contains('noticed') ||
        changed.contains('softer')) {
      return 'Noticed it sooner this time';
    }
    if (analysis.whatFadedLine?.trim().isNotEmpty == true) {
      return _shorten(analysis.whatFadedLine!.trim(), 96);
    }
    return null;
  }

  String? _costValue(
    ArchiveEvidenceAnalysis analysis,
    ArchiveBeliefThread thread,
  ) {
    if (analysis.repeatedPressurePhrases.any((p) => p.contains('rest'))) {
      return 'Rest felt harder to take';
    }
    if (thread.whatChanged.toLowerCase().contains('avoid')) {
      return 'Avoidance kept the pressure going';
    }
    if (analysis.repeatedPressurePhrases.isNotEmpty) {
      return _shorten(
        'May cost rest or capacity when ${analysis.repeatedPressurePhrases.first}',
        96,
      );
    }
    return null;
  }

  String? _changeLine(String whatChanged, ArchiveEvidenceAnalysis analysis) {
    final lower = whatChanged.toLowerCase();
    String? tag;
    if (lower.contains('noticed') ||
        lower.contains('earlier') ||
        lower.contains('softer')) {
      tag = 'softer';
    } else if (lower.contains('returned') ||
        lower.contains('again') ||
        lower.contains('repeat') ||
        analysis.possibleRepeat) {
      tag = 'repeated';
    } else if (lower.contains('shifted') ||
        lower.contains('different') ||
        lower.contains('around')) {
      tag = 'shifted';
    } else if (lower.contains('stronger') ||
        lower.contains('heavier') ||
        lower.contains('avoid')) {
      tag = 'stronger';
    }
    if (tag == null) return null;
    return '${ArchiveThoughtMapCopy.changePrefix}$tag';
  }

  List<ArchiveThoughtMapConnector> _connectorsFor(int nodeCount) {
    if (nodeCount <= 1) return const [];
    const cycle = [
      ArchiveThoughtMapConnector.because,
      ArchiveThoughtMapConnector.so,
      ArchiveThoughtMapConnector.but,
      ArchiveThoughtMapConnector.next,
    ];
    return List.generate(nodeCount - 1, (i) => cycle[i % cycle.length]);
  }

  String? _contextFromText(String text) {
    const contexts = {
      'work': 'Work pressure',
      'family': 'Family tension',
      'rest': 'Need for rest',
      'saying yes': 'Saying yes too quickly',
      'deadlines': 'Deadline pressure',
      'money': 'Money worry',
      'health': 'Health concern',
      'relationships': 'Relationship tension',
    };
    const keywords = {
      'work': ['work', 'office', 'deadline', 'boss', 'project', 'job'],
      'family': ['family', 'kids', 'child', 'partner', 'parent', 'home'],
      'rest': ['rest', 'tired', 'sleep', 'exhausted', 'burnout'],
      'saying yes': ['yes', 'agree', 'help', 'capacity', 'commit'],
      'deadlines': ['deadline', 'due', 'late', 'overdue'],
      'money': ['money', 'bills', 'rent', 'pay', 'afford'],
      'health': ['health', 'sick', 'doctor', 'pain'],
      'relationships': ['friend', 'relationship', 'people', 'partner'],
    };
    for (final entry in keywords.entries) {
      if (entry.value.any(text.contains)) {
        return contexts[entry.key];
      }
    }
    return null;
  }

  String _shorten(String value, int maxLen) {
    final trimmed = value.trim();
    if (trimmed.length <= maxLen) return trimmed;
    return '${trimmed.substring(0, maxLen - 1).trim()}…';
  }
}