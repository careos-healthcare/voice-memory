import 'package:archiveme_mobile/features/journal/domain/task_node.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/storage/sqlite/journal_sqlite_repository.dart';

/// Normalized journal-entry entity map (id → entry).
///
/// UI should select individual ids via [journalEntryByIdProvider] so a single
/// upsert does not rebuild unrelated timeline rows.
class JournalEntryMapState {
  const JournalEntryMapState({this.entries = const {}});

  const JournalEntryMapState.empty() : entries = const {};

  final Map<String, JournalEntry> entries;

  JournalEntry? operator [](String id) => entries[id];

  JournalEntryMapState putEntry(JournalEntry entry) {
    return putAll({entry.id: entry});
  }

  JournalEntryMapState putAll(Map<String, JournalEntry> updates) {
    if (updates.isEmpty) return this;
    return JournalEntryMapState(entries: {...entries, ...updates});
  }

  JournalEntryMapState removeEntry(String entryId) {
    if (!entries.containsKey(entryId)) return this;
    final next = Map<String, JournalEntry>.from(entries)..remove(entryId);
    return JournalEntryMapState(entries: next);
  }
}

/// Normalized task-node entity map (id → task).
class TaskNodeMapState {
  const TaskNodeMapState({this.nodes = const {}});

  const TaskNodeMapState.empty() : nodes = const {};

  final Map<String, TaskNode> nodes;

  TaskNode? operator [](String id) => nodes[id];

  TaskNodeMapState putNode(TaskNode node) {
    return putAll({node.id: node});
  }

  TaskNodeMapState putAll(Map<String, TaskNode> updates) {
    if (updates.isEmpty) return this;
    return TaskNodeMapState(nodes: {...nodes, ...updates});
  }

  TaskNodeMapState removeNode(String nodeId) {
    if (!nodes.containsKey(nodeId)) return this;
    final next = Map<String, TaskNode>.from(nodes)..remove(nodeId);
    return TaskNodeMapState(nodes: next);
  }
}

/// Ordered journal timeline ids plus cursor metadata for infinite scroll.
class JournalTimelinePaginationState {
  const JournalTimelinePaginationState({
    this.orderedEntryIds = const [],
    this.cursor,
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  const JournalTimelinePaginationState.initial()
      : orderedEntryIds = const [],
        cursor = null,
        hasMore = true,
        isLoadingMore = false;

  final List<String> orderedEntryIds;
  final JournalFeedCursor? cursor;
  final bool hasMore;
  final bool isLoadingMore;

  JournalTimelinePaginationState copyWith({
    List<String>? orderedEntryIds,
    JournalFeedCursor? cursor,
    bool? hasMore,
    bool? isLoadingMore,
    bool clearCursor = false,
  }) {
    return JournalTimelinePaginationState(
      orderedEntryIds: orderedEntryIds ?? this.orderedEntryIds,
      cursor: clearCursor ? null : cursor ?? this.cursor,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// Ordered task ids plus cursor metadata for infinite scroll.
class TaskTimelinePaginationState {
  const TaskTimelinePaginationState({
    this.orderedTaskIds = const [],
    this.cursor,
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  const TaskTimelinePaginationState.initial()
      : orderedTaskIds = const [],
        cursor = null,
        hasMore = true,
        isLoadingMore = false;

  final List<String> orderedTaskIds;
  final TaskNodeFeedCursor? cursor;
  final bool hasMore;
  final bool isLoadingMore;

  TaskTimelinePaginationState copyWith({
    List<String>? orderedTaskIds,
    TaskNodeFeedCursor? cursor,
    bool? hasMore,
    bool? isLoadingMore,
    bool clearCursor = false,
  }) {
    return TaskTimelinePaginationState(
      orderedTaskIds: orderedTaskIds ?? this.orderedTaskIds,
      cursor: clearCursor ? null : cursor ?? this.cursor,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}
