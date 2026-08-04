import 'dart:collection';

enum DocumentFormat { pdf, epub, markdown, html, plainText }

enum DocumentBlockKind { heading, paragraph, listItem, table, pageBreak }

final class DocumentBlock {
  DocumentBlock({
    required this.kind,
    required this.text,
    required this.startChar,
    required this.endChar,
    this.headingLevel,
    this.pageNumber,
    this.chapterIndex,
    this.chapterTitle,
  }) {
    if (startChar < 0 || endChar < startChar) {
      throw ArgumentError('Invalid block character range.');
    }
  }

  final DocumentBlockKind kind;
  final String text;
  final int startChar;
  final int endChar;
  final int? headingLevel;
  final int? pageNumber;
  final int? chapterIndex;
  final String? chapterTitle;

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'text': text,
    'startChar': startChar,
    'endChar': endChar,
    if (headingLevel != null) 'headingLevel': headingLevel,
    if (pageNumber != null) 'pageNumber': pageNumber,
    if (chapterIndex != null) 'chapterIndex': chapterIndex,
    if (chapterTitle != null) 'chapterTitle': chapterTitle,
  };

  factory DocumentBlock.fromJson(Map<String, dynamic> json) => DocumentBlock(
    kind: DocumentBlockKind.values.byName(json['kind'] as String),
    text: json['text'] as String,
    startChar: (json['startChar'] as num).toInt(),
    endChar: (json['endChar'] as num).toInt(),
    headingLevel: (json['headingLevel'] as num?)?.toInt(),
    pageNumber: (json['pageNumber'] as num?)?.toInt(),
    chapterIndex: (json['chapterIndex'] as num?)?.toInt(),
    chapterTitle: json['chapterTitle'] as String?,
  );
}

final class ParsedDocument {
  ParsedDocument({
    required this.format,
    required this.text,
    required Iterable<DocumentBlock> blocks,
    this.title,
  }) : blocks = UnmodifiableListView(blocks) {
    for (final block in this.blocks) {
      if (block.endChar > text.length ||
          text.substring(block.startChar, block.endChar) != block.text) {
        throw ArgumentError('Block provenance does not match document text.');
      }
    }
  }

  final DocumentFormat format;
  final String text;
  final List<DocumentBlock> blocks;
  final String? title;

  Map<String, dynamic> toJson() => {
    'format': format.name,
    'text': text,
    'blocks': blocks.map((block) => block.toJson()).toList(),
    if (title != null) 'title': title,
  };

  factory ParsedDocument.fromJson(Map<String, dynamic> json) => ParsedDocument(
    format: DocumentFormat.values.byName(json['format'] as String),
    text: json['text'] as String,
    blocks: (json['blocks'] as List).whereType<Map>().map(
      (block) => DocumentBlock.fromJson(Map<String, dynamic>.from(block)),
    ),
    title: json['title'] as String?,
  );
}

final class DocumentChunk {
  DocumentChunk({
    required this.index,
    required this.text,
    required this.startChar,
    required this.endChar,
    required this.tokenCount,
    required Iterable<int> pageNumbers,
    required Iterable<int> chapterIndexes,
  }) : pageNumbers = UnmodifiableListView(pageNumbers.toSet().toList()..sort()),
       chapterIndexes = UnmodifiableListView(
         chapterIndexes.toSet().toList()..sort(),
       );

  final int index;
  final String text;
  final int startChar;
  final int endChar;
  final int tokenCount;
  final List<int> pageNumbers;
  final List<int> chapterIndexes;

  Map<String, dynamic> toJson() => {
    'index': index,
    'text': text,
    'startChar': startChar,
    'endChar': endChar,
    'tokenCount': tokenCount,
    'pageNumbers': pageNumbers,
    'chapterIndexes': chapterIndexes,
  };

  factory DocumentChunk.fromJson(Map<String, dynamic> json) => DocumentChunk(
    index: (json['index'] as num).toInt(),
    text: json['text'] as String,
    startChar: (json['startChar'] as num).toInt(),
    endChar: (json['endChar'] as num).toInt(),
    tokenCount: (json['tokenCount'] as num).toInt(),
    pageNumbers: (json['pageNumbers'] as List? ?? const [])
        .whereType<num>()
        .map((value) => value.toInt()),
    chapterIndexes: (json['chapterIndexes'] as List? ?? const [])
        .whereType<num>()
        .map((value) => value.toInt()),
  );
}

final class StoredDocumentMetadata {
  StoredDocumentMetadata({
    required this.id,
    required this.fileName,
    required this.mimeType,
    required this.byteLength,
    required this.createdAt,
    this.deletedAt,
  });

  final String id;
  final String fileName;
  final String mimeType;
  final int byteLength;
  final DateTime createdAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'fileName': fileName,
    'mimeType': mimeType,
    'byteLength': byteLength,
    'createdAt': createdAt.toUtc().toIso8601String(),
    if (deletedAt != null) 'deletedAt': deletedAt!.toUtc().toIso8601String(),
  };

  factory StoredDocumentMetadata.fromJson(Map<String, dynamic> json) {
    return StoredDocumentMetadata(
      id: json['id'] as String,
      fileName: json['fileName'] as String,
      mimeType: json['mimeType'] as String,
      byteLength: json['byteLength'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String),
    );
  }
}

final class StoredDocumentRecord {
  StoredDocumentRecord({
    required this.metadata,
    required this.parsed,
    required Iterable<DocumentChunk> chunks,
    Map<String, dynamic>? conceptResult,
  }) : chunks = UnmodifiableListView(chunks),
       conceptResult = conceptResult == null
           ? null
           : UnmodifiableMapView(Map<String, dynamic>.from(conceptResult));

  final StoredDocumentMetadata metadata;
  final ParsedDocument parsed;
  final List<DocumentChunk> chunks;
  final Map<String, dynamic>? conceptResult;

  Map<String, dynamic> toJson() => {
    'metadata': metadata.toJson(),
    'parsed': parsed.toJson(),
    'chunks': chunks.map((chunk) => chunk.toJson()).toList(),
    if (conceptResult != null) 'conceptResult': conceptResult,
  };

  factory StoredDocumentRecord.fromJson(Map<String, dynamic> json) =>
      StoredDocumentRecord(
        metadata: StoredDocumentMetadata.fromJson(
          Map<String, dynamic>.from(json['metadata'] as Map),
        ),
        parsed: ParsedDocument.fromJson(
          Map<String, dynamic>.from(json['parsed'] as Map),
        ),
        chunks: (json['chunks'] as List).whereType<Map>().map(
          (chunk) => DocumentChunk.fromJson(Map<String, dynamic>.from(chunk)),
        ),
        conceptResult: json['conceptResult'] is Map
            ? Map<String, dynamic>.from(json['conceptResult'] as Map)
            : null,
      );
}
