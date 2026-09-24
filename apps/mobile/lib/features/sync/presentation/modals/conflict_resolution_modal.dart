import 'package:archiveme_mobile/features/sync/application/conflict_line_diff.dart';
import 'package:archiveme_mobile/features/sync/application/conflict_resolution_store.dart';
import 'package:archiveme_mobile/features/sync/application/sync_presence.dart';
import 'package:archiveme_mobile/features/sync/presentation/widgets/provider_scope_probe.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/sync_status.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens the diff when [entry] is in conflict. Otherwise opens the entry.
Future<void> openEntryRespectingConflict({
  required BuildContext context,
  required JournalEntry entry,
  required VoidCallback onOpen,
}) async {
  if (entry.syncStatus != SyncStatus.conflict || !hasRiverpodScope(context)) {
    onOpen();
    return;
  }
  final container = ProviderScope.containerOf(context, listen: false);
  final notifier = container.read(syncStateProvider.notifier);
  final remote = notifier.remoteTranscript(entry.id) ?? entry.transcript;
  final decision = await ConflictResolutionModal.show(
    context,
    entryId: entry.id,
    localText: entry.transcript,
    remoteText: remote,
  );
  if (decision == null) return;
  await notifier.resolve(decision);
}

/// Side-by-side or stacked diff with keep-local, keep-remote, and a merge.
class ConflictResolutionModal extends StatefulWidget {
  const ConflictResolutionModal({
    required this.entryId,
    required this.localText,
    required this.remoteText,
    super.key,
  });

  final String entryId;
  final String localText;
  final String remoteText;

  static Future<ConflictDecision?> show(
    BuildContext context, {
    required String entryId,
    required String localText,
    required String remoteText,
  }) {
    return showDialog<ConflictDecision>(
      context: context,
      builder: (context) => ConflictResolutionModal(
        entryId: entryId,
        localText: localText,
        remoteText: remoteText,
      ),
    );
  }

  @override
  State<ConflictResolutionModal> createState() =>
      _ConflictResolutionModalState();
}

class _ConflictResolutionModalState extends State<ConflictResolutionModal> {
  late final List<DiffLine> _rows = buildLineDiff(
    widget.localText,
    widget.remoteText,
  );
  late final List<bool> _selected = [
    for (final row in _rows)
      if (row.selectable) true,
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      key: const Key('conflict_resolution_modal'),
      child: SizedBox(
        width: 520,
        height: 520,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Resolve conflict',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final panes = [
                    _VersionPane(title: 'Local', text: widget.localText),
                    _VersionPane(title: 'Remote', text: widget.remoteText),
                  ];
                  if (constraints.maxWidth >= 480) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final pane in panes) Expanded(child: pane),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: panes,
                  );
                },
              ),
              const SizedBox(height: 8),
              Expanded(child: _diffList()),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  TextButton(
                    key: const Key('conflict_use_local'),
                    onPressed: () => _close(
                      ConflictChoice.useLocal,
                      widget.localText,
                    ),
                    child: const Text('Use Local'),
                  ),
                  TextButton(
                    key: const Key('conflict_use_remote'),
                    onPressed: () => _close(
                      ConflictChoice.useRemote,
                      widget.remoteText,
                    ),
                    child: const Text('Use Remote'),
                  ),
                  FilledButton(
                    key: const Key('conflict_combine'),
                    onPressed: () => _close(
                      ConflictChoice.combineBoth,
                      combineSelectedLines(_rows, _selected),
                    ),
                    child: const Text('Combine Both'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _diffList() {
    var selectable = 0;
    final tiles = <Widget>[];
    for (final row in _rows) {
      if (!row.selectable) {
        tiles.add(
          _DiffRowTile(
            row: row,
            selected: true,
            onChanged: null,
            index: -1,
          ),
        );
        continue;
      }
      final index = selectable++;
      tiles.add(
        _DiffRowTile(
          row: row,
          selected: _selected[index],
          onChanged: (value) => setState(() => _selected[index] = value),
          index: index,
        ),
      );
    }
    return ListView(shrinkWrap: true, children: tiles);
  }

  void _close(ConflictChoice choice, String text) {
    Navigator.of(context).pop(
      ConflictDecision(
        entryId: widget.entryId,
        choice: choice,
        resolvedText: text,
      ),
    );
  }
}

class _VersionPane extends StatelessWidget {
  const _VersionPane({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(text, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _DiffRowTile extends StatelessWidget {
  const _DiffRowTile({
    required this.row,
    required this.selected,
    required this.onChanged,
    required this.index,
  });

  final DiffLine row;
  final bool selected;
  final ValueChanged<bool>? onChanged;
  final int index;

  @override
  Widget build(BuildContext context) {
    final (prefix, color) = switch (row.kind) {
      DiffLineKind.added => ('+', const Color(0xFF166534)),
      DiffLineKind.removed => ('-', AppColors.error),
      DiffLineKind.unchanged => (' ', AppColors.textMuted),
    };
    final background = switch (row.kind) {
      DiffLineKind.added => const Color(0xFFE8F5E9),
      DiffLineKind.removed => AppColors.destructiveLight,
      DiffLineKind.unchanged => Colors.transparent,
    };
    return ColoredBox(
      color: background,
      child: Row(
        children: [
          if (onChanged != null)
            Checkbox(
              key: Key('conflict_line_$index'),
              value: selected,
              onChanged: (value) => onChanged!(value ?? false),
            )
          else
            const SizedBox(width: 48),
          Text(prefix, style: TextStyle(color: color)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              row.text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
