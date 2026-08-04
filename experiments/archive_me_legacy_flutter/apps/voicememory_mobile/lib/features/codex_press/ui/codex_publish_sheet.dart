import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../shared/ui/animations/canvas_feature_panel.dart';
import '../../semantic_clusters/semantic_cluster.dart';
import '../codex_encryption_manager.dart';
import '../codex_models.dart';
import '../codex_publication_service.dart';

Future<void> showCodexPublishSheet({
  required BuildContext context,
  required CodexPublicationService service,
  required List<SemanticCluster> clusters,
}) => showCanvasFeaturePanel<void>(
  context: context,
  routeName: '/codex-press',
  builder: (_) => CodexPublishSheet(service: service, clusters: clusters),
);

class CodexPublishSheet extends StatefulWidget {
  const CodexPublishSheet({
    required this.service,
    required this.clusters,
    super.key,
  });

  final CodexPublicationService service;
  final List<SemanticCluster> clusters;

  @override
  State<CodexPublishSheet> createState() => _CodexPublishSheetState();
}

class _CodexPublishSheetState extends State<CodexPublishSheet> {
  final _title = TextEditingController(text: 'My Sovereign Codex');
  final _password = TextEditingController();
  final _search = TextEditingController();
  final _sourceSearch = TextEditingController();
  CodexPublicationTemplate _template =
      CodexPublicationTemplate.minimalistJournal;
  CodexOrganization _organization = CodexOrganization.chronological;
  final Set<String> _selectedClusters = {};
  final Set<String> _selectedSources = {};
  late List<String> _clusterOrder;
  CodexManuscript? _manuscript;
  File? _lastExport;
  bool _includeRecovery = true;
  bool _busy = false;
  String _stage = '';
  double _progress = 0;
  String? _error;
  late Future<List<CodexExportRecord>> _historyFuture;
  late Future<List<CodexSourceOption>> _sourceOptionsFuture;

  @override
  void initState() {
    super.initState();
    _clusterOrder = widget.clusters.map((item) => item.id).toList();
    _selectedClusters.addAll(_clusterOrder);
    _historyFuture = widget.service.history.list();
    _sourceOptionsFuture = widget.service.sourceOptions().then((options) {
      _selectedSources.addAll(options.map((item) => item.id));
      if (mounted) setState(() {});
      return options;
    });
  }

  @override
  void dispose() {
    widget.service.cancel();
    _title.dispose();
    _password.dispose();
    _search.dispose();
    _sourceSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.auto_stories_rounded),
          title: const Text('The Sovereign Codex'),
          subtitle: const Text('Private, offline memoir press'),
          trailing: IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ),
        if (_busy) LinearProgressIndicator(value: _progress),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              TextField(
                key: const Key('codex_title'),
                controller: _title,
                maxLength: 160,
                decoration: const InputDecoration(
                  labelText: 'Book title',
                  prefixIcon: Icon(Icons.edit_note),
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<CodexOrganization>(
                segments: const [
                  ButtonSegment(
                    value: CodexOrganization.chronological,
                    label: Text('Chronological'),
                    icon: Icon(Icons.timeline),
                  ),
                  ButtonSegment(
                    value: CodexOrganization.thematic,
                    label: Text('Thematic'),
                    icon: Icon(Icons.hub_outlined),
                  ),
                ],
                selected: {_organization},
                onSelectionChanged: _busy
                    ? null
                    : (value) => setState(() {
                        _organization = value.single;
                        _manuscript = null;
                      }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CodexPublicationTemplate>(
                key: const Key('codex_template'),
                initialValue: _template,
                decoration: const InputDecoration(
                  labelText: 'Typography & layout',
                ),
                items: [
                  for (final value in CodexPublicationTemplate.values)
                    DropdownMenuItem(value: value, child: Text(value.label)),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() {
                        _template = value ?? _template;
                        _manuscript = null;
                      }),
              ),
              const SizedBox(height: 20),
              Text('Memory constellations', style: theme.textTheme.titleMedium),
              TextField(
                controller: _search,
                decoration: const InputDecoration(
                  hintText: 'Search local clusters',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 6),
              ..._visibleClusters.map(
                (cluster) => CheckboxListTile(
                  key: Key('codex_cluster_${cluster.id}'),
                  dense: true,
                  value: _selectedClusters.contains(cluster.id),
                  title: Text(cluster.title),
                  subtitle: Text(
                    cluster.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onChanged: _busy
                      ? null
                      : (selected) => setState(() {
                          if (selected == true) {
                            _selectedClusters.add(cluster.id);
                          } else {
                            _selectedClusters.remove(cluster.id);
                          }
                          _manuscript = null;
                        }),
                ),
              ),
              const SizedBox(height: 12),
              ExpansionTile(
                key: const Key('codex_source_selector'),
                title: const Text('Individual memories'),
                subtitle: const Text(
                  'Optionally include or exclude journal and voice sources',
                ),
                children: [
                  TextField(
                    controller: _sourceSearch,
                    decoration: const InputDecoration(
                      hintText: 'Search local memories',
                      prefixIcon: Icon(Icons.manage_search),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  FutureBuilder<List<CodexSourceOption>>(
                    future: _sourceOptionsFuture,
                    builder: (context, snapshot) {
                      final query = _sourceSearch.text.trim().toLowerCase();
                      final options = (snapshot.data ?? const [])
                          .where(
                            (item) =>
                                query.isEmpty ||
                                item.label.toLowerCase().contains(query),
                          )
                          .toList();
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const LinearProgressIndicator();
                      }
                      if (options.isEmpty) {
                        return const ListTile(
                          title: Text('No matching local memories'),
                        );
                      }
                      return Column(
                        children: [
                          for (final option in options.take(100))
                            CheckboxListTile(
                              key: Key('codex_source_${option.id}'),
                              dense: true,
                              value: _selectedSources.contains(option.id),
                              title: Text(option.label),
                              subtitle: Text(
                                '${option.kind.name} · '
                                '${option.occurredAt.toIso8601String().substring(0, 10)}',
                              ),
                              onChanged: _busy
                                  ? null
                                  : (selected) => setState(() {
                                      if (selected == true) {
                                        _selectedSources.add(option.id);
                                      } else {
                                        _selectedSources.remove(option.id);
                                      }
                                      _manuscript = null;
                                    }),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
              if (_organization == CodexOrganization.thematic) ...[
                const SizedBox(height: 16),
                Text('Chapter order', style: theme.textTheme.titleMedium),
                SizedBox(
                  height: (_clusterOrder.length * 54).clamp(54, 270).toDouble(),
                  child: ReorderableListView.builder(
                    buildDefaultDragHandles: true,
                    itemCount: _clusterOrder.length,
                    onReorderItem: _busy
                        ? (_, _) {}
                        : (oldIndex, newIndex) {
                            setState(() {
                              final id = _clusterOrder.removeAt(oldIndex);
                              _clusterOrder.insert(newIndex, id);
                              _manuscript = null;
                            });
                          },
                    itemBuilder: (context, index) {
                      final cluster = widget.clusters.firstWhere(
                        (item) => item.id == _clusterOrder[index],
                      );
                      return ListTile(
                        key: ValueKey(cluster.id),
                        dense: true,
                        leading: Text('${index + 1}'),
                        title: Text(cluster.title),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton.icon(
                key: const Key('codex_compile'),
                onPressed: _busy ? null : _compile,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Compile locally'),
              ),
              if (_busy) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: Text(_stage)),
                    TextButton(
                      key: const Key('codex_cancel'),
                      onPressed: widget.service.cancel,
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _error!,
                    key: const Key('codex_error'),
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              if (_manuscript case final manuscript?) ...[
                const SizedBox(height: 22),
                _Preview(manuscript: manuscript),
                const SizedBox(height: 22),
                Text('Encrypted archive', style: theme.textTheme.titleMedium),
                const Text(
                  '.codex is the secure portable format. A random export key '
                  'encrypts every package.',
                ),
                TextField(
                  key: const Key('codex_password'),
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password (optional with Sanctuary recovery)',
                  ),
                ),
                SwitchListTile(
                  key: const Key('codex_recovery_slot'),
                  value: _includeRecovery,
                  title: const Text('Allow Sanctuary recovery unlock'),
                  subtitle: const Text(
                    'Wraps the export key. The recovery phrase is never stored.',
                  ),
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _includeRecovery = value),
                ),
                FilledButton.tonalIcon(
                  key: const Key('codex_export_encrypted'),
                  onPressed: _busy ? null : _exportEncrypted,
                  icon: const Icon(Icons.lock),
                  label: const Text('Publish encrypted .codex'),
                ),
                const SizedBox(height: 18),
                Text('Open formats', style: theme.textTheme.titleMedium),
                const Text(
                  'PDF, EPUB, and HTML are plaintext. Export requires owner '
                  'authorization and creates a readable local file.',
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final format in const [
                      CodexExportFormat.pdf,
                      CodexExportFormat.epub,
                      CodexExportFormat.offlineHtml,
                    ])
                      OutlinedButton(
                        key: Key('codex_export_${format.name}'),
                        onPressed: _busy
                            ? null
                            : () => _exportPlaintext(format),
                        child: Text(format.name.toUpperCase()),
                      ),
                  ],
                ),
              ],
              if (_lastExport case final file?) ...[
                const SizedBox(height: 16),
                ListTile(
                  key: const Key('codex_export_ready'),
                  leading: const Icon(Icons.check_circle_outline),
                  title: const Text('Publication ready'),
                  subtitle: Text(file.uri.pathSegments.last),
                  trailing: IconButton(
                    tooltip: 'Share',
                    onPressed: () => Share.shareXFiles([XFile(file.path)]),
                    icon: const Icon(Icons.ios_share),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              FutureBuilder<List<CodexExportRecord>>(
                future: _historyFuture,
                builder: (context, snapshot) {
                  final records = snapshot.data ?? const [];
                  if (records.isEmpty) return const SizedBox();
                  return ExpansionTile(
                    title: const Text('Publication history'),
                    children: [
                      for (final record in records)
                        ListTile(
                          leading: Icon(
                            record.encrypted ? Icons.lock : Icons.description,
                          ),
                          title: Text(record.title),
                          subtitle: Text(
                            '${record.format.name} · ${record.size} bytes',
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<SemanticCluster> get _visibleClusters {
    final query = _search.text.trim().toLowerCase();
    return widget.clusters
        .where(
          (cluster) =>
              query.isEmpty ||
              cluster.title.toLowerCase().contains(query) ||
              cluster.summary.toLowerCase().contains(query),
        )
        .toList();
  }

  Future<void> _compile() async {
    setState(() {
      _busy = true;
      _error = null;
      _progress = 0;
    });
    try {
      final value = await widget.service.compile(
        CodexCompilationRequest(
          title: _title.text,
          template: _template,
          organization: _organization,
          selectedClusterIds: _selectedClusters.toList(),
          selectedSourceIds: _selectedSources.toList(),
          chapterOrder: _clusterOrder,
        ),
        onProgress: _onProgress,
      );
      if (mounted) setState(() => _manuscript = value);
    } on Object catch (error) {
      if (mounted) setState(() => _error = _friendly(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportEncrypted() async {
    final manuscript = _manuscript;
    if (manuscript == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = await widget.service.exportEncrypted(
        manuscript: manuscript,
        password: _password.text.trim().isEmpty ? null : _password.text,
        includeRecoverySlot: _includeRecovery,
        onProgress: _onProgress,
      );
      if (mounted) {
        setState(() {
          _lastExport = file;
          _historyFuture = widget.service.history.list();
        });
      }
    } on Object catch (error) {
      if (mounted) setState(() => _error = _friendly(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportPlaintext(CodexExportFormat format) async {
    final manuscript = _manuscript;
    if (manuscript == null) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('codex_plaintext_warning'),
        title: const Text('Export readable plaintext?'),
        content: const Text(
          'This file is not encrypted. Anyone with access to it can read your '
          'memoir. Keep it only in a location you trust.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('codex_accept_plaintext'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('I understand — authorize'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = await widget.service.exportPlaintext(
        manuscript: manuscript,
        format: format,
        warningAccepted: true,
      );
      if (mounted) {
        setState(() {
          _lastExport = file;
          _historyFuture = widget.service.history.list();
        });
      }
    } on Object catch (error) {
      if (mounted) setState(() => _error = _friendly(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onProgress(String stage, double progress) {
    if (!mounted) return;
    setState(() {
      _stage = stage;
      _progress = progress;
    });
  }

  static String _friendly(Object error) {
    if (error is CodexCancelledException) return 'Compilation cancelled.';
    if (error is CodexAuthenticationException) {
      return 'Authorization failed. No publication was exported.';
    }
    if (error is FormatException) return error.message.toString();
    return 'The Codex could not be completed on this device.';
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.manuscript});
  final CodexManuscript manuscript;

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('codex_preview'),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            manuscript.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(
            '${manuscript.chapters.length} chapters · '
            '${manuscript.template.label}',
          ),
          const Divider(),
          for (final chapter in manuscript.chapters)
            ExpansionTile(
              title: Text('${chapter.ordinal + 1}. ${chapter.title}'),
              subtitle: Text(
                '${chapter.passages.length} source-bound sections',
              ),
              children: [
                for (final passage in chapter.passages.take(3))
                  ListTile(
                    title: Text(passage.heading),
                    subtitle: Text(
                      passage.text,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
        ],
      ),
    ),
  );
}
