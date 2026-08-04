import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../shared/ui/animations/canvas_feature_panel.dart';
import '../../../shared/ui/glassmorphic_container.dart';
import '../../autonomous_muse/legacy_sweep_orchestrator.dart';
import '../../autonomous_muse/ui/muse_digest_sheet.dart';
import '../graph_ingestion_pipeline.dart';

typedef VaultDirectoryPicker = Future<String?> Function();
typedef ImportOwnerAuthorizer = Future<bool> Function();

final class ImportStudioSheet extends StatefulWidget {
  const ImportStudioSheet({
    super.key,
    required this.pipeline,
    this.legacySweepController,
    this.directoryPicker,
    this.authorizeImport,
  });

  final GraphIngestionController pipeline;
  final LegacySweepController? legacySweepController;
  final VaultDirectoryPicker? directoryPicker;
  final ImportOwnerAuthorizer? authorizeImport;

  static Future<void> show({
    required BuildContext context,
    required GraphIngestionController pipeline,
    LegacySweepController? legacySweepController,
    ImportOwnerAuthorizer? authorizeImport,
  }) => showCanvasFeaturePanel<void>(
    context: context,
    routeName: '/legacy-import-studio',
    builder: (_) => ImportStudioSheet(
      pipeline: pipeline,
      legacySweepController: legacySweepController,
      authorizeImport: authorizeImport,
    ),
  );

  @override
  State<ImportStudioSheet> createState() => _ImportStudioSheetState();
}

class _ImportStudioSheetState extends State<ImportStudioSheet> {
  StreamSubscription<GraphIngestionProgress>? _subscription;
  GraphIngestionProgress? _progress;
  GraphIngestionResult? _result;
  String? _directoryPath;
  String? _error;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _subscription = widget.pipeline.progress.listen((progress) {
      if (mounted) setState(() => _progress = progress);
    });
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  Future<void> _pickDirectory() async {
    final selected =
        await widget.directoryPicker?.call() ??
        await FilePicker.platform.getDirectoryPath(
          dialogTitle: 'Select Obsidian or Notion Markdown vault',
          lockParentWindow: true,
        );
    if (!mounted || selected == null) return;
    setState(() {
      _directoryPath = selected;
      _error = null;
      _result = null;
    });
  }

  Future<void> _startImport() async {
    final selected = _directoryPath;
    if (_running || selected == null) return;
    if (widget.authorizeImport != null &&
        !await widget.authorizeImport!.call()) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _running = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await widget.pipeline.ingestDirectory(Directory(selected));
      if (mounted) setState(() => _result = result);
    } on GraphIngestionCancelled {
      if (mounted) setState(() => _error = 'Import cancelled safely.');
    } on Object catch (error) {
      if (mounted) setState(() => _error = 'Import failed: $error');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.account_tree_outlined),
            title: const Text('Legacy Data Import Studio'),
            subtitle: const Text('Offline Obsidian and Notion Markdown bridge'),
            trailing: IconButton(
              key: const Key('legacy-import-close'),
              onPressed: _running ? null : () => Navigator.maybePop(context),
              icon: const Icon(Icons.close),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                GlassmorphicContainer(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Vault folder', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        _directoryPath ?? 'No local folder selected',
                        key: const Key('legacy-import-selected-folder'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        key: const Key('legacy-import-pick-folder'),
                        onPressed: _running ? null : _pickDirectory,
                        icon: const Icon(Icons.folder_open_outlined),
                        label: const Text('Choose vault folder'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GlassmorphicContainer(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _phaseLabel(progress?.phase),
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          Text('${((progress?.fraction ?? 0) * 100).round()}%'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        key: const Key('legacy-import-progress'),
                        value: progress?.fraction ?? 0,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _Metric(
                            key: const Key('legacy-import-rate'),
                            label: 'Parsing speed',
                            value:
                                '${(progress?.notesPerSecond ?? 0).toStringAsFixed(1)} notes/s',
                          ),
                          _Metric(
                            key: const Key('legacy-import-embedding'),
                            label: 'Embeddings',
                            value:
                                '${progress?.embeddedChunks ?? 0}/${progress?.totalChunks ?? 0}',
                          ),
                          _Metric(
                            key: const Key('legacy-import-eta'),
                            label: 'Embedding ETA',
                            value: _duration(progress?.eta),
                          ),
                          _Metric(
                            key: const Key('legacy-import-sqlite'),
                            label: 'SQLite writes',
                            value:
                                '${progress?.insertedNotes ?? 0} notes · '
                                '${progress?.sqliteWriteTime.inMilliseconds ?? 0} ms',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_result case final result?) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Imported ${result.insertedNotes} notes and '
                    '${result.insertedEdges} links; '
                    '${result.skippedNotes} duplicates skipped.',
                    key: const Key('legacy-import-result'),
                  ),
                ],
                if (widget.legacySweepController != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const Key('legacy-import-open-muse-digest'),
                    onPressed: _running
                        ? null
                        : () => MuseDigestSheet.show(
                            context: context,
                            controller: widget.legacySweepController!,
                          ),
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: const Text('Open Muse Digest'),
                  ),
                ],
                if (_error case final error?) ...[
                  const SizedBox(height: 12),
                  Text(
                    error,
                    key: const Key('legacy-import-error'),
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                const SizedBox(height: 20),
                if (_running)
                  OutlinedButton.icon(
                    key: const Key('legacy-import-cancel'),
                    onPressed: widget.pipeline.cancel,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('Cancel after current batch'),
                  )
                else
                  FilledButton.icon(
                    key: const Key('legacy-import-start'),
                    onPressed: _directoryPath == null ? null : _startImport,
                    icon: const Icon(Icons.move_to_inbox_outlined),
                    label: const Text('Import into memory graph'),
                  ),
                const SizedBox(height: 8),
                const Text(
                  'All parsing and embedding stays on this device. Sensitive '
                  'note fields and authoritative vectors are encrypted before '
                  'they are written to SQLite.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _phaseLabel(GraphIngestionPhase? phase) => switch (phase) {
    GraphIngestionPhase.parsing => 'Parsing vault',
    GraphIngestionPhase.chunking => 'Chunking notes',
    GraphIngestionPhase.embedding => 'Generating local embeddings',
    GraphIngestionPhase.inserting => 'Writing encrypted SQLite batches',
    GraphIngestionPhase.graphCommit => 'Committing graph topology',
    GraphIngestionPhase.completed => 'Import complete',
    GraphIngestionPhase.cancelled => 'Import cancelled',
    null => 'Ready to import',
  };

  static String _duration(Duration? value) {
    if (value == null) return '—';
    final seconds = value.inSeconds;
    return seconds >= 60 ? '${seconds ~/ 60}m ${seconds % 60}s' : '${seconds}s';
  }
}

final class _Metric extends StatelessWidget {
  const _Metric({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 150,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 2),
        Text(value, style: Theme.of(context).textTheme.bodyLarge),
      ],
    ),
  );
}
