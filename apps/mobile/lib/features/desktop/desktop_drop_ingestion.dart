import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archiveme_mobile/features/attachments/local_ocr_processor.dart';
import 'package:archiveme_mobile/features/search/entity_extraction_worker.dart';
import 'package:archiveme_mobile/features/wearable/wearable_ingestion_worker.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_023_attachment_text.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

/// Files the desktop window accepts onto a new moment.
enum DesktopDropKind { audio, image, pdf, ignored }

/// One file dropped on the window.
class DesktopDroppedFile {
  const DesktopDroppedFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// A moment created from a dropped file.
class DesktopIngestedMoment {
  const DesktopIngestedMoment({
    required this.entryId,
    required this.kind,
    required this.transcript,
    required this.entityIds,
  });

  final String entryId;
  final DesktopDropKind kind;
  final String transcript;
  final List<String> entityIds;
}

/// Maps a file name to audio, a picture, a PDF, or an ignored type.
DesktopDropKind classifyDesktopDrop(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.mp3') || lower.endsWith('.wav')) {
    return DesktopDropKind.audio;
  }
  if (lower.endsWith('.png')) return DesktopDropKind.image;
  if (lower.endsWith('.pdf')) return DesktopDropKind.pdf;
  return DesktopDropKind.ignored;
}

/// Pulls literal strings out of a PDF body.
String extractPdfLiteralText(Uint8List bytes) {
  final raw = latin1.decode(bytes, allowInvalid: true);
  final buffer = StringBuffer();
  final pattern = RegExp(r'\(((?:\\\)|\\.|[^)\\])*)\)');
  for (final match in pattern.allMatches(raw)) {
    final piece = (match.group(1) ?? '')
        .replaceAll(r'\(', '(')
        .replaceAll(r'\)', ')')
        .replaceAll(r'\n', ' ')
        .trim();
    if (piece.isEmpty) continue;
    if (buffer.isNotEmpty) buffer.write(' ');
    buffer.write(piece);
  }
  return buffer.toString();
}

Future<OcrDocument> _emptyOcr(Uint8List bytes) async => OcrDocument.empty;

/// Transcribes a dropped WAV when a local model is installed.
Future<String> transcribeDroppedAudio(Uint8List bytes, String name) {
  if (!name.toLowerCase().endsWith('.wav')) return Future<String>.value('');
  return WearableSherpaTranscriber().transcribeBytes(bytes);
}

/// Creates moments from dropped audio, pictures, and PDFs.
class DesktopFileIngestion {
  DesktopFileIngestion({
    LocalOcrProcessor? ocr,
    this.transcribe = transcribeDroppedAudio,
    this.readPdf = extractPdfLiteralText,
    this.entities = const EntityExtractionWorker(),
    DateTime Function()? clock,
  }) : ocr = ocr ?? const LocalOcrProcessor(recognize: _emptyOcr),
       _clock = clock ?? DateTime.now;

  final LocalOcrProcessor ocr;
  final Future<String> Function(Uint8List bytes, String name) transcribe;
  final String Function(Uint8List bytes) readPdf;
  final EntityExtractionWorker entities;
  final DateTime Function() _clock;
  var _sequence = 0;

  Future<List<DesktopIngestedMoment>> ingest({
    required DatabaseExecutor database,
    required List<DesktopDroppedFile> files,
  }) async {
    final created = <DesktopIngestedMoment>[];
    for (final file in files) {
      final kind = classifyDesktopDrop(file.name);
      if (kind == DesktopDropKind.ignored) continue;
      final text = await _textFor(file, kind);
      final transcript = text.trim().isEmpty ? file.name : text.trim();
      final entryId = _nextId();
      final now = _clock().millisecondsSinceEpoch;
      await database.insert('journal_entries', {
        'id': entryId,
        'created_at': now,
        'updated_at': now,
        'is_archived': 0,
        'transcript': transcript,
        'has_verified_proof': 0,
        'payload_json': jsonEncode({
          'source': 'desktop_drop',
          'file': file.name,
          'kind': kind.name,
        }),
      });
      if (text.trim().isNotEmpty) {
        await _storeAttachmentText(database, entryId, text.trim());
      }
      final extraction = await entities.processEntry(
        db: database,
        entryId: entryId,
        transcript: transcript,
        seenAt: _clock(),
      );
      created.add(
        DesktopIngestedMoment(
          entryId: entryId,
          kind: kind,
          transcript: transcript,
          entityIds: extraction.entityIds,
        ),
      );
    }
    return created;
  }

  Future<String> _textFor(DesktopDroppedFile file, DesktopDropKind kind) {
    switch (kind) {
      case DesktopDropKind.audio:
        return transcribe(file.bytes, file.name);
      case DesktopDropKind.image:
        return ocr.processBytes(file.bytes).then((document) => document.text);
      case DesktopDropKind.pdf:
        return Future<String>.value(readPdf(file.bytes));
      case DesktopDropKind.ignored:
        return Future<String>.value('');
    }
  }

  Future<void> _storeAttachmentText(
    DatabaseExecutor database,
    String entryId,
    String text,
  ) async {
    final columns = await database.rawQuery(
      'PRAGMA table_info(journal_entries)',
    );
    final present = columns.any(
      (row) => row['name'] == Migration023AttachmentText.column,
    );
    if (!present) return;
    await database.update(
      'journal_entries',
      {Migration023AttachmentText.column: text},
      where: 'id = ?',
      whereArgs: [entryId],
    );
  }

  String _nextId() {
    _sequence += 1;
    return 'drop-${_clock().microsecondsSinceEpoch}-$_sequence';
  }
}

/// True on desktop hosts. Widget tests leave the plugin disabled.
bool desktopDropPluginEnabled({bool? override}) {
  if (override != null) return override;
  if (Platform.environment['FLUTTER_TEST'] == 'true') return false;
  if (kIsWeb) return true;
  return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
}

/// Accepts audio, pictures, and PDFs dropped on the window.
class DesktopDropIngestion extends StatelessWidget {
  const DesktopDropIngestion({
    required this.child,
    required this.onFiles,
    super.key,
    this.enablePlugin,
  });

  final Widget child;
  final Future<void> Function(List<DesktopDroppedFile> files) onFiles;
  final bool? enablePlugin;

  @override
  Widget build(BuildContext context) {
    if (!desktopDropPluginEnabled(override: enablePlugin)) return child;
    return DropTarget(
      onDragDone: (detail) {
        unawaited(_deliver(detail.files));
      },
      child: child,
    );
  }

  Future<void> _deliver(List<DropItem> files) async {
    final dropped = <DesktopDroppedFile>[];
    for (final file in files) {
      if (classifyDesktopDrop(file.name) == DesktopDropKind.ignored) continue;
      try {
        dropped.add(
          DesktopDroppedFile(name: file.name, bytes: await file.readAsBytes()),
        );
      } on Object catch (error) {
        error.runtimeType;
      }
    }
    if (dropped.isEmpty) return;
    await onFiles(dropped);
  }
}
