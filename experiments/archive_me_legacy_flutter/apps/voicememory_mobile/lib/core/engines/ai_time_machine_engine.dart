import '../graph/graph_node.dart';
import '../graph/personal_knowledge_graph.dart';
import 'evidence_reference.dart';

typedef TimeMachineClock = DateTime Function();

enum HistoricalQueryIntent {
  relativeSnapshot,
  transition,
  entitySnapshot,
  boundedFallback,
}

class HistoricalQueryWindow {
  HistoricalQueryWindow({
    required this.intent,
    required this.originalQuery,
    required DateTime start,
    required DateTime end,
    this.subject,
  }) : start = start.toUtc(),
       end = end.toUtc();

  final HistoricalQueryIntent intent;
  final String originalQuery;
  final DateTime start;
  final DateTime end;
  final String? subject;
}

class HistoricalNodeSnapshot {
  HistoricalNodeSnapshot({
    required this.nodeId,
    required this.type,
    required this.label,
    required num confidence,
    required Iterable<EvidenceReference> evidence,
  }) : confidence = clampGraphScore(confidence),
       evidence = List.unmodifiable(evidence);

  final String nodeId;
  final NodeType type;
  final String label;
  final double confidence;
  final List<EvidenceReference> evidence;
}

class TimeMachineResult {
  TimeMachineResult({
    required this.parsedQuery,
    required Iterable<HistoricalNodeSnapshot> snapshots,
    required Iterable<EvidenceReference> evidence,
  }) : snapshots = List.unmodifiable(snapshots),
       evidence = List.unmodifiable(evidence);

  final HistoricalQueryWindow parsedQuery;
  final List<HistoricalNodeSnapshot> snapshots;
  final List<EvidenceReference> evidence;
}

class AITimeMachineEngine {
  AITimeMachineEngine(
    this.graph, {
    TimeMachineClock? clock,
    this.fallbackWindow = const Duration(days: 90),
  }) : clock = clock ?? graph.clock ?? DateTime.now;

  final PersonalKnowledgeGraph graph;
  final TimeMachineClock clock;
  final Duration fallbackWindow;

  /// Builds a bounded snapshot for an entity selected directly from the graph.
  TimeMachineResult queryEntity(
    GraphNode entity, {
    Duration padding = const Duration(days: 30),
  }) {
    if (padding.isNegative) {
      throw ArgumentError.value(padding, 'padding', 'Must not be negative');
    }
    final evidence = referencesForNode(graph, entity);
    final now = clock().toUtc();
    final start = evidence.isEmpty
        ? now.subtract(fallbackWindow)
        : evidence.first.observedAt.subtract(padding);
    final end = evidence.isEmpty ? now : evidence.last.observedAt.add(padding);
    final parsed = HistoricalQueryWindow(
      intent: HistoricalQueryIntent.entitySnapshot,
      originalQuery: 'Entity: ${entity.label}',
      start: start,
      end: end,
      subject: entity.label,
    );
    if (evidence.isEmpty) {
      return TimeMachineResult(
        parsedQuery: parsed,
        snapshots: const [],
        evidence: const [],
      );
    }
    return TimeMachineResult(
      parsedQuery: parsed,
      snapshots: [
        HistoricalNodeSnapshot(
          nodeId: entity.id,
          type: entity.type,
          label: entity.label,
          confidence: entity.confidence,
          evidence: evidence,
        ),
      ],
      evidence: evidence,
    );
  }

  TimeMachineResult query(String query) {
    final parsed = parse(query);
    final snapshots = <HistoricalNodeSnapshot>[];
    final allEvidence = <String, EvidenceReference>{};
    for (final node in graph.nodes) {
      final evidence = referencesForNode(graph, node)
          .where(
            (item) =>
                !item.observedAt.isBefore(parsed.start) &&
                !item.observedAt.isAfter(parsed.end) &&
                (parsed.subject == null ||
                    _matchesSubject(node, item, parsed.subject!)),
          )
          .toList();
      if (evidence.isEmpty) continue;
      for (final item in evidence) {
        allEvidence[item.entryId] = item;
      }
      snapshots.add(
        HistoricalNodeSnapshot(
          nodeId: node.id,
          type: node.type,
          label: node.label,
          confidence: node.confidence,
          evidence: evidence,
        ),
      );
    }
    snapshots.sort((a, b) => a.label.compareTo(b.label));
    final evidence = allEvidence.values.toList()
      ..sort((a, b) => a.observedAt.compareTo(b.observedAt));
    return TimeMachineResult(
      parsedQuery: parsed,
      snapshots: snapshots,
      evidence: evidence,
    );
  }

  HistoricalQueryWindow parse(String query) {
    final now = clock().toUtc();
    final normalized = normalizeGraphLabel(query);
    final relative = RegExp(
      r'\b(one|two|three|four|five|\d+)\s+(year|month|day)s?\s+ago\b',
    ).firstMatch(normalized);
    if (relative != null) {
      final amount = _number(relative.group(1)!);
      final unit = relative.group(2)!;
      final target = switch (unit) {
        'year' => _shiftMonths(now, -12 * amount),
        'month' => _shiftMonths(now, -amount),
        _ => now.subtract(Duration(days: amount)),
      };
      final radius = switch (unit) {
        'year' => const Duration(days: 183),
        'month' => const Duration(days: 15),
        _ => const Duration(hours: 12),
      };
      return HistoricalQueryWindow(
        intent: HistoricalQueryIntent.relativeSnapshot,
        originalQuery: query,
        start: target.subtract(radius),
        end: target.add(radius),
      );
    }

    final transition = RegExp(
      r'\bwhen did i become\s+(.+)$',
    ).firstMatch(normalized);
    if (transition != null) {
      final subject = transition.group(1)!.trim();
      final matching = <EvidenceReference>[];
      for (final node in graph.nodes) {
        matching.addAll(
          referencesForNode(
            graph,
            node,
          ).where((item) => _matchesSubject(node, item, subject)),
        );
      }
      matching.sort((a, b) => a.observedAt.compareTo(b.observedAt));
      final center = matching.isEmpty ? now : matching.first.observedAt;
      return HistoricalQueryWindow(
        intent: HistoricalQueryIntent.transition,
        originalQuery: query,
        start: center.subtract(const Duration(days: 30)),
        end: center.add(const Duration(days: 30)),
        subject: subject,
      );
    }

    return HistoricalQueryWindow(
      intent: HistoricalQueryIntent.boundedFallback,
      originalQuery: query,
      start: now.subtract(fallbackWindow),
      end: now,
    );
  }

  static bool _matchesSubject(
    GraphNode node,
    EvidenceReference item,
    String subject,
  ) {
    final term = normalizeGraphLabel(subject);
    final text =
        '${normalizeGraphLabel(node.label)} '
        '${normalizeGraphLabel(item.excerpt)}';
    return text.split(' ').contains(term) ||
        text.contains('$term ') ||
        text.endsWith(term);
  }

  static int _number(String value) =>
      int.tryParse(value) ??
      const {'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5}[value]!;

  static DateTime _shiftMonths(DateTime date, int months) {
    final monthIndex = date.year * 12 + date.month - 1 + months;
    final year = monthIndex ~/ 12;
    final month = monthIndex % 12 + 1;
    final lastDay = DateTime.utc(year, month + 1, 0).day;
    return DateTime.utc(
      year,
      month,
      date.day.clamp(1, lastDay),
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );
  }
}
