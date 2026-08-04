import 'dart:math';
import 'dart:typed_data';

import '../../core/graph/personal_knowledge_graph_store.dart';
import '../../features/semantic_clusters/semantic_cluster_store.dart';
import 'document_chunker.dart';
import 'document_graph_mapper.dart';
import 'document_ingestion_ai_service.dart';
import 'document_models.dart';
import 'document_parser_service.dart';
import 'document_vault_store.dart';
import 'secure_article_fetcher.dart';
import 'ui/document_vault_sheet.dart';

typedef RejectedDocumentNodeIds = Future<Set<String>> Function();

/// Coordinates offline import, encrypted storage, local indexing and mapping.
final class DocumentIngestionService {
  DocumentIngestionService({
    required this.vault,
    required this.parser,
    required this.chunker,
    required this.articleFetcher,
    required this.mapper,
    required this.personalGraphStore,
    required this.clusterStore,
    required this.aiService,
    required this.rejectedNodeIds,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const maxOriginalBytes = 20 * 1024 * 1024;
  static const maxExtractedCharacters = 5 * 1024 * 1024;
  static const maxChunks = 10000;
  static const maxPdfPages = 2000;

  final DocumentVaultStore vault;
  final DocumentParserService parser;
  final DocumentChunker chunker;
  final SecureArticleFetcher articleFetcher;
  final DocumentGraphMapper mapper;
  final PersonalKnowledgeGraphStore personalGraphStore;
  final SemanticClusterStore clusterStore;
  final DocumentIngestionAiService aiService;
  final RejectedDocumentNodeIds rejectedNodeIds;
  final DateTime Function() _clock;

  Future<DocumentVaultController> createController() async {
    final documents = await listDocuments();
    return DocumentVaultController(
      documents: documents,
      onImportBytes: importBytes,
      onImportUrl: importUrl,
      onReindex: reindex,
      onDelete: delete,
      onAnalyzeSelected: analyzeSelected,
    );
  }

  Future<List<DocumentVaultEntry>> listDocuments() async {
    final metadata = await vault.list();
    final result = <DocumentVaultEntry>[];
    for (final item in metadata) {
      final record = await vault.readRecord(item.id);
      if (record != null) {
        result.add(
          _entry(
            metadata: record.metadata,
            parsed: record.parsed,
            chunks: record.chunks,
            overlay: await mapper.overlayStore.load(),
            conceptResult: record.conceptResult,
          ),
        );
        continue;
      }
      final entry = await vault.withOriginal(
        item.id,
        (bytes) => _entryFromBytes(item, bytes),
      );
      if (entry != null) result.add(entry);
    }
    return List.unmodifiable(result);
  }

  Future<DocumentVaultEntry> importBytes(
    DocumentImportRequest request,
    void Function(double progress, String? detail) reportProgress,
  ) async {
    reportProgress(.05, 'Validating local file');
    final format = _formatFor(request.fileName);
    final mimeType = _mimeType(format);
    final bytes = request.bytes;
    try {
      _validateOriginal(bytes);
      reportProgress(.2, 'Parsing locally');
      final parsed = await parser.parse(
        bytes,
        format: format,
        sourceName: request.fileName,
      );
      final chunks = _validatedChunks(parsed);
      final id = _opaqueId('doc');
      final metadata = StoredDocumentMetadata(
        id: id,
        fileName: _safeFileName(request.fileName),
        mimeType: mimeType,
        byteLength: bytes.length,
        createdAt: _clock().toUtc(),
      );
      reportProgress(.45, 'Encrypting private document');
      await vault.put(metadata: metadata, originalBytes: bytes);
      await vault.putRecord(
        StoredDocumentRecord(
          metadata: metadata,
          parsed: parsed,
          chunks: chunks,
        ),
      );
      reportProgress(.65, 'Generating local embeddings');
      await _map(id, chunks);
      reportProgress(1, 'Indexed privately on this device');
      return _entry(
        metadata: metadata,
        parsed: parsed,
        chunks: chunks,
        overlay: await mapper.overlayStore.load(),
      );
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  }

  Future<DocumentVaultEntry> importUrl(
    Uri uri,
    void Function(double progress, String? detail) reportProgress,
  ) async {
    reportProgress(.05, 'Fetching approved HTTPS article');
    final fetched = await articleFetcher.fetch(uri);
    try {
      reportProgress(.3, 'Extracting readable content locally');
      final parsed = await parser.parse(
        fetched.body,
        format: DocumentFormat.html,
        sourceName: 'article.html',
      );
      final chunks = _validatedChunks(parsed);
      final id = _opaqueId('doc');
      final metadata = StoredDocumentMetadata(
        id: id,
        fileName: _articleFileName(parsed.title),
        mimeType: 'text/html',
        byteLength: fetched.body.length,
        createdAt: _clock().toUtc(),
      );
      reportProgress(.55, 'Encrypting private article');
      await vault.put(metadata: metadata, originalBytes: fetched.body);
      await vault.putRecord(
        StoredDocumentRecord(
          metadata: metadata,
          parsed: parsed,
          chunks: chunks,
        ),
      );
      reportProgress(.75, 'Generating local embeddings');
      await _map(id, chunks);
      reportProgress(1, 'Indexed privately on this device');
      return _entry(
        metadata: metadata,
        parsed: parsed,
        chunks: chunks,
        overlay: await mapper.overlayStore.load(),
      );
    } finally {
      fetched.body.fillRange(0, fetched.body.length, 0);
    }
  }

  Future<DocumentVaultEntry> reindex(
    DocumentVaultEntry document,
    void Function(double progress, String? detail) reportProgress,
  ) async {
    reportProgress(.1, 'Decrypting locally');
    final next = await vault.withOriginal(document.metadata.id, (bytes) async {
      final entry = await _entryFromBytes(document.metadata, bytes);
      await vault.putRecord(
        StoredDocumentRecord(
          metadata: document.metadata,
          parsed: entry.parsed,
          chunks: entry.chunks,
        ),
      );
      reportProgress(.55, 'Rebuilding local vectors');
      await _map(document.metadata.id, entry.chunks);
      return _entry(
        metadata: document.metadata,
        parsed: entry.parsed,
        chunks: entry.chunks,
        overlay: await mapper.overlayStore.load(),
      );
    });
    if (next == null) throw StateError('Document is no longer available.');
    reportProgress(1, 'Re-index complete');
    return next;
  }

  Future<void> delete(DocumentVaultEntry document) async {
    await mapper.removeDocument(document.metadata.id);
    await vault.delete(document.metadata.id);
  }

  Future<DocumentVaultEntry> analyzeSelected(
    DocumentVaultEntry document,
    List<DocumentChunk> selected,
    void Function(double progress, String? detail) reportProgress,
  ) async {
    reportProgress(.1, 'Preparing only selected excerpts');
    final analysis = await aiService.analyzeSelected([
      for (final chunk in selected)
        ApprovedDocumentExcerpt(
          documentId: document.metadata.id,
          chunkId: _chunkOpaqueId(document.metadata.id, chunk.index),
          text: chunk.text,
          format: _formatFor(document.metadata.fileName).name,
        ),
    ]);
    reportProgress(.85, 'Validating citations');
    final overlay = await mapper.overlayStore.load();
    final nodeByChunk = <int, String>{
      for (final entry in overlay.citations.entries)
        if (entry.value.documentId == document.metadata.id)
          entry.value.chunkIndex: entry.key,
    };
    final markers = <DocumentReaderMarker>[...document.markers];
    for (final concept in analysis.concepts) {
      for (final chunkId in concept.citationChunkIds) {
        final index = _chunkIndex(document.metadata.id, chunkId);
        markers.add(
          DocumentReaderMarker(
            id: 'cloud-${concept.id}-$index',
            kind: DocumentMarkerKind.concept,
            label: concept.label,
            chunkIndex: index,
            nodeId: nodeByChunk[index],
          ),
        );
      }
    }
    for (var index = 0; index < analysis.categoryTags.length; index++) {
      markers.add(
        DocumentReaderMarker(
          id: 'category-$index',
          kind: DocumentMarkerKind.category,
          label: analysis.categoryTags[index],
        ),
      );
    }
    await vault.putRecord(
      StoredDocumentRecord(
        metadata: document.metadata,
        parsed: document.parsed,
        chunks: document.chunks,
        conceptResult: _analysisJson(analysis),
      ),
    );
    reportProgress(1, 'Approved excerpt analysis complete');
    return document.copyWith(cloudAnalyzed: true, markers: markers);
  }

  Future<DocumentVaultEntry> _entryFromBytes(
    StoredDocumentMetadata metadata,
    Uint8List bytes,
  ) async {
    final parsed = await parser.parse(
      bytes,
      format: _formatFor(metadata.fileName),
      sourceName: metadata.fileName,
    );
    final chunks = _validatedChunks(parsed);
    return _entry(
      metadata: metadata,
      parsed: parsed,
      chunks: chunks,
      overlay: await mapper.overlayStore.load(),
    );
  }

  Future<void> _map(String documentId, List<DocumentChunk> chunks) async {
    await mapper.mapDocument(
      documentId: documentId,
      chunks: chunks,
      personalGraph: await personalGraphStore.load(),
      clusters: await clusterStore.list(),
      rejectedNodeIds: await rejectedNodeIds(),
    );
  }

  DocumentVaultEntry _entry({
    required StoredDocumentMetadata metadata,
    required ParsedDocument parsed,
    required List<DocumentChunk> chunks,
    required DocumentOverlaySnapshot overlay,
    Map<String, dynamic>? conceptResult,
  }) {
    final markers = <DocumentReaderMarker>[];
    for (final entry in overlay.citations.entries) {
      final citation = entry.value;
      if (citation.documentId != metadata.id) continue;
      markers.add(
        DocumentReaderMarker(
          id: 'citation-${entry.key}',
          kind: DocumentMarkerKind.citation,
          label: _citationLabel(citation),
          blockIndex: _blockIndex(parsed, citation),
          chunkIndex: citation.chunkIndex,
          nodeId: entry.key,
        ),
      );
    }
    for (final attribution in overlay.attributions) {
      if (attribution.documentId != metadata.id) continue;
      markers.add(
        DocumentReaderMarker(
          id: 'cluster-${attribution.documentNodeId}-${attribution.clusterId}',
          kind: DocumentMarkerKind.category,
          label: 'Related cluster',
          chunkIndex: attribution.citation.chunkIndex,
          nodeId: attribution.documentNodeId,
          clusterId: attribution.clusterId,
        ),
      );
    }
    if (conceptResult != null) {
      for (final raw
          in (conceptResult['concepts'] as List? ?? const [])
              .whereType<Map>()) {
        final concept = Map<String, dynamic>.from(raw);
        for (final chunkId
            in (concept['citationChunkIds'] as List? ?? const [])
                .whereType<String>()) {
          final index = _chunkIndex(metadata.id, chunkId);
          markers.add(
            DocumentReaderMarker(
              id: 'cloud-${concept['id']}-$index',
              kind: DocumentMarkerKind.concept,
              label: concept['label'] as String? ?? 'Concept',
              chunkIndex: index,
              nodeId: overlay.citations.entries
                  .where(
                    (entry) =>
                        entry.value.documentId == metadata.id &&
                        entry.value.chunkIndex == index,
                  )
                  .map((entry) => entry.key)
                  .firstOrNull,
            ),
          );
        }
      }
    }
    return DocumentVaultEntry(
      metadata: metadata,
      parsed: parsed,
      chunks: chunks,
      markers: markers,
      cloudAnalyzed: conceptResult != null,
    );
  }

  List<DocumentChunk> _validatedChunks(ParsedDocument parsed) {
    if (parsed.text.length > maxExtractedCharacters) {
      throw const DocumentParseException('Extracted text is too large.');
    }
    final pages = parsed.blocks
        .map((block) => block.pageNumber)
        .whereType<int>();
    if (pages.isNotEmpty && pages.reduce(max) > maxPdfPages) {
      throw const DocumentParseException('PDF page limit exceeded.');
    }
    final chunks = chunker.chunk(parsed);
    if (chunks.length > maxChunks) {
      throw const DocumentParseException('Document chunk limit exceeded.');
    }
    return chunks;
  }

  static void _validateOriginal(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > maxOriginalBytes) {
      throw const DocumentParseException('Document size limit exceeded.');
    }
  }

  static DocumentFormat _formatFor(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return DocumentFormat.pdf;
    if (lower.endsWith('.epub')) return DocumentFormat.epub;
    if (lower.endsWith('.md') || lower.endsWith('.markdown')) {
      return DocumentFormat.markdown;
    }
    if (lower.endsWith('.html') || lower.endsWith('.htm')) {
      return DocumentFormat.html;
    }
    if (lower.endsWith('.txt')) return DocumentFormat.plainText;
    throw const DocumentParseException('Unsupported document format.');
  }

  static String _mimeType(DocumentFormat format) => switch (format) {
    DocumentFormat.pdf => 'application/pdf',
    DocumentFormat.epub => 'application/epub+zip',
    DocumentFormat.markdown => 'text/markdown',
    DocumentFormat.html => 'text/html',
    DocumentFormat.plainText => 'text/plain',
  };

  static String _safeFileName(String value) {
    final leaf = value.replaceAll('\\', '/').split('/').last.trim();
    return leaf.isEmpty ? 'document.txt' : leaf;
  }

  static String _articleFileName(String? title) {
    final safe = (title ?? 'Saved article')
        .replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '')
        .trim();
    return '${safe.isEmpty ? 'Saved article' : safe.substring(0, min(80, safe.length))}.html';
  }

  static String _citationLabel(DocumentCitation citation) {
    if (citation.pageNumbers.isNotEmpty) {
      return 'Page ${citation.pageNumbers.join(', ')}';
    }
    if (citation.chapterIndexes.isNotEmpty) {
      return 'Chapter ${citation.chapterIndexes.first + 1}';
    }
    return 'Excerpt ${citation.chunkIndex + 1}';
  }

  static Map<String, dynamic> _analysisJson(DocumentCloudAnalysis analysis) => {
    'concepts': [
      for (final concept in analysis.concepts)
        {
          'id': concept.id,
          'label': concept.label,
          'kind': concept.kind,
          'summary': concept.summary,
          'citationChunkIds': concept.citationChunkIds,
        },
    ],
    'entities': [
      for (final entity in analysis.entities)
        {
          'id': entity.id,
          'label': entity.label,
          'type': entity.type,
          'citationChunkIds': entity.citationChunkIds,
        },
    ],
    'arguments': [
      for (final argument in analysis.arguments)
        {
          'id': argument.id,
          'claim': argument.claim,
          'stance': argument.stance,
          'citationChunkIds': argument.citationChunkIds,
        },
    ],
    'categoryTags': analysis.categoryTags,
    'relationships': [
      for (final relationship in analysis.relationships)
        {
          'sourceConceptId': relationship.sourceConceptId,
          'targetConceptId': relationship.targetConceptId,
          'type': relationship.type,
          'citationChunkIds': relationship.citationChunkIds,
        },
    ],
  };

  static int? _blockIndex(ParsedDocument document, DocumentCitation citation) {
    for (var index = 0; index < document.blocks.length; index++) {
      final block = document.blocks[index];
      if (block.startChar < citation.endChar &&
          block.endChar > citation.startChar) {
        return index;
      }
    }
    return null;
  }

  static String _opaqueId(String prefix) {
    final random = Random.secure();
    const alphabet =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final token = List.generate(
      24,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
    return '${prefix}_$token';
  }

  static String _chunkOpaqueId(String documentId, int index) =>
      'chunk_${_stableHash('$documentId:$index')}';

  static int _chunkIndex(String documentId, String opaqueId) {
    // Only selected chunks are accepted by the route. Resolve by deterministic
    // IDs without exposing local paths or graph identifiers.
    for (var index = 0; index < maxChunks; index++) {
      if (_chunkOpaqueId(documentId, index) == opaqueId) return index;
    }
    throw const FormatException('Cloud response invented a chunk citation.');
  }

  static String _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
