import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archiveme_mobile/security/export_pdf_renderer.dart';
import 'package:archiveme_mobile/security/private_data_service.dart';
import 'package:flutter_test/flutter_test.dart';

ArchiveExportPayload _payload({
  List<Map<String, dynamic>> entries = const [],
  List<Map<String, String>> notes = const [],
}) {
  return ArchiveExportPayload(
    entries: entries,
    exportedAt: DateTime.utc(2026, 9, 20),
    insightCorrectionNotes: notes,
  );
}

/// Inflates FlateDecode streams so tests can assert on drawn text.
String _pdfWords(Uint8List bytes) {
  final raw = latin1.decode(bytes);
  final buffer = StringBuffer(raw);
  final streamPattern = RegExp(r'stream\r?\n([\s\S]*?)\r?\nendstream');
  for (final match in streamPattern.allMatches(raw)) {
    try {
      final inflated = zlib.decode(latin1.encode(match.group(1)!));
      buffer.write(latin1.decode(inflated, allowInvalid: true));
    } on FormatException {
      // Non-deflate streams (xref) are ignored.
    }
  }
  return RegExp(r'\[\((.*?)\)\]TJ')
      .allMatches(buffer.toString())
      .map((match) => match.group(1)!)
      .join(' ');
}

void main() {
  test('empty archive still produces a valid PDF', () async {
    final bytes = await ExportPdfRenderer.render(_payload());
    expect(latin1.decode(bytes.take(5).toList()), '%PDF-');
    final text = _pdfWords(bytes);
    expect(text, contains('Thoughtprint'));
    expect(text, contains('Journal export'));
    expect(text, contains('No reflections in this export.'));
    expect(text, isNot(contains('VoiceMemory')));
  });

  test('renders sanitized entry text and skips unread mood', () async {
    final bytes = await ExportPdfRenderer.render(
      _payload(
        entries: [
          {
            'createdAt': '2026-06-03T00:00:00.000Z',
            'transcript': 'My reflection about quiet time',
            'durationSeconds': 5,
            'reflection': {
              'recurringThemes': <String>[],
              'exactLanguagePattern': '',
              'concreteObservation': 'You sounded tired.',
              'repeatedSignal': '',
            },
          },
        ],
      ),
    );
    final text = _pdfWords(bytes);
    expect(text, contains('My reflection about quiet time'));
    expect(text, contains('You sounded tired.'));
    expect(text, isNot(contains('neutral')));
    expect(text, isNot(contains('secret-id')));
    expect(text, isNot(contains('/tmp/secret.m4a')));
    expect(text, isNot(contains('VoiceMemory')));
  });

  test('includes mood, intensity, themes, and correction notes', () async {
    final bytes = await ExportPdfRenderer.render(
      _payload(
        entries: [
          {
            'createdAt': '2026-06-03T00:00:00.000Z',
            'transcript': 'A harder day at work',
            'durationSeconds': 12,
            'reflection': {
              'mood': 'anxious',
              'emotionalIntensity': 7,
              'recurringThemes': ['work', 'sleep'],
              'exactLanguagePattern': 'I need quiet',
              'concreteObservation': 'Meetings ran late again.',
              'repeatedSignal': 'Quiet mentioned twice.',
            },
          },
        ],
        notes: [
          {
            'label': 'Weekly review insight correction',
            'note': 'This was about capacity, not failure.',
          },
        ],
      ),
    );
    final text = _pdfWords(bytes);
    expect(text, contains('anxious'));
    expect(text, contains('work'));
    expect(text, contains('Meetings ran late again.'));
    expect(text, contains('This was about capacity, not failure.'));
  });

  test('uses the /export PDF filename', () {
    expect(ExportPdfRenderer.fileName, 'thoughtprint_export.pdf');
  });
}
