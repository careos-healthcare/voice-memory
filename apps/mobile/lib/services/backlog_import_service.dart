import 'dart:convert';
import 'dart:io';

import 'package:archiveme_mobile/api/api_exceptions.dart';
import 'package:archiveme_mobile/api/models/ledger_dto.dart';
import 'package:archiveme_mobile/core/network/api_failure_mapper.dart';
import 'package:archiveme_mobile/core/network/voice_memory_api_routes.dart';
import 'package:archiveme_mobile/core/network/http_transport.dart';
import 'package:archiveme_mobile/core/network/multipart_file_part.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

const _supportedExtensions = {'txt', 'csv', 'm4a', 'mp3'};
const _textBatchSize = 20;
const _uuid = Uuid();

/// One parsed historical entry ready for ledger bulk import.
class BacklogImportChunk {
  const BacklogImportChunk({
    required this.entryId,
    required this.sourceFile,
    required this.kind,
    this.rawText,
    this.audioPath,
    this.createdAt,
  });

  final String entryId;
  final String sourceFile;
  final BacklogImportChunkKind kind;
  final String? rawText;
  final String? audioPath;
  final DateTime? createdAt;
}

enum BacklogImportChunkKind { text, audio }

enum BacklogImportPhase {
  idle,
  picking,
  parsing,
  uploading,
  processing,
  generatingInsight,
  complete,
  error,
}

/// Cold-start insight returned after backlog import finalizes.
class BacklogImportInsight {
  const BacklogImportInsight({
    required this.id,
    required this.insightText,
    required this.kind,
    required this.confidenceBand,
    required this.citedEntryIds,
  });

  factory BacklogImportInsight.fromJson(Map<String, dynamic> json) {
    return BacklogImportInsight(
      id: json['id'] as String? ?? '',
      insightText: json['insightText'] as String? ?? '',
      kind: json['kind'] as String? ?? 'theme',
      confidenceBand: json['confidenceBand'] as String? ?? 'weak',
      citedEntryIds: (json['citedEntryIds'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
    );
  }

  final String id;
  final String insightText;
  final String kind;
  final String confidenceBand;
  final List<String> citedEntryIds;
}

/// Upload and parsing progress for onboarding backlog import.
class BacklogImportProgress {
  const BacklogImportProgress({
    this.phase = BacklogImportPhase.idle,
    this.totalChunks = 0,
    this.processedChunks = 0,
    this.importedCount = 0,
    this.failedCount = 0,
    this.statusMessage,
    this.errorMessage,
    this.insight,
  });

  final BacklogImportPhase phase;
  final int totalChunks;
  final int processedChunks;
  final int importedCount;
  final int failedCount;
  final String? statusMessage;
  final String? errorMessage;
  final BacklogImportInsight? insight;

  double get fraction {
    if (totalChunks <= 0) return 0;
    return processedChunks / totalChunks;
  }

  bool get isActive =>
      phase == BacklogImportPhase.picking ||
      phase == BacklogImportPhase.parsing ||
      phase == BacklogImportPhase.uploading ||
      phase == BacklogImportPhase.processing ||
      phase == BacklogImportPhase.generatingInsight;

  BacklogImportProgress copyWith({
    BacklogImportPhase? phase,
    int? totalChunks,
    int? processedChunks,
    int? importedCount,
    int? failedCount,
    String? statusMessage,
    String? errorMessage,
    BacklogImportInsight? insight,
    bool clearError = false,
    bool clearInsight = false,
  }) {
    return BacklogImportProgress(
      phase: phase ?? this.phase,
      totalChunks: totalChunks ?? this.totalChunks,
      processedChunks: processedChunks ?? this.processedChunks,
      importedCount: importedCount ?? this.importedCount,
      failedCount: failedCount ?? this.failedCount,
      statusMessage: statusMessage ?? this.statusMessage,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      insight: clearInsight ? null : (insight ?? this.insight),
    );
  }
}

/// Picks export files, parses Apple Notes dumps, and uploads ledger chunks.
class BacklogImportService {
  BacklogImportService(this._transport);

  final HttpTransport _transport;

  Future<List<PlatformFile>> pickExportFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _supportedExtensions.toList(),
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) {
      return const [];
    }
    return result.files
        .where((file) => _extensionFor(file.name) != null)
        .toList(growable: false);
  }

  List<BacklogImportChunk> parseSelectedFiles(List<PlatformFile> files) {
    final chunks = <BacklogImportChunk>[];
    for (final file in files) {
      final extension = _extensionFor(file.name);
      if (extension == null) continue;

      if (extension == 'm4a' || extension == 'mp3') {
        final path = file.path;
        if (path == null || path.isEmpty) continue;
        chunks.add(
          BacklogImportChunk(
            entryId: _uuid.v4(),
            sourceFile: file.name,
            kind: BacklogImportChunkKind.audio,
            audioPath: path,
          ),
        );
        continue;
      }

      final content = _readTextContent(file);
      if (content == null || content.trim().isEmpty) continue;

      if (extension == 'csv') {
        chunks.addAll(parseAppleNotesCsv(content, sourceFile: file.name));
      } else {
        chunks.addAll(parseRawTextDump(content, sourceFile: file.name));
      }
    }
    return chunks;
  }

  Future<BacklogImportProgress> uploadQueue(
    List<BacklogImportChunk> chunks, {
    void Function(BacklogImportProgress progress)? onProgress,
    String? activeLens,
  }) async {
    if (chunks.isEmpty) {
      const progress = BacklogImportProgress(
        phase: BacklogImportPhase.complete,
        statusMessage: 'No entries found in the selected files.',
      );
      onProgress?.call(progress);
      return progress;
    }

    var imported = 0;
    var failed = 0;
    var processed = 0;
    final total = chunks.length;

    void emit(BacklogImportProgress progress) => onProgress?.call(progress);

    emit(
      BacklogImportProgress(
        phase: BacklogImportPhase.uploading,
        totalChunks: total,
        processedChunks: processed,
        importedCount: imported,
        failedCount: failed,
        statusMessage: 'Uploading historical entries…',
      ),
    );

    final textChunks = chunks
        .where((chunk) => chunk.kind == BacklogImportChunkKind.text)
        .toList(growable: false);
    final audioChunks = chunks
        .where((chunk) => chunk.kind == BacklogImportChunkKind.audio)
        .toList(growable: false);
    final coldStartTranscript = _latestChunkText(chunks);
    BacklogImportInsight? coldStartInsight;

    for (var index = 0; index < textChunks.length; index += _textBatchSize) {
      final end = (index + _textBatchSize).clamp(0, textChunks.length);
      final batch = textChunks.sublist(index, end);
      final isLastTextBatch = end >= textChunks.length;
      final finalizeColdStart = isLastTextBatch && audioChunks.isEmpty;

      try {
        if (finalizeColdStart && audioChunks.isEmpty) {
          emit(
            BacklogImportProgress(
              phase: BacklogImportPhase.generatingInsight,
              totalChunks: total,
              processedChunks: processed,
              importedCount: imported,
              failedCount: failed,
              statusMessage: 'Finding patterns in your history…',
            ),
          );
        }

        final batchResult = await _uploadTextBatch(
          batch,
          finalizeColdStart: finalizeColdStart && audioChunks.isEmpty,
          coldStartTranscript: coldStartTranscript,
          activeLens: activeLens,
        );
        imported += batchResult.imported;
        failed += batchResult.failed;
        coldStartInsight ??= batchResult.insight;
      } on ApiException {
        failed += batch.length;
      }
      processed += batch.length;
      emit(
        BacklogImportProgress(
          phase: BacklogImportPhase.uploading,
          totalChunks: total,
          processedChunks: processed,
          importedCount: imported,
          failedCount: failed,
          insight: coldStartInsight,
          statusMessage: coldStartInsight != null
              ? 'Your first insight is ready.'
              : 'Uploading notes ($processed of $total)…',
        ),
      );
    }

    for (var audioIndex = 0; audioIndex < audioChunks.length; audioIndex++) {
      final chunk = audioChunks[audioIndex];
      final isLastAudio = audioIndex == audioChunks.length - 1;
      emit(
        BacklogImportProgress(
          phase: BacklogImportPhase.processing,
          totalChunks: total,
          processedChunks: processed,
          importedCount: imported,
          failedCount: failed,
          statusMessage: 'Transcribing ${chunk.sourceFile}…',
        ),
      );
      try {
        if (isLastAudio) {
          emit(
            BacklogImportProgress(
              phase: BacklogImportPhase.generatingInsight,
              totalChunks: total,
              processedChunks: processed,
              importedCount: imported,
              failedCount: failed,
              statusMessage: 'Finding patterns in your history…',
            ),
          );
        }

        final audioResult = await _uploadAudioChunk(
          chunk,
          finalizeColdStart: isLastAudio,
          coldStartTranscript: coldStartTranscript,
          activeLens: activeLens,
        );
        imported += audioResult.imported;
        failed += audioResult.failed;
        coldStartInsight ??= audioResult.insight;
      } on ApiException {
        failed += 1;
      }
      processed += 1;
      emit(
        BacklogImportProgress(
          phase: BacklogImportPhase.processing,
          totalChunks: total,
          processedChunks: processed,
          importedCount: imported,
          failedCount: failed,
          insight: coldStartInsight,
          statusMessage: coldStartInsight != null
              ? 'Your first insight is ready.'
              : 'Processing audio ($processed of $total)…',
        ),
      );
    }

    final complete = BacklogImportProgress(
      phase: BacklogImportPhase.complete,
      totalChunks: total,
      processedChunks: total,
      importedCount: imported,
      failedCount: failed,
      insight: coldStartInsight,
      statusMessage: coldStartInsight != null
          ? 'Imported $imported ${imported == 1 ? 'entry' : 'entries'} — insight ready.'
          : imported == 0
          ? 'No entries could be imported.'
          : 'Imported $imported ${imported == 1 ? 'entry' : 'entries'}.',
    );
    emit(complete);
    return complete;
  }

  Future<
    ({
      int imported,
      int failed,
      BacklogImportInsight? insight,
    })
  >
  _uploadTextBatch(
    List<BacklogImportChunk> batch, {
    bool finalizeColdStart = false,
    String? coldStartTranscript,
    String? activeLens,
  }) async {
    final result = await _transport.post(
      VoiceMemoryApiRoutes.ledgerBulkImport.path,
      body: {
        'chunks': batch
            .map(
              (chunk) => {
                'entryId': chunk.entryId,
                'rawText': chunk.rawText,
                if (chunk.createdAt != null)
                  'createdAt': chunk.createdAt!.toUtc().toIso8601String(),
                'sourceFile': chunk.sourceFile,
              },
            )
            .toList(growable: false),
        if (finalizeColdStart) 'finalizeColdStart': true,
        if (finalizeColdStart && coldStartTranscript != null)
          'coldStartTranscript': coldStartTranscript,
        if (finalizeColdStart && activeLens != null && activeLens.isNotEmpty)
          'activeLens': activeLens,
      },
    );

    return result.when(
      success: _decodeBulkImportResponse,
      onFailure: (failure) => throw failure.toApiException(),
    );
  }

  Future<
    ({
      int imported,
      int failed,
      BacklogImportInsight? insight,
    })
  >
  _uploadAudioChunk(
    BacklogImportChunk chunk, {
    bool finalizeColdStart = false,
    String? coldStartTranscript,
    String? activeLens,
  }) async {
    final path = chunk.audioPath;
    if (path == null || path.isEmpty) {
      return (imported: 0, failed: 1, insight: null);
    }

    final result = await _transport.postMultipart(
      VoiceMemoryApiRoutes.ledgerBulkImport.path,
      fields: {
        'entryId': chunk.entryId,
        'sourceFile': chunk.sourceFile,
        if (chunk.createdAt != null)
          'createdAt': chunk.createdAt!.toUtc().toIso8601String(),
        if (finalizeColdStart) 'finalizeColdStart': 'true',
        if (finalizeColdStart && coldStartTranscript != null)
          'coldStartTranscript': coldStartTranscript,
        if (finalizeColdStart && activeLens != null && activeLens.isNotEmpty)
          'activeLens': activeLens,
      },
      files: [
        MultipartFilePart.fromPath(
          field: 'audio',
          path: path,
          filename: chunk.sourceFile,
        ),
      ],
    );

    return result.when(
      success: _decodeBulkImportResponse,
      onFailure: (failure) => throw failure.toApiException(),
    );
  }

  ({
    int imported,
    int failed,
    BacklogImportInsight? insight,
  })
  _decodeBulkImportResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiFailureMapper.fromResponse(response).toApiException();
    }
    return _transport
        .decodeEnvelope(
          response,
          parseData: LedgerBulkImportResponseDto.fromJson,
          toDomain: _mapBulkImportResult,
          missingDataMessage: 'Bulk import failed',
        )
        .when(
          success: (value) => value,
          onFailure: (failure) => throw failure.toApiException(),
        );
  }

  ({
    int imported,
    int failed,
    BacklogImportInsight? insight,
  })
  _mapBulkImportResult(LedgerBulkImportResponseDto dto) {
    final insight = dto.insight;
    return (
      imported: dto.imported,
      failed: dto.failed,
      insight: insight == null
          ? null
          : BacklogImportInsight.fromJson(insight.toJson()),
    );
  }

  String? _latestChunkText(List<BacklogImportChunk> chunks) {
    final textChunks = chunks
        .where(
          (chunk) =>
              chunk.kind == BacklogImportChunkKind.text &&
              (chunk.rawText?.trim().isNotEmpty ?? false),
        )
        .toList(growable: false);
    if (textChunks.isEmpty) return null;

    textChunks.sort((left, right) {
      final leftDate =
          left.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final rightDate =
          right.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return rightDate.compareTo(leftDate);
    });
    return textChunks.first.rawText?.trim();
  }

  String? _readTextContent(PlatformFile file) {
    if (file.bytes != null) {
      return utf8.decode(file.bytes!);
    }
    final path = file.path;
    if (path == null || path.isEmpty) return null;
    return File(path).readAsStringSync();
  }

  String? _extensionFor(String filename) {
    final dot = filename.lastIndexOf('.');
    if (dot < 0 || dot == filename.length - 1) return null;
    final extension = filename.substring(dot + 1).toLowerCase();
    return _supportedExtensions.contains(extension) ? extension : null;
  }
}

/// Parses Apple Notes CSV exports into discrete ledger chunks.
List<BacklogImportChunk> parseAppleNotesCsv(
  String content, {
  required String sourceFile,
}) {
  final rows = _parseCsvRows(content);
  if (rows.isEmpty) return const [];

  final header = rows.first.map((cell) => cell.trim().toLowerCase()).toList();
  final hasHeader = _looksLikeHeaderRow(header);
  final dataRows = hasHeader ? rows.skip(1) : rows;

  final titleIndex = _columnIndex(header, const ['title', 'name']);
  final bodyIndex = _columnIndex(header, const [
    'body',
    'content',
    'note',
    'text',
    'note text',
  ]);
  final createdIndex = _columnIndex(header, const [
    'created',
    'creation date',
    'date created',
    'creation',
    'date',
  ]);

  final chunks = <BacklogImportChunk>[];
  for (final row in dataRows) {
    if (row.isEmpty) continue;

    final body = bodyIndex != null && bodyIndex < row.length
        ? row[bodyIndex].trim()
        : row.length > 1
        ? row.last.trim()
        : row.first.trim();
    if (body.isEmpty) continue;

    final title = titleIndex != null && titleIndex < row.length
        ? row[titleIndex].trim()
        : '';
    final rawText = title.isEmpty ? body : '$title\n\n$body';

    final createdRaw = createdIndex != null && createdIndex < row.length
        ? row[createdIndex].trim()
        : null;

    chunks.add(
      BacklogImportChunk(
        entryId: _uuid.v4(),
        sourceFile: sourceFile,
        kind: BacklogImportChunkKind.text,
        rawText: rawText,
        createdAt: _parseFlexibleDate(createdRaw),
      ),
    );
  }

  if (chunks.isEmpty && !hasHeader) {
    return parseRawTextDump(content, sourceFile: sourceFile);
  }
  return chunks;
}

/// Parses raw text dumps using timestamps or paragraph breaks.
List<BacklogImportChunk> parseRawTextDump(
  String content, {
  required String sourceFile,
}) {
  final normalized = content.replaceAll('\r\n', '\n').trim();
  if (normalized.isEmpty) return const [];

  final timestampSections = _splitOnTimestampHeaders(normalized);
  if (timestampSections.length > 1) {
    return timestampSections
        .map(
          (section) => BacklogImportChunk(
            entryId: _uuid.v4(),
            sourceFile: sourceFile,
            kind: BacklogImportChunkKind.text,
            rawText: section.text.trim(),
            createdAt: section.createdAt,
          ),
        )
        .where((chunk) => chunk.rawText?.isNotEmpty ?? false)
        .toList(growable: false);
  }

  final paragraphs = normalized
      .split(RegExp(r'\n{2,}'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);

  if (paragraphs.length <= 1) {
    return [
      BacklogImportChunk(
        entryId: _uuid.v4(),
        sourceFile: sourceFile,
        kind: BacklogImportChunkKind.text,
        rawText: normalized,
      ),
    ];
  }

  return paragraphs
      .map(
        (paragraph) => BacklogImportChunk(
          entryId: _uuid.v4(),
          sourceFile: sourceFile,
          kind: BacklogImportChunkKind.text,
          rawText: paragraph,
          createdAt: _parseLeadingTimestamp(paragraph),
        ),
      )
      .toList(growable: false);
}

class _TimestampSection {
  const _TimestampSection({required this.text, this.createdAt});

  final String text;
  final DateTime? createdAt;
}

List<_TimestampSection> _splitOnTimestampHeaders(String content) {
  final lines = content.split('\n');
  final sections = <_TimestampSection>[];
  final buffer = <String>[];
  DateTime? currentDate;

  void flush() {
    final text = buffer.join('\n').trim();
    if (text.isNotEmpty) {
      sections.add(_TimestampSection(text: text, createdAt: currentDate));
    }
    buffer.clear();
  }

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      if (buffer.isNotEmpty) buffer.add('');
      continue;
    }

    final maybeDate = _parseFlexibleDate(trimmed);
    if (maybeDate != null && trimmed.length <= 40) {
      flush();
      currentDate = maybeDate;
      continue;
    }

    buffer.add(trimmed);
  }

  flush();
  return sections;
}

DateTime? _parseLeadingTimestamp(String text) {
  final firstLine = text.split('\n').first.trim();
  return _parseFlexibleDate(firstLine);
}

DateTime? _parseFlexibleDate(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final value = raw.trim();

  final appleAt = RegExp(
    r'^([A-Za-z]{3,9} \d{1,2}, \d{4}) at (\d{1,2}:\d{2}(?: ?[AP]M)?)$',
    caseSensitive: false,
  ).firstMatch(value);
  if (appleAt != null) {
    final combined = '${appleAt.group(1)} ${appleAt.group(2)}';
    final parsed = DateTime.tryParse(combined);
    if (parsed != null) return parsed;
  }

  final direct = DateTime.tryParse(value);
  if (direct != null) return direct;

  final parsed = DateTime.tryParse(value.replaceAll(' at ', ' '));
  return parsed;
}

bool _looksLikeHeaderRow(List<String> header) {
  if (header.isEmpty) return false;
  return header.any(
    (cell) =>
        cell.contains('title') ||
        cell.contains('body') ||
        cell.contains('content') ||
        cell.contains('created') ||
        cell.contains('date'),
  );
}

int? _columnIndex(List<String> header, List<String> candidates) {
  for (var index = 0; index < header.length; index++) {
    final cell = header[index];
    for (final candidate in candidates) {
      if (cell == candidate || cell.contains(candidate)) {
        return index;
      }
    }
  }
  return null;
}

List<List<String>> _parseCsvRows(String content) {
  final rows = <List<String>>[];
  final row = <String>[];
  final buffer = StringBuffer();
  var inQuotes = false;

  for (var index = 0; index < content.length; index++) {
    final char = content[index];
    if (char == '"') {
      final isEscapedQuote =
          inQuotes && index + 1 < content.length && content[index + 1] == '"';
      if (isEscapedQuote) {
        buffer.write('"');
        index += 1;
      } else {
        inQuotes = !inQuotes;
      }
      continue;
    }

    if (char == ',' && !inQuotes) {
      row.add(buffer.toString());
      buffer.clear();
      continue;
    }

    if ((char == '\n' || char == '\r') && !inQuotes) {
      if (char == '\r' && index + 1 < content.length && content[index + 1] == '\n') {
        index += 1;
      }
      row.add(buffer.toString());
      buffer.clear();
      if (row.any((cell) => cell.trim().isNotEmpty)) {
        rows.add(List<String>.from(row));
      }
      row.clear();
      continue;
    }

    buffer.write(char);
  }

  row.add(buffer.toString());
  if (row.any((cell) => cell.trim().isNotEmpty)) {
    rows.add(row);
  }
  return rows;
}