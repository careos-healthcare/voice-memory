import 'dart:io';

import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/obsidian_markdown_template.dart';
import 'package:archiveme_mobile/services/obsidian_vault_diff.dart';
import 'package:file_picker/file_picker.dart';

/// Surroundings written into Obsidian frontmatter when they were captured.
class MarkdownAmbient {
  const MarkdownAmbient({
    this.locality,
    this.weather,
    this.steps,
    this.calendar,
  });

  final String? locality;
  final String? weather;
  final int? steps;
  final String? calendar;

  bool get isEmpty =>
      (locality == null || locality!.trim().isEmpty) &&
      (weather == null || weather!.trim().isEmpty) &&
      steps == null &&
      (calendar == null || calendar!.trim().isEmpty);
}

/// One journal entry rendered as an Obsidian note.
class MarkdownNote {
  const MarkdownNote({
    required this.id,
    required this.createdAt,
    required this.body,
    required this.mood,
    required this.tags,
    this.ambient = const MarkdownAmbient(),
    this.patterns = const [],
  });

  factory MarkdownNote.fromEntry(JournalEntry entry) {
    final themes = entry.reflection.recurringThemes
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
    return MarkdownNote(
      id: entry.id,
      createdAt: entry.createdAt,
      body: entry.transcript,
      mood: entry.reflection.mood.trim().isEmpty
          ? 'unspecified'
          : entry.reflection.mood.trim(),
      tags: ['journal', ...themes],
      patterns: themes,
      ambient: ambientFromDisplayJson(entry.display.toJson()),
    );
  }

  final String id;
  final DateTime createdAt;
  final String body;
  final String mood;
  final List<String> tags;
  final MarkdownAmbient ambient;
  final List<String> patterns;

  String get fileName {
    final day = _isoDay(createdAt);
    final safeId = id.replaceAll(RegExp('[^A-Za-z0-9_-]'), '');
    return '$day-$safeId.md';
  }
}

/// Remembers the vault folder chosen for continuous export.
abstract class MarkdownVaultStore {
  Future<String?> readPath();

  Future<void> writePath(String path);
}

class MemoryMarkdownVaultStore implements MarkdownVaultStore {
  String? path;

  @override
  Future<String?> readPath() async => path;

  @override
  Future<void> writePath(String path) async {
    this.path = path;
  }
}

/// A note that was written into the vault.
class MarkdownWrittenFile {
  const MarkdownWrittenFile({required this.path, required this.contents});

  final String path;
  final String contents;
}

/// Opens the system folder picker. Tests pass their own picker instead.
Future<String?> pickMarkdownVaultDirectory() {
  return FilePicker.platform.getDirectoryPath();
}

Future<void> writeMarkdownFile(String path, String contents) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsString(contents, flush: true);
}

/// Writes journal entries as Obsidian notes with Dataview frontmatter.
class MarkdownExportService {
  MarkdownExportService({
    Future<String?> Function()? pickDirectory,
    MarkdownVaultStore? vault,
    Future<void> Function(String path, String contents)? writeFile,
    Future<String?> Function(String path)? readFile,
    this.template,
  }) : _pick = pickDirectory ?? pickMarkdownVaultDirectory,
       _vault = vault ?? MemoryMarkdownVaultStore(),
       _write = writeFile ?? writeMarkdownFile,
       _read = readFile ?? _readMarkdownFile;

  final Future<String?> Function() _pick;
  final MarkdownVaultStore _vault;
  final Future<void> Function(String path, String contents) _write;
  final Future<String?> Function(String path) _read;
  final ObsidianMarkdownTemplate? template;
  final Map<String, String> _lastPushedHash = {};

  /// Asks for a vault folder and remembers it for later syncs.
  Future<String?> chooseVault() async {
    final picked = await _pick();
    if (picked == null || picked.trim().isEmpty) return null;
    final path = picked.trim();
    await _vault.writePath(path);
    return path;
  }

  /// Rewrites one note per entry in the remembered vault.
  Stream<MarkdownWrittenFile> syncStream(List<JournalEntry> entries) async* {
    final directory = await _vault.readPath();
    if (directory == null || directory.trim().isEmpty) return;
    for (final entry in entries) {
      final note = MarkdownNote.fromEntry(entry);
      final path = _join(directory.trim(), note.fileName);
      final contents = renderNote(note);
      final vaultMarkdown = await _read(path);
      final decision = ObsidianVaultDiff.resolve(
        localMarkdown: contents,
        vaultMarkdown: vaultMarkdown,
        lastPushedHash: _lastPushedHash[note.id],
      );
      if (decision != ObsidianVaultPush.write) continue;
      await _write(path, contents);
      _lastPushedHash[note.id] = ObsidianVaultDiff.hashOf(contents);
      yield MarkdownWrittenFile(path: path, contents: contents);
    }
  }

  Future<int> sync(List<JournalEntry> entries) async {
    var count = 0;
    await for (final _ in syncStream(entries)) {
      count += 1;
    }
    return count;
  }

  /// Uses the user template when one is set, otherwise the Dataview layout.
  String renderNote(MarkdownNote note) {
    final layout = template;
    if (layout == null) return renderMarkdownNote(note);
    return layout.render(ObsidianTemplateValues.fromNote(note));
  }
}

Future<String?> _readMarkdownFile(String path) async {
  final file = File(path);
  if (!file.existsSync()) return null;
  return file.readAsString();
}

/// YAML frontmatter plus the transcript. Dataview can read every field.
String renderMarkdownNote(MarkdownNote note) {
  final tags = note.tags.where((tag) => tag.trim().isNotEmpty).toList();
  final buffer = StringBuffer()
    ..writeln('---')
    ..writeln('date: ${_isoDay(note.createdAt)}')
    ..writeln('tags:');
  for (final tag in tags.isEmpty ? const ['journal'] : tags) {
    buffer.writeln('  - ${_yamlScalar(tag)}');
  }
  buffer.writeln('mood: ${_yamlScalar(note.mood)}');
  final ambient = note.ambient;
  if (ambient.locality != null && ambient.locality!.trim().isNotEmpty) {
    buffer.writeln(
      'ambient_locality: ${_yamlScalar(ambient.locality!.trim())}',
    );
  }
  if (ambient.weather != null && ambient.weather!.trim().isNotEmpty) {
    buffer.writeln('ambient_weather: ${_yamlScalar(ambient.weather!.trim())}');
  }
  if (ambient.steps != null) {
    buffer.writeln('ambient_steps: ${ambient.steps}');
  }
  if (ambient.calendar != null && ambient.calendar!.trim().isNotEmpty) {
    buffer.writeln(
      'ambient_calendar: ${_yamlScalar(ambient.calendar!.trim())}',
    );
  }
  buffer
    ..writeln('---')
    ..writeln()
    ..writeln(note.body.trim());
  return buffer.toString();
}

MarkdownAmbient ambientFromDisplayJson(Map<String, dynamic> displayJson) {
  final raw = displayJson['ambientContext'];
  if (raw is! Map) return const MarkdownAmbient();
  final steps = raw['stepCount'];
  return MarkdownAmbient(
    locality: _optional(raw['locality']),
    weather: _optional(raw['weatherLabel']),
    steps: steps is num ? steps.round() : int.tryParse('$steps'),
    calendar: _optional(raw['calendarTitle']),
  );
}

String? _optional(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _isoDay(DateTime when) {
  final utc = when.toUtc();
  final month = utc.month.toString().padLeft(2, '0');
  final day = utc.day.toString().padLeft(2, '0');
  return '${utc.year}-$month-$day';
}

String _yamlScalar(String value) {
  if (value.isEmpty) return '""';
  final needsQuote = RegExp(
    r'''[:#\[\]{}&*!|>'"%@`]|^\s|\s$|\n''',
  ).hasMatch(value);
  if (!needsQuote) return value;
  final escaped = value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  return '"$escaped"';
}

String _join(String directory, String fileName) {
  if (directory.endsWith('/') || directory.endsWith(r'\')) {
    return '$directory$fileName';
  }
  return '$directory/$fileName';
}
