import 'dart:convert';
import 'dart:typed_data';

import 'package:html/parser.dart' as html_parser;
import 'package:uuid/uuid.dart';

import '../../core/graph/personal_knowledge_graph_store.dart';
import '../../services/local_storage/browser_bridge_vault.dart';
import '../document_ingestion/document_chunker.dart';
import '../document_ingestion/document_graph_mapper.dart';
import '../document_ingestion/document_models.dart';
import '../document_ingestion/document_parser_service.dart';
import '../document_ingestion/document_semantic_index.dart';
import '../semantic_clusters/semantic_cluster_store.dart';
import 'browser_bridge_models.dart';

typedef BrowserAutoTaggingPreference = Future<bool> Function();
typedef BrowserRejectedNodeIds = Future<Set<String>> Function();

final class ClipperIngestionResult {
  const ClipperIngestionResult({
    required this.clipId,
    required this.chunkCount,
    required this.clusterIds,
  });

  final String clipId;
  final int chunkCount;
  final List<String> clusterIds;
}

/// Local-only web clip sanitization, encrypted persistence and vector mapping.
final class ClipperIngestionEngine {
  const ClipperIngestionEngine({
    required this.vault,
    required this.parser,
    required this.chunker,
    required this.semanticIndex,
    required this.mapper,
    required this.graphStore,
    required this.clusterStore,
    required this.autoTaggingEnabled,
    required this.rejectedNodeIds,
  });

  static const maxContentCharacters = 5 * 1024 * 1024;
  static const maxScreenshotBytes = 12 * 1024 * 1024;
  static const maxHighlights = 256;

  final BrowserBridgeVault vault;
  final DocumentParserService parser;
  final DocumentChunker chunker;
  final DocumentSemanticIndex semanticIndex;
  final DocumentGraphMapper mapper;
  final PersonalKnowledgeGraphStore graphStore;
  final SemanticClusterStore clusterStore;
  final BrowserAutoTaggingPreference autoTaggingEnabled;
  final BrowserRejectedNodeIds rejectedNodeIds;

  Future<ClipperIngestionResult> ingest({
    required String extensionId,
    required WebClipPayload payload,
  }) async {
    _validate(payload);
    final clipId = 'webclip_${const Uuid().v4()}';
    final sanitized = payload.contentType.contains('markdown')
        ? _sanitizeMarkdown(payload.content)
        : sanitizeHtml(payload.content);
    final source = _withHighlights(
      sanitized,
      payload.selection,
      payload.highlights,
      markdown: payload.contentType.contains('markdown'),
    );
    final format = payload.contentType.contains('markdown')
        ? DocumentFormat.markdown
        : DocumentFormat.html;
    final parsed = await parser.parse(
      Uint8List.fromList(utf8.encode(source)),
      format: format,
      sourceName: '${_safeTitle(payload.title)}.${format.name}',
    );
    final chunks = chunker.chunk(parsed);
    if (chunks.isEmpty) {
      throw const FormatException('The web clip contains no readable text.');
    }

    List<String> clusterIds = const [];
    if (await autoTaggingEnabled()) {
      final overlay = await mapper.mapDocument(
        documentId: clipId,
        chunks: chunks,
        personalGraph: await graphStore.load(),
        clusters: await clusterStore.list(),
        rejectedNodeIds: await rejectedNodeIds(),
      );
      clusterIds =
          overlay.attributions
              .where((item) => item.documentId == clipId)
              .map((item) => item.clusterId)
              .toSet()
              .toList()
            ..sort();
    } else {
      await semanticIndex.indexDocument(clipId, chunks);
    }

    await vault.recordClip(
      BrowserClipRecord(
        id: clipId,
        extensionId: extensionId,
        payload: WebClipPayload(
          url: payload.url,
          title: payload.title,
          content: source,
          contentType: payload.contentType,
          capturedAt: payload.capturedAt,
          selection: payload.selection,
          highlights: payload.highlights,
          metadata: payload.metadata,
          screenshot: payload.screenshot,
        ),
        chunkCount: chunks.length,
        clusterIds: clusterIds,
      ),
    );
    return ClipperIngestionResult(
      clipId: clipId,
      chunkCount: chunks.length,
      clusterIds: List.unmodifiable(clusterIds),
    );
  }

  static String sanitizeHtml(String source) {
    final document = html_parser.parse(source);
    for (final selector in const [
      'script',
      'style',
      'noscript',
      'iframe',
      'object',
      'embed',
      'form',
      'input',
      'button',
      'canvas',
      'svg',
      'link',
      'meta[http-equiv]',
    ]) {
      for (final element in document.querySelectorAll(selector)) {
        element.remove();
      }
    }
    for (final element in document.querySelectorAll('*')) {
      final remove = element.attributes.keys
          .where(
            (key) =>
                key.toString().toLowerCase().startsWith('on') ||
                {
                  'style',
                  'srcset',
                  'ping',
                  'nonce',
                }.contains(key.toString().toLowerCase()),
          )
          .toList();
      for (final key in remove) {
        element.attributes.remove(key);
      }
      if (element.localName == 'img') {
        final width = int.tryParse(element.attributes['width'] ?? '');
        final height = int.tryParse(element.attributes['height'] ?? '');
        if ((width != null && width <= 2) || (height != null && height <= 2)) {
          element.remove();
        } else {
          final src = element.attributes['src'];
          if (src != null &&
              (src.startsWith('data:') ||
                  src.contains('pixel') ||
                  src.contains('tracker'))) {
            element.attributes.remove('src');
          }
        }
      }
    }
    return document.outerHtml;
  }

  static String _sanitizeMarkdown(String source) => source
      .replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<iframe[\s\S]*?</iframe>', caseSensitive: false), '')
      .replaceAll(RegExp(r'!\[[^\]]*\]\(data:[^)]+\)'), '')
      .trim();

  static String _withHighlights(
    String source,
    String? selection,
    List<String> highlights, {
    required bool markdown,
  }) {
    final values = {
      if (selection?.trim().isNotEmpty == true) selection!.trim(),
      ...highlights.map((item) => item.trim()).where((item) => item.isNotEmpty),
    };
    if (values.isEmpty) return source;
    if (markdown) {
      return '$source\n\n## Saved highlights\n\n'
          '${values.map((item) => '> $item').join('\n\n')}';
    }
    final escaped = values.map(const HtmlEscape().convert);
    return '$source<section><h2>Saved highlights</h2>'
        '${escaped.map((item) => '<blockquote>$item</blockquote>').join()}'
        '</section>';
  }

  static String _safeTitle(String value) {
    final safe = value
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    return safe.isEmpty
        ? 'web_clip'
        : safe.substring(0, safe.length.clamp(0, 80));
  }

  static void _validate(WebClipPayload payload) {
    if (payload.content.trim().isEmpty ||
        payload.content.length > maxContentCharacters) {
      throw const FormatException('Invalid web clip content size.');
    }
    if (payload.highlights.length > maxHighlights) {
      throw const FormatException('Too many web clip highlights.');
    }
    if ((payload.screenshot?.length ?? 0) > maxScreenshotBytes) {
      throw const FormatException('Web clip screenshot is too large.');
    }
  }
}
