import 'package:archiveme_mobile/features/insights/evidence_connection_graph_mapper.dart';
import 'package:archiveme_mobile/features/insights/models/evidence_connection_graph.dart';
import 'package:archiveme_mobile/features/insights/pattern_exploration_conversation_state.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) {
  return JournalEntry(
    id: id,
    createdAt: createdAt ?? DateTime.utc(2026, 1, 12),
    transcript: transcript,
    durationSeconds: 10,
    reflection: const Reflection(
      mood: 'calm',
      emotionalIntensity: 3,
      recurringThemes: ['work'],
      exactLanguagePattern: '',
      concreteObservation: 'Work came up again.',
      repeatedSignal: '',
    ),
  );
}

void main() {
  const mapper = EvidenceConnectionGraphMapper();

  PatternExplorationMessage assistant({
    String content = 'These saved moments share a thread.',
    List<String> citedEntryIds = const [],
  }) {
    return PatternExplorationMessage(
      role: PatternExplorationMessage.roleAssistant,
      content: content,
      citedEntryIds: citedEntryIds,
    );
  }

  test(
    'maps a reply to a center message node and one evidence node per entry',
    () async {
      final entries = {
        'entry-a': _entry(
          id: 'entry-a',
          transcript: 'I stayed late again after the meeting.',
          createdAt: DateTime.utc(2026, 1, 10),
        ),
        'entry-b': _entry(
          id: 'entry-b',
          transcript: 'The same pressure showed up on Monday.',
          createdAt: DateTime.utc(2026, 2, 3),
        ),
      };

      final graph = await mapper.map(
        message: assistant(citedEntryIds: ['entry-a', 'entry-b']),
        getById: (id) async => entries[id],
      );

      expect(graph.nodes, hasLength(3));
      expect(graph.edges, hasLength(2));
      expect(graph.messageNodeId, EvidenceConnectionGraphMapper.messageNodeId);
      expect(graph.canvasSize.width, greaterThan(0));
      expect(graph.canvasSize.height, greaterThan(0));

      final messageNode = graph.nodeById(graph.messageNodeId)!;
      expect(messageNode.kind, EvidenceGraphNodeKind.message);
      expect(messageNode.label, contains('These saved moments'));
      expect(messageNode.isNavigable, isFalse);

      final evidence = graph.nodes
          .where((node) => node.kind == EvidenceGraphNodeKind.evidence)
          .toList();
      expect(evidence, hasLength(2));
      expect(evidence.map((node) => node.entryId), ['entry-a', 'entry-b']);
      expect(evidence[0].excerpt, 'I stayed late again after the meeting.');
      expect(evidence[0].dateLabel, 'Jan 10');
      expect(evidence[0].available, isTrue);
      expect(evidence[0].isNavigable, isTrue);
      expect(evidence[1].dateLabel, 'Feb 3');

      for (final edge in graph.edges) {
        expect(edge.fromId, graph.messageNodeId);
      }
    },
  );

  test(
    'missing or deleted entries become unavailable evidence nodes',
    () async {
      final graph = await mapper.map(
        message: assistant(citedEntryIds: ['gone', 'still-here']),
        getById: (id) async {
          if (id == 'still-here') {
            return _entry(
              id: 'still-here',
              transcript: 'This one is still in the list.',
            );
          }
          return null;
        },
      );

      final gone = graph.nodeById('evidence-gone')!;
      expect(gone.kind, EvidenceGraphNodeKind.evidence);
      expect(gone.label, EvidenceConnectionGraphMapper.unavailableLabel);
      expect(gone.excerpt, EvidenceConnectionGraphMapper.unavailableLabel);
      expect(gone.available, isFalse);
      expect(gone.isNavigable, isFalse);
      expect(gone.entryId, 'gone');

      final present = graph.nodeById('evidence-still-here')!;
      expect(present.available, isTrue);
      expect(present.excerpt, 'This one is still in the list.');
      expect(present.isNavigable, isTrue);
    },
  );

  test('lookup exceptions become unavailable evidence nodes', () async {
    final graph = await mapper.map(
      message: assistant(citedEntryIds: ['boom']),
      getById: (id) async => throw StateError('missing $id'),
    );

    final node = graph.nodeById('evidence-boom')!;
    expect(node.kind, EvidenceGraphNodeKind.evidence);
    expect(node.label, EvidenceConnectionGraphMapper.unavailableLabel);
    expect(node.available, isFalse);
    expect(node.isNavigable, isFalse);
  });

  test(
    'trims message content for the center label without hypothesis copy',
    () async {
      const long =
          'This reply is long enough that the graph label should clip it '
          'instead of repeating the full paragraph on the canvas.';
      final graph = await mapper.map(
        message: assistant(content: long),
        getById: (_) async => null,
      );

      final messageNode = graph.nodeById(graph.messageNodeId)!;
      expect(messageNode.label.length, lessThan(long.length));
      expect(messageNode.label, endsWith('…'));
      expect(messageNode.label.toLowerCase(), isNot(contains('hypothesis')));
      expect(messageNode.label.toLowerCase(), isNot(contains('theory')));
    },
  );
}
