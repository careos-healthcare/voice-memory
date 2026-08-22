import 'package:archiveme_mobile/features/curiosity_loop/data/models/curiosity_reaction_record.dart';
import 'package:archiveme_mobile/features/curiosity_loop/data/repositories/curiosity_reaction_repository.dart';
import 'package:archiveme_mobile/features/curiosity_loop/models/curiosity_hook.dart';
import 'package:archiveme_mobile/features/curiosity_loop/repositories/curiosity_hook_repository.dart';
import 'package:archiveme_mobile/features/curiosity_loop/yesterdays_snapshot_reaction.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/journal_service.dart';

/// Portable export of curiosity loop journal moments and return-day reactions.
class CuriosityDataExporter {
  CuriosityDataExporter({
    required this._journalService,
    required this._reactionRepository,
    CuriosityHookRepository? hookRepository,
  }) : _hookRepository =
           hookRepository ?? LocalCuriosityHookRepository.instance();

  static const schemaVersion = 'curiosity_loop_export_v1';

  final JournalService _journalService;
  final CuriosityReactionRepository _reactionRepository;
  final CuriosityHookRepository _hookRepository;

  Future<String> exportAsMarkdown({
    required DateTime start,
    required DateTime end,
  }) async {
    final snapshot = await _loadSnapshot(start: start, end: end);
    final buffer = StringBuffer();

    buffer.writeln('# ArchiveMe — Curiosity Loop Export');
    buffer.writeln();
    buffer.writeln(
      '> **Window:** ${_formatDate(snapshot.windowStart)} → '
      '${_formatDate(snapshot.windowEnd)} (UTC)',
    );
    buffer.writeln();

    buffer.writeln('## Reaction summary');
    buffer.writeln();
    buffer.writeln('| Reaction | Count | Share |');
    buffer.writeln('| --- | ---: | ---: |');

    final summary = snapshot.summary;
    if (summary.totalReactions == 0) {
      buffer.writeln('| _No return-day reactions in this window_ | 0 | 0% |');
    } else {
      for (final reaction in YesterdaysSnapshotReaction.values) {
        final count = summary.reactionCounts[reaction] ?? 0;
        final share = summary.reactionBreakdown[reaction.name] ?? 0;
        buffer.writeln(
          '| ${reaction.emoji} ${_escapeMarkdown(reaction.label)} | '
          '$count | ${_formatPercent(share)} |',
        );
      }
    }

    buffer.writeln();
    buffer.writeln('**Total check-ins:** ${summary.totalReactions}');
    buffer.writeln();
    buffer.writeln('## Journal moments');
    buffer.writeln();

    if (snapshot.entries.isEmpty) {
      buffer.writeln('_No journal entries were saved during this window._');
      return buffer.toString().trimRight();
    }

    for (final row in snapshot.entryRows) {
      buffer.writeln(
        '### ${_formatDateTime(row.createdAt)} · ${_escapeMarkdown(row.emotionalTone)}',
      );
      buffer.writeln();
      buffer.writeln('- **Anchor:** ${_escapeMarkdown(row.primaryAnchor)}');
      buffer.writeln(
        '- **Emotional tone:** ${_escapeMarkdown(row.emotionalTone)}',
      );
      buffer.writeln('- **Return-day reaction:** ${row.reactionLabel}');
      buffer.writeln();
      buffer.writeln('> ${_escapeMarkdown(row.entryPreview)}');
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln();
    }

    return buffer.toString().trimRight();
  }

  Future<Map<String, dynamic>> exportAsJson({
    required DateTime start,
    required DateTime end,
  }) async {
    final snapshot = await _loadSnapshot(start: start, end: end);
    final summary = snapshot.summary;

    return {
      'schemaVersion': schemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'window': {
        'start': snapshot.windowStart.toIso8601String(),
        'end': snapshot.windowEnd.toIso8601String(),
      },
      'summary': {
        'totalReactions': summary.totalReactions,
        'totalEntries': snapshot.entries.length,
        'reactionBreakdown': summary.reactionBreakdown,
        'reactionCounts': {
          for (final reaction in YesterdaysSnapshotReaction.values)
            reaction.name: summary.reactionCounts[reaction] ?? 0,
        },
      },
      'entries': [
        for (final row in snapshot.entryRows)
          {
            'entryId': row.entryId,
            'createdAt': row.createdAt.toUtc().toIso8601String(),
            'primaryAnchor': _nullableString(row.primaryAnchor),
            'emotionalTone': _nullableString(row.emotionalTone),
            'entryPreview': _nullableString(row.entryPreview),
            'hookId': row.hookId,
            'hookType': row.hookType?.name,
            'reaction': row.reaction == null
                ? null
                : {
                    'id': row.reaction!.id,
                    'timestamp': row.reaction!.timestamp
                        .toUtc()
                        .toIso8601String(),
                    'type': row.reaction!.reactionType.name,
                    'emoji': row.reaction!.reactionType.emoji,
                    'label': row.reaction!.reactionType.label,
                  },
          },
      ],
      'reactions': snapshot.reactions.map((record) => record.toJson()).toList(),
      'hooks': snapshot.relevantHooks.map((hook) => hook.toJson()).toList(),
    };
  }

  Future<_CuriosityExportSnapshot> _loadSnapshot({
    required DateTime start,
    required DateTime end,
  }) async {
    final windowStart = start.toUtc();
    final windowEnd = end.toUtc();
    if (windowStart.isAfter(windowEnd)) {
      return _CuriosityExportSnapshot.empty(windowStart, windowEnd);
    }

    final reactions = await _reactionRepository.getReactionsInWindow(
      start: windowStart,
      end: windowEnd,
    );
    final hooks = await _hookRepository.loadAll();
    final hooksById = {
      for (final hook in hooks)
        if (hook.id.isNotEmpty) hook.id: hook,
    };

    final reactionByHookId = {
      for (final reaction in reactions)
        if (reaction.hookId.isNotEmpty) reaction.hookId: reaction,
    };

    final hookByEntryId = <String, CuriosityHook>{};
    for (final hook in hooks) {
      if (hook.entryId.isEmpty) continue;
      final existing = hookByEntryId[hook.entryId];
      if (existing == null || hook.createdAt.isAfter(existing.createdAt)) {
        hookByEntryId[hook.entryId] = hook;
      }
    }

    final allEntries = await _journalService.loadAll();
    final entries =
        allEntries
            .where(
              (entry) =>
                  !_isBefore(entry.createdAt, windowStart) &&
                  !_isAfter(entry.createdAt, windowEnd),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final entryRows = entries
        .map((entry) {
          final hook = hookByEntryId[entry.id];
          final reaction = hook == null ? null : reactionByHookId[hook.id];
          return _CuriosityExportEntryRow.fromParts(
            entry: entry,
            hook: hook,
            reaction: reaction,
          );
        })
        .toList(growable: false);

    final relevantHookIds = {
      for (final reaction in reactions) reaction.hookId,
      for (final row in entryRows)
        if (row.hookId != null) row.hookId!,
    };
    final relevantHooks = [
      for (final hookId in relevantHookIds)
        if (hooksById[hookId] != null) hooksById[hookId]!,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return _CuriosityExportSnapshot(
      windowStart: windowStart,
      windowEnd: windowEnd,
      entries: entries,
      reactions: reactions,
      relevantHooks: relevantHooks,
      entryRows: entryRows,
      summary: _CuriosityExportSummary.fromReactions(reactions),
    );
  }

  static String _formatDate(DateTime value) {
    final utc = value.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}-'
        '${utc.month.toString().padLeft(2, '0')}-'
        '${utc.day.toString().padLeft(2, '0')}';
  }

  static String _formatDateTime(DateTime value) {
    final utc = value.toUtc();
    return '${_formatDate(utc)} '
        '${utc.hour.toString().padLeft(2, '0')}:'
        '${utc.minute.toString().padLeft(2, '0')} UTC';
  }

  static String _formatPercent(double share) {
    return '${(share * 100).round()}%';
  }

  static String _escapeMarkdown(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '—';
    return raw
        .replaceAll(r'\', r'\\')
        .replaceAll('|', r'\|')
        .replaceAll('\r\n', ' ')
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ')
        .trim();
  }

  static String? _nullableString(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed == '—') return null;
    return trimmed;
  }

  static bool _isBefore(DateTime value, DateTime boundary) {
    return value.toUtc().isBefore(boundary);
  }

  static bool _isAfter(DateTime value, DateTime boundary) {
    return value.toUtc().isAfter(boundary);
  }
}

class _CuriosityExportSummary {
  const _CuriosityExportSummary({
    required this.totalReactions,
    required this.reactionCounts,
    required this.reactionBreakdown,
  });

  factory _CuriosityExportSummary.fromReactions(
    List<CuriosityReactionRecord> reactions,
  ) {
    if (reactions.isEmpty) {
      return const _CuriosityExportSummary(
        totalReactions: 0,
        reactionCounts: {},
        reactionBreakdown: {},
      );
    }

    final counts = <YesterdaysSnapshotReaction, int>{};
    for (final reaction in reactions) {
      counts.update(
        reaction.reactionType,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    final total = reactions.length;
    return _CuriosityExportSummary(
      totalReactions: total,
      reactionCounts: counts,
      reactionBreakdown: {
        for (final type in YesterdaysSnapshotReaction.values)
          type.name: (counts[type] ?? 0) / total,
      },
    );
  }

  final int totalReactions;
  final Map<YesterdaysSnapshotReaction, int> reactionCounts;
  final Map<String, double> reactionBreakdown;
}

class _CuriosityExportEntryRow {
  const _CuriosityExportEntryRow({
    required this.entryId,
    required this.createdAt,
    required this.primaryAnchor,
    required this.emotionalTone,
    required this.entryPreview,
    required this.reactionLabel,
    required this.hookId,
    required this.hookType,
    required this.reaction,
  });

  factory _CuriosityExportEntryRow.fromParts({
    required JournalEntry entry,
    required CuriosityHook? hook,
    required CuriosityReactionRecord? reaction,
  }) {
    final reflection = entry.reflection;
    final anchor = _firstNonEmpty([
      hook?.primaryAnchor,
      reaction?.primaryAnchor,
      reflection.repeatedSignal,
      reflection.exactLanguagePattern,
    ]);
    final preview = _firstNonEmpty([
      reflection.concreteObservation,
      entry.transcript,
    ]);
    final tone = _firstNonEmpty([reflection.mood]);

    return _CuriosityExportEntryRow(
      entryId: entry.id,
      createdAt: entry.createdAt,
      primaryAnchor: anchor ?? '—',
      emotionalTone: tone ?? '—',
      entryPreview: _truncate(preview ?? '—', 240),
      reactionLabel: reaction == null
          ? '—'
          : '${reaction.reactionType.emoji} ${reaction.reactionType.label}',
      hookId: hook?.id,
      hookType: hook?.hookType,
      reaction: reaction,
    );
  }

  final String entryId;
  final DateTime createdAt;
  final String primaryAnchor;
  final String emotionalTone;
  final String entryPreview;
  final String reactionLabel;
  final String? hookId;
  final CuriosityHookType? hookType;
  final CuriosityReactionRecord? reaction;

  static String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  static String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength - 1)}…';
  }
}

class _CuriosityExportSnapshot {
  const _CuriosityExportSnapshot({
    required this.windowStart,
    required this.windowEnd,
    required this.entries,
    required this.reactions,
    required this.relevantHooks,
    required this.entryRows,
    required this.summary,
  });

  factory _CuriosityExportSnapshot.empty(DateTime start, DateTime end) {
    return _CuriosityExportSnapshot(
      windowStart: start,
      windowEnd: end,
      entries: const [],
      reactions: const [],
      relevantHooks: const [],
      entryRows: const [],
      summary: const _CuriosityExportSummary(
        totalReactions: 0,
        reactionCounts: {},
        reactionBreakdown: {},
      ),
    );
  }

  final DateTime windowStart;
  final DateTime windowEnd;
  final List<JournalEntry> entries;
  final List<CuriosityReactionRecord> reactions;
  final List<CuriosityHook> relevantHooks;
  final List<_CuriosityExportEntryRow> entryRows;
  final _CuriosityExportSummary summary;
}