import '../../api/api_transport.dart';
import '../../services/capture_attest_service.dart';

/// An excerpt the user explicitly selected for ephemeral cloud analysis.
final class ApprovedDocumentExcerpt {
  const ApprovedDocumentExcerpt({
    required this.documentId,
    required this.chunkId,
    required this.text,
    required this.format,
  });

  final String documentId;
  final String chunkId;
  final String text;
  final String format;
}

final class DocumentCloudConcept {
  const DocumentCloudConcept({
    required this.id,
    required this.label,
    required this.kind,
    required this.summary,
    required this.citationChunkIds,
  });

  final String id;
  final String label;
  final String kind;
  final String summary;
  final List<String> citationChunkIds;
}

final class DocumentCloudRelationship {
  const DocumentCloudRelationship({
    required this.sourceConceptId,
    required this.targetConceptId,
    required this.type,
    required this.citationChunkIds,
  });

  final String sourceConceptId;
  final String targetConceptId;
  final String type;
  final List<String> citationChunkIds;
}

final class DocumentCloudEntity {
  const DocumentCloudEntity({
    required this.id,
    required this.label,
    required this.type,
    required this.citationChunkIds,
  });

  final String id;
  final String label;
  final String type;
  final List<String> citationChunkIds;
}

final class DocumentCloudArgument {
  const DocumentCloudArgument({
    required this.id,
    required this.claim,
    required this.stance,
    required this.citationChunkIds,
  });

  final String id;
  final String claim;
  final String stance;
  final List<String> citationChunkIds;
}

final class DocumentCloudAnalysis {
  const DocumentCloudAnalysis({
    required this.concepts,
    required this.entities,
    required this.arguments,
    required this.relationships,
    required this.categoryTags,
  });

  final List<DocumentCloudConcept> concepts;
  final List<DocumentCloudEntity> entities;
  final List<DocumentCloudArgument> arguments;
  final List<DocumentCloudRelationship> relationships;
  final List<String> categoryTags;
}

/// Opt-in, non-persistent concept extraction for selected document excerpts.
///
/// URLs, local paths, raw files and personal graph identifiers are never
/// accepted by this API boundary. The caller must present the final selected
/// excerpts to the user before invoking [analyzeSelected].
final class DocumentIngestionAiService {
  const DocumentIngestionAiService({
    required this.transport,
    required this.attest,
  });

  static const maxChunks = 12;
  static const maxChunkCharacters = 3000;
  static const maxTotalCharacters = 24000;

  final ApiTransport transport;
  final CaptureAttestService attest;

  Map<String, Object> buildApprovedPayload(
    Iterable<ApprovedDocumentExcerpt> approved,
  ) => buildPayload(approved);

  static Map<String, Object> buildPayload(
    Iterable<ApprovedDocumentExcerpt> approved,
  ) {
    final chunks = approved.toList(growable: false);
    if (chunks.isEmpty || chunks.length > maxChunks) {
      throw const FormatException('Select between 1 and 12 excerpts.');
    }
    final documentIds = chunks.map((chunk) => chunk.documentId).toSet();
    if (documentIds.length != 1) {
      throw const FormatException('Excerpts must belong to one document.');
    }
    final chunkIds = <String>{};
    var totalCharacters = 0;
    for (final chunk in chunks) {
      if (!_isOpaqueId(chunk.documentId) || !_isOpaqueId(chunk.chunkId)) {
        throw const FormatException('Document and chunk IDs must be opaque.');
      }
      if (!chunkIds.add(chunk.chunkId)) {
        throw const FormatException('Chunk IDs must be unique.');
      }
      final length = chunk.text.length;
      if (length == 0 || length > maxChunkCharacters) {
        throw const FormatException('An excerpt exceeds the size limit.');
      }
      totalCharacters += length;
      if (totalCharacters > maxTotalCharacters) {
        throw const FormatException('Selected excerpts exceed the size limit.');
      }
    }
    return <String, Object>{
      'documentId': chunks.first.documentId,
      'format': chunks.first.format,
      'chunks': <Map<String, Object>>[
        for (final chunk in chunks)
          <String, Object>{'id': chunk.chunkId, 'text': chunk.text},
      ],
    };
  }

  Future<DocumentCloudAnalysis> analyzeSelected(
    Iterable<ApprovedDocumentExcerpt> approved,
  ) async {
    final payload = buildApprovedPayload(approved);
    final allowedChunkIds = (payload['chunks']! as List<Map<String, Object>>)
        .map((chunk) => chunk['id']! as String)
        .toSet();
    final token = await attest.ensureCaptureToken();
    final response = await transport.postJson(
      '/api/document-ingestion',
      headers: {
        ...transport.jsonHeaders,
        ApiTransport.captureTokenHeader: token,
        'x-vm-client': 'voicememory-mobile',
      },
      body: payload,
    );
    return parseResponse(
      transport.decodeJson(response),
      allowedChunkIds: allowedChunkIds,
    );
  }

  static DocumentCloudAnalysis parseResponse(
    Object? value, {
    required Set<String> allowedChunkIds,
  }) {
    if (value is! Map) {
      throw const FormatException('Invalid document analysis response.');
    }
    final json = Map<String, dynamic>.from(value);
    final concepts = (json['concepts'] as List? ?? const <Object>[])
        .whereType<Map>()
        .map((raw) {
          final item = Map<String, dynamic>.from(raw);
          final citations = _validatedCitations(
            item['citationChunkIds'],
            allowedChunkIds,
          );
          return DocumentCloudConcept(
            id: _requiredString(item, 'id'),
            label: _requiredString(item, 'label'),
            kind: _requiredString(item, 'kind'),
            summary: _requiredString(item, 'summary'),
            citationChunkIds: citations,
          );
        })
        .toList(growable: false);
    final conceptIds = concepts.map((concept) => concept.id).toSet();
    if (conceptIds.length != concepts.length) {
      throw const FormatException('Concept IDs must be unique.');
    }
    final relationships = (json['relationships'] as List? ?? const <Object>[])
        .whereType<Map>()
        .map((raw) {
          final item = Map<String, dynamic>.from(raw);
          final source = _requiredString(item, 'sourceConceptId');
          final target = _requiredString(item, 'targetConceptId');
          if (!conceptIds.contains(source) || !conceptIds.contains(target)) {
            throw const FormatException(
              'Relationship references an unknown concept.',
            );
          }
          return DocumentCloudRelationship(
            sourceConceptId: source,
            targetConceptId: target,
            type: _requiredString(item, 'type'),
            citationChunkIds: _validatedCitations(
              item['citationChunkIds'],
              allowedChunkIds,
            ),
          );
        })
        .toList(growable: false);
    final entities = (json['entities'] as List? ?? const <Object>[])
        .whereType<Map>()
        .map((raw) {
          final item = Map<String, dynamic>.from(raw);
          return DocumentCloudEntity(
            id: _requiredString(item, 'id'),
            label: _requiredString(item, 'label'),
            type: _requiredString(item, 'type'),
            citationChunkIds: _validatedCitations(
              item['citationChunkIds'],
              allowedChunkIds,
            ),
          );
        })
        .toList(growable: false);
    final arguments = (json['arguments'] as List? ?? const <Object>[])
        .whereType<Map>()
        .map((raw) {
          final item = Map<String, dynamic>.from(raw);
          return DocumentCloudArgument(
            id: _requiredString(item, 'id'),
            claim: _requiredString(item, 'claim'),
            stance: _requiredString(item, 'stance'),
            citationChunkIds: _validatedCitations(
              item['citationChunkIds'],
              allowedChunkIds,
            ),
          );
        })
        .toList(growable: false);
    final tags = (json['categoryTags'] as List? ?? const <Object>[])
        .whereType<String>()
        .where((tag) => tag.trim().isNotEmpty)
        .map((tag) => tag.trim())
        .toList(growable: false);
    return DocumentCloudAnalysis(
      concepts: concepts,
      entities: entities,
      arguments: arguments,
      relationships: relationships,
      categoryTags: tags,
    );
  }

  static List<String> _validatedCitations(Object? value, Set<String> allowed) {
    final citations = (value as List? ?? const <Object>[])
        .whereType<String>()
        .toList(growable: false);
    if (citations.isEmpty ||
        citations.any((chunkId) => !allowed.contains(chunkId))) {
      throw const FormatException('Analysis contains an invalid citation.');
    }
    return citations;
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Missing $key.');
    }
    return value.trim();
  }

  static bool _isOpaqueId(String value) =>
      RegExp(r'^[A-Za-z0-9_-]{8,96}$').hasMatch(value);
}
