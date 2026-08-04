import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../document_models.dart';

enum DocumentVaultActivity { ready, importing, indexing, analyzing, failed }

enum DocumentMarkerKind { citation, concept, category }

enum DocumentImportKind { file, droppedFile, httpsUrl }

typedef DocumentBytesImporter =
    Future<DocumentVaultEntry> Function(
      DocumentImportRequest request,
      void Function(double progress, String? detail) reportProgress,
    );
typedef DocumentUrlImporter =
    Future<DocumentVaultEntry> Function(
      Uri uri,
      void Function(double progress, String? detail) reportProgress,
    );
typedef DocumentReindexCallback =
    Future<DocumentVaultEntry> Function(
      DocumentVaultEntry document,
      void Function(double progress, String? detail) reportProgress,
    );
typedef DocumentDeleteCallback =
    Future<void> Function(DocumentVaultEntry document);
typedef DocumentAnalyzeCallback =
    Future<DocumentVaultEntry> Function(
      DocumentVaultEntry document,
      List<DocumentChunk> selected,
      void Function(double progress, String? detail) reportProgress,
    );
typedef DocumentFilePicker = Future<PlatformFile?> Function();

final class DocumentImportRequest {
  const DocumentImportRequest({
    required this.kind,
    required this.fileName,
    required this.bytes,
  });

  final DocumentImportKind kind;
  final String fileName;
  final Uint8List bytes;
}

final class DocumentReaderMarker {
  const DocumentReaderMarker({
    required this.id,
    required this.kind,
    required this.label,
    this.blockIndex,
    this.chunkIndex,
    this.nodeId,
    this.clusterId,
  });

  final String id;
  final DocumentMarkerKind kind;
  final String label;
  final int? blockIndex;
  final int? chunkIndex;
  final String? nodeId;
  final String? clusterId;
}

final class DocumentVaultEntry {
  DocumentVaultEntry({
    required this.metadata,
    required this.parsed,
    required Iterable<DocumentChunk> chunks,
    this.activity = DocumentVaultActivity.ready,
    this.progress = 1,
    this.progressDetail,
    this.failure,
    this.cloudAnalyzed = false,
    Iterable<DocumentReaderMarker> markers = const [],
  }) : chunks = List.unmodifiable(chunks),
       markers = List.unmodifiable(markers);

  final StoredDocumentMetadata metadata;
  final ParsedDocument parsed;
  final List<DocumentChunk> chunks;
  final DocumentVaultActivity activity;
  final double progress;
  final String? progressDetail;
  final String? failure;
  final bool cloudAnalyzed;
  final List<DocumentReaderMarker> markers;

  DocumentVaultEntry copyWith({
    DocumentVaultActivity? activity,
    double? progress,
    String? progressDetail,
    String? failure,
    bool? cloudAnalyzed,
    Iterable<DocumentReaderMarker>? markers,
  }) => DocumentVaultEntry(
    metadata: metadata,
    parsed: parsed,
    chunks: chunks,
    activity: activity ?? this.activity,
    progress: progress ?? this.progress,
    progressDetail: progressDetail ?? this.progressDetail,
    failure: failure,
    cloudAnalyzed: cloudAnalyzed ?? this.cloudAnalyzed,
    markers: markers ?? this.markers,
  );
}

/// Testable state and action boundary for the document vault UI.
///
/// Storage, parsing, indexing, and network work stay behind injected callbacks.
/// This class intentionally has no dependency on AppServices.
final class DocumentVaultController extends ChangeNotifier {
  DocumentVaultController({
    Iterable<DocumentVaultEntry> documents = const [],
    this.onImportBytes,
    this.onImportUrl,
    this.onReindex,
    this.onDelete,
    this.onAnalyzeSelected,
  }) : _documents = List.of(documents);

  final DocumentBytesImporter? onImportBytes;
  final DocumentUrlImporter? onImportUrl;
  final DocumentReindexCallback? onReindex;
  final DocumentDeleteCallback? onDelete;
  final DocumentAnalyzeCallback? onAnalyzeSelected;

  List<DocumentVaultEntry> _documents;
  String? _selectedDocumentId;
  final Set<int> _selectedChunks = {};
  DocumentVaultActivity _importActivity = DocumentVaultActivity.ready;
  double _importProgress = 0;
  String? _importDetail;
  String? _importFailure;

  List<DocumentVaultEntry> get documents => List.unmodifiable(_documents);
  String? get selectedDocumentId =>
      _selectedDocumentId ??
      (_documents.isEmpty ? null : _documents.first.metadata.id);
  Set<int> get selectedChunks => Set.unmodifiable(_selectedChunks);
  DocumentVaultActivity get importActivity => _importActivity;
  double get importProgress => _importProgress;
  String? get importDetail => _importDetail;
  String? get importFailure => _importFailure;

  DocumentVaultEntry? get selectedDocument {
    final id = selectedDocumentId;
    if (id == null) return null;
    for (final document in _documents) {
      if (document.metadata.id == id) return document;
    }
    return null;
  }

  void replaceDocuments(Iterable<DocumentVaultEntry> documents) {
    _documents = List.of(documents);
    if (!_documents.any(
      (document) => document.metadata.id == _selectedDocumentId,
    )) {
      _selectedDocumentId = null;
      _selectedChunks.clear();
    }
    notifyListeners();
  }

  void selectDocument(String id) {
    if (id == selectedDocumentId) return;
    _selectedDocumentId = id;
    _selectedChunks.clear();
    notifyListeners();
  }

  void toggleChunk(int index) {
    if (!_selectedChunks.add(index)) _selectedChunks.remove(index);
    notifyListeners();
  }

  void clearSelection() {
    _selectedChunks.clear();
    notifyListeners();
  }

  void reportImportProgress(double progress, [String? detail]) {
    _importActivity = DocumentVaultActivity.importing;
    _importProgress = progress.clamp(0, 1);
    _importDetail = detail;
    _importFailure = null;
    notifyListeners();
  }

  void reportImportFailure(String message) {
    _importActivity = DocumentVaultActivity.failed;
    _importFailure = message;
    notifyListeners();
  }

  Future<void> importBytes(DocumentImportRequest request) async {
    final callback = onImportBytes;
    if (callback == null) return;
    reportImportProgress(0, 'Reading locally');
    try {
      final imported = await callback(request, reportImportProgress);
      _upsert(imported);
      _selectedDocumentId = imported.metadata.id;
      _importActivity = DocumentVaultActivity.ready;
      _importProgress = 1;
      _importDetail = 'Stored locally';
      notifyListeners();
    } on Object catch (error) {
      reportImportFailure(_message(error));
    }
  }

  Future<void> importUrl(Uri uri) async {
    final callback = onImportUrl;
    if (callback == null) return;
    if (uri.scheme != 'https' || uri.host.isEmpty) {
      reportImportFailure('Enter a valid HTTPS URL.');
      return;
    }
    reportImportProgress(0, 'Fetching approved URL');
    try {
      final imported = await callback(uri, reportImportProgress);
      _upsert(imported);
      _selectedDocumentId = imported.metadata.id;
      _importActivity = DocumentVaultActivity.ready;
      _importProgress = 1;
      _importDetail = 'Fetched and stored locally';
      notifyListeners();
    } on Object catch (error) {
      reportImportFailure(_message(error));
    }
  }

  Future<void> reindex(DocumentVaultEntry document) async {
    final callback = onReindex;
    if (callback == null) return;
    _setDocumentActivity(document, DocumentVaultActivity.indexing, 0);
    try {
      final updated = await callback(document, (progress, detail) {
        _setDocumentActivity(
          document,
          DocumentVaultActivity.indexing,
          progress,
          detail: detail,
        );
      });
      _upsert(updated);
      notifyListeners();
    } on Object catch (error) {
      _setDocumentActivity(
        document,
        DocumentVaultActivity.failed,
        0,
        failure: _message(error),
      );
    }
  }

  Future<void> delete(DocumentVaultEntry document) async {
    final callback = onDelete;
    if (callback == null) return;
    try {
      await callback(document);
      _documents.removeWhere(
        (item) => item.metadata.id == document.metadata.id,
      );
      _selectedDocumentId = null;
      _selectedChunks.clear();
      notifyListeners();
    } on Object catch (error) {
      _setDocumentActivity(
        document,
        DocumentVaultActivity.failed,
        0,
        failure: _message(error),
      );
    }
  }

  Future<void> analyzeSelected() async {
    final document = selectedDocument;
    final callback = onAnalyzeSelected;
    if (document == null || callback == null || _selectedChunks.isEmpty) return;
    final selected = [
      for (final chunk in document.chunks)
        if (_selectedChunks.contains(chunk.index)) chunk,
    ];
    _setDocumentActivity(document, DocumentVaultActivity.analyzing, 0);
    try {
      final updated = await callback(document, selected, (progress, detail) {
        _setDocumentActivity(
          document,
          DocumentVaultActivity.analyzing,
          progress,
          detail: detail,
        );
      });
      _upsert(updated);
      _selectedChunks.clear();
      notifyListeners();
    } on Object catch (error) {
      _setDocumentActivity(
        document,
        DocumentVaultActivity.failed,
        0,
        failure: _message(error),
      );
    }
  }

  void _setDocumentActivity(
    DocumentVaultEntry target,
    DocumentVaultActivity activity,
    double progress, {
    String? detail,
    String? failure,
  }) {
    final index = _documents.indexWhere(
      (item) => item.metadata.id == target.metadata.id,
    );
    if (index < 0) return;
    _documents[index] = _documents[index].copyWith(
      activity: activity,
      progress: progress.clamp(0, 1),
      progressDetail: detail,
      failure: failure,
    );
    notifyListeners();
  }

  void _upsert(DocumentVaultEntry document) {
    final index = _documents.indexWhere(
      (item) => item.metadata.id == document.metadata.id,
    );
    if (index < 0) {
      _documents.insert(0, document);
    } else {
      _documents[index] = document;
    }
  }

  static String _message(Object error) =>
      error.toString().replaceFirst(RegExp(r'^(Exception|StateError): '), '');
}

class DocumentVaultSheet extends StatefulWidget {
  const DocumentVaultSheet({
    super.key,
    required this.controller,
    required this.onClose,
    this.onBackgroundRequested,
    this.onFocusNode,
    this.onFocusCluster,
    this.filePicker,
  });

  final DocumentVaultController controller;
  final VoidCallback onClose;
  final VoidCallback? onBackgroundRequested;
  final ValueChanged<String>? onFocusNode;
  final ValueChanged<String>? onFocusCluster;
  final DocumentFilePicker? filePicker;

  @override
  State<DocumentVaultSheet> createState() => _DocumentVaultSheetState();
}

class _DocumentVaultSheetState extends State<DocumentVaultSheet> {
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant DocumentVaultSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.controller;
    return ClipRRect(
      key: const Key('document-vault-sheet'),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Material(
          color: theme.colorScheme.surface.withValues(alpha: .9),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 10, 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.library_books_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Document vault',
                              style: theme.textTheme.headlineSmall,
                            ),
                            const Text('Private by default · excerpts opt in'),
                          ],
                        ),
                      ),
                      IconButton(
                        key: const Key('document-vault-close'),
                        tooltip: 'Close document vault',
                        onPressed: widget.onClose,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DropTarget(
                    onDragEntered: (_) => setState(() => _dragging = true),
                    onDragExited: (_) => setState(() => _dragging = false),
                    onDragDone: (details) async {
                      setState(() => _dragging = false);
                      for (final file in details.files) {
                        await controller.importBytes(
                          DocumentImportRequest(
                            kind: DocumentImportKind.droppedFile,
                            fileName: file.name,
                            bytes: await file.readAsBytes(),
                          ),
                        );
                      }
                    },
                    child: AnimatedContainer(
                      key: const Key('document-drop-target'),
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(
                          alpha: _dragging ? .55 : .2,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(
                            alpha: _dragging ? .8 : .25,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _dragging
                                  ? 'Drop files to import locally'
                                  : 'Import a file or drop one here',
                            ),
                          ),
                          TextButton.icon(
                            key: const Key('document-import-file'),
                            onPressed: controller.onImportBytes == null
                                ? null
                                : _pickFile,
                            icon: const Icon(Icons.upload_file_outlined),
                            label: const Text('File'),
                          ),
                          TextButton.icon(
                            key: const Key('document-import-url'),
                            onPressed: controller.onImportUrl == null
                                ? null
                                : _requestUrl,
                            icon: const Icon(Icons.link),
                            label: const Text('URL'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (controller.importActivity != DocumentVaultActivity.ready)
                  _ImportStatus(controller: controller),
                const SizedBox(height: 8),
                Expanded(
                  child: controller.documents.isEmpty
                      ? const Center(
                          child: Text(
                            'No documents yet.\nFiles remain encrypted locally.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: 148,
                              child: ListView(
                                key: const Key('document-vault-list'),
                                padding: const EdgeInsets.only(left: 12),
                                children: [
                                  for (final document in controller.documents)
                                    _DocumentTile(
                                      document: document,
                                      selected:
                                          document.metadata.id ==
                                          controller.selectedDocumentId,
                                      onTap: () => controller.selectDocument(
                                        document.metadata.id,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const VerticalDivider(width: 1),
                            Expanded(
                              child: _DocumentReader(
                                document: controller.selectedDocument!,
                                selectedChunks: controller.selectedChunks,
                                onToggleChunk: controller.toggleChunk,
                                onReindex: controller.onReindex == null
                                    ? null
                                    : () => controller.reindex(
                                        controller.selectedDocument!,
                                      ),
                                onDelete: controller.onDelete == null
                                    ? null
                                    : () => _confirmDelete(
                                        controller.selectedDocument!,
                                      ),
                                onAnalyze:
                                    controller.onAnalyzeSelected == null ||
                                        controller.selectedChunks.isEmpty
                                    ? null
                                    : _confirmAnalyze,
                                onMarker: _focusMarker,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    final picked =
        await widget.filePicker?.call() ??
        (await FilePicker.platform.pickFiles(
          allowMultiple: false,
          withData: true,
          type: FileType.custom,
          allowedExtensions: const [
            'pdf',
            'epub',
            'md',
            'markdown',
            'html',
            'txt',
          ],
        ))?.files.single;
    if (picked == null) return;
    final bytes =
        picked.bytes ??
        (picked.path == null ? null : await File(picked.path!).readAsBytes());
    if (bytes == null) {
      widget.controller.reportImportFailure(
        'The selected file could not be read.',
      );
      return;
    }
    await widget.controller.importBytes(
      DocumentImportRequest(
        kind: DocumentImportKind.file,
        fileName: picked.name,
        bytes: bytes,
      ),
    );
  }

  Future<void> _requestUrl() async {
    final input = TextEditingController();
    try {
      final value = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Import from HTTPS URL'),
          content: TextField(
            key: const Key('document-url-input'),
            controller: input,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              hintText: 'https://example.com/article',
              helperText: 'Nothing is fetched until you confirm.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('document-url-review'),
              onPressed: () => Navigator.pop(dialogContext, input.text.trim()),
              child: const Text('Review fetch'),
            ),
          ],
        ),
      );
      if (!mounted || value == null) return;
      final uri = Uri.tryParse(value);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        widget.controller.reportImportFailure('Enter a valid HTTPS URL.');
        return;
      }
      final approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          key: const Key('document-url-confirmation'),
          title: const Text('Fetch this page?'),
          content: Text(
            '$uri\n\nThe page will be fetched once, sanitized, and stored '
            'encrypted on this device.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('document-url-fetch-confirm'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Fetch and store locally'),
            ),
          ],
        ),
      );
      if (approved == true) await widget.controller.importUrl(uri);
    } finally {
      input.dispose();
    }
  }

  Future<void> _confirmAnalyze() async {
    final count = widget.controller.selectedChunks.length;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('document-cloud-approval'),
        title: const Text('Analyze selected excerpts?'),
        content: Text(
          '$count selected ${count == 1 ? 'excerpt' : 'excerpts'} will be sent '
          'for cloud analysis. The original document stays local.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('document-cloud-approve'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Analyze selected excerpts'),
          ),
        ],
      ),
    );
    if (approved == true) await widget.controller.analyzeSelected();
  }

  Future<void> _confirmDelete(DocumentVaultEntry document) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('document-delete-confirmation'),
        title: const Text('Securely delete document?'),
        content: Text(
          '${document.metadata.fileName} and its derived index will be removed. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('document-delete-approve'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Securely delete'),
          ),
        ],
      ),
    );
    if (approved == true) await widget.controller.delete(document);
  }

  void _focusMarker(DocumentReaderMarker marker) {
    final nodeId = marker.nodeId;
    final clusterId = marker.clusterId;
    if (nodeId == null && clusterId == null) return;
    widget.onBackgroundRequested?.call();
    if (nodeId != null) widget.onFocusNode?.call(nodeId);
    if (clusterId != null) widget.onFocusCluster?.call(clusterId);
  }
}

class _ImportStatus extends StatelessWidget {
  const _ImportStatus({required this.controller});

  final DocumentVaultController controller;

  @override
  Widget build(BuildContext context) {
    final failed = controller.importActivity == DocumentVaultActivity.failed;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Column(
        key: const Key('document-import-status'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!failed)
            LinearProgressIndicator(value: controller.importProgress),
          const SizedBox(height: 4),
          Text(
            failed
                ? controller.importFailure ?? 'Import failed.'
                : controller.importDetail ?? 'Working locally…',
            style: TextStyle(
              color: failed ? Theme.of(context).colorScheme.error : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.document,
    required this.selected,
    required this.onTap,
  });

  final DocumentVaultEntry document;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    color: selected
        ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .6)
        : null,
    child: ListTile(
      key: Key('document-tile-${document.metadata.id}'),
      selected: selected,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      title: Text(document.metadata.fileName, maxLines: 2),
      subtitle: Text(
        document.cloudAnalyzed ? 'Local + cloud excerpts' : 'Local only',
      ),
      onTap: onTap,
    ),
  );
}

class _DocumentReader extends StatelessWidget {
  const _DocumentReader({
    required this.document,
    required this.selectedChunks,
    required this.onToggleChunk,
    required this.onMarker,
    this.onReindex,
    this.onDelete,
    this.onAnalyze,
  });

  final DocumentVaultEntry document;
  final Set<int> selectedChunks;
  final ValueChanged<int> onToggleChunk;
  final ValueChanged<DocumentReaderMarker> onMarker;
  final VoidCallback? onReindex;
  final VoidCallback? onDelete;
  final VoidCallback? onAnalyze;

  @override
  Widget build(BuildContext context) {
    final busy =
        document.activity == DocumentVaultActivity.indexing ||
        document.activity == DocumentVaultActivity.analyzing;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 8, 8),
          child: Row(
            children: [
              const _ProvenanceBadge(label: 'Encrypted local'),
              const SizedBox(width: 6),
              if (document.cloudAnalyzed)
                const _ProvenanceBadge(label: 'Approved excerpts: cloud'),
              const Spacer(),
              IconButton(
                key: const Key('document-reindex'),
                tooltip: 'Reindex document',
                onPressed: busy ? null : onReindex,
                icon: const Icon(Icons.refresh),
              ),
              IconButton(
                key: const Key('document-secure-delete'),
                tooltip: 'Securely delete document',
                onPressed: busy ? null : onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
        if (busy)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: LinearProgressIndicator(
              key: const Key('document-operation-progress'),
              value: document.progress,
            ),
          ),
        if (document.failure != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              document.failure!,
              key: const Key('document-operation-failure'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Expanded(
          child: ListView(
            key: const Key('document-sanitized-reader'),
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
            children: [
              for (
                var index = 0;
                index < document.parsed.blocks.length;
                index++
              )
                _BlockCard(
                  index: index,
                  block: document.parsed.blocks[index],
                  selectedChunkIndexes: document.chunks
                      .where(
                        (chunk) =>
                            chunk.startChar <
                                document.parsed.blocks[index].endChar &&
                            chunk.endChar >
                                document.parsed.blocks[index].startChar,
                      )
                      .map((chunk) => chunk.index)
                      .toList(),
                  selectedChunks: selectedChunks,
                  markers: document.markers
                      .where((marker) => marker.blockIndex == index)
                      .toList(),
                  onToggleChunk: onToggleChunk,
                  onMarker: onMarker,
                ),
              if (document.chunks.isNotEmpty) ...[
                const Divider(height: 32),
                Text(
                  'Selectable excerpts',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                for (final chunk in document.chunks)
                  _ChunkCard(
                    chunk: chunk,
                    selected: selectedChunks.contains(chunk.index),
                    markers: document.markers
                        .where((marker) => marker.chunkIndex == chunk.index)
                        .toList(),
                    onChanged: () => onToggleChunk(chunk.index),
                    onMarker: onMarker,
                  ),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('document-analyze-selected'),
              onPressed: busy ? null : onAnalyze,
              icon: const Icon(Icons.auto_awesome_outlined),
              label: Text(
                selectedChunks.isEmpty
                    ? 'Select excerpts to analyze'
                    : 'Analyze selected excerpts (${selectedChunks.length})',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BlockCard extends StatelessWidget {
  const _BlockCard({
    required this.index,
    required this.block,
    required this.selectedChunkIndexes,
    required this.selectedChunks,
    required this.markers,
    required this.onToggleChunk,
    required this.onMarker,
  });

  final int index;
  final DocumentBlock block;
  final List<int> selectedChunkIndexes;
  final Set<int> selectedChunks;
  final List<DocumentReaderMarker> markers;
  final ValueChanged<int> onToggleChunk;
  final ValueChanged<DocumentReaderMarker> onMarker;

  @override
  Widget build(BuildContext context) {
    final heading = block.kind == DocumentBlockKind.heading;
    final selectable =
        block.kind == DocumentBlockKind.paragraph ||
        block.kind == DocumentBlockKind.listItem;
    final selected =
        selectedChunkIndexes.isNotEmpty &&
        selectedChunkIndexes.every(selectedChunks.contains);
    return Padding(
      padding: EdgeInsets.only(top: heading ? 16 : 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: Key('document-paragraph-$index'),
            onTap: selectable && selectedChunkIndexes.isNotEmpty
                ? () => _toggleParagraph(selected)
                : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selectable)
                    Checkbox(
                      value: selected,
                      onChanged: selectedChunkIndexes.isEmpty
                          ? null
                          : (_) => _toggleParagraph(selected),
                    ),
                  Expanded(
                    child: Text(
                      sanitizeDocumentBlockText(block.text),
                      style: heading
                          ? Theme.of(context).textTheme.titleLarge
                          : Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (markers.isNotEmpty)
            _MarkerWrap(markers: markers, onTap: onMarker),
        ],
      ),
    );
  }

  void _toggleParagraph(bool selected) {
    for (final chunkIndex in selectedChunkIndexes) {
      if (selectedChunks.contains(chunkIndex) == selected) {
        onToggleChunk(chunkIndex);
      }
    }
  }
}

class _ChunkCard extends StatelessWidget {
  const _ChunkCard({
    required this.chunk,
    required this.selected,
    required this.markers,
    required this.onChanged,
    required this.onMarker,
  });

  final DocumentChunk chunk;
  final bool selected;
  final List<DocumentReaderMarker> markers;
  final VoidCallback onChanged;
  final ValueChanged<DocumentReaderMarker> onMarker;

  @override
  Widget build(BuildContext context) => Card(
    key: Key('document-chunk-${chunk.index}'),
    color: selected
        ? Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: .7)
        : null,
    child: InkWell(
      onTap: onChanged,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(value: selected, onChanged: (_) => onChanged()),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sanitizeDocumentBlockText(chunk.text)),
                  if (markers.isNotEmpty)
                    _MarkerWrap(markers: markers, onTap: onMarker),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MarkerWrap extends StatelessWidget {
  const _MarkerWrap({required this.markers, required this.onTap});

  final List<DocumentReaderMarker> markers;
  final ValueChanged<DocumentReaderMarker> onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final marker in markers)
          ActionChip(
            key: Key('document-marker-${marker.id}'),
            avatar: Icon(switch (marker.kind) {
              DocumentMarkerKind.citation => Icons.format_quote,
              DocumentMarkerKind.concept => Icons.hub_outlined,
              DocumentMarkerKind.category => Icons.label_outline,
            }, size: 16),
            label: Text(marker.label),
            onPressed: marker.nodeId == null && marker.clusterId == null
                ? null
                : () => onTap(marker),
          ),
      ],
    ),
  );
}

class _ProvenanceBadge extends StatelessWidget {
  const _ProvenanceBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    ),
  );
}

/// Converts parser output to inert display text. No HTML widget or WebView is
/// used, and control characters that can alter presentation are discarded.
String sanitizeDocumentBlockText(String value) => value
    .replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]'), '')
    .replaceAll('\r\n', '\n')
    .replaceAll('\r', '\n');
