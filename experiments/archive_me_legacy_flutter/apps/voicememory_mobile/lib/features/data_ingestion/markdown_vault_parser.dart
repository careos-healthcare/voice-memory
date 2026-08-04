import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

import 'markdown_vault_models.dart';

typedef MarkdownParseProgressCallback =
    void Function(MarkdownVaultParseProgress progress);

final class MarkdownVaultParser {
  const MarkdownVaultParser({this.maximumFileBytes = 10 * 1024 * 1024});

  final int maximumFileBytes;

  Future<List<ParsedMarkdownNote>> parseDirectory(
    Directory root, {
    MarkdownParseProgressCallback? onProgress,
  }) async {
    if (!await root.exists()) {
      throw ArgumentError.value(root.path, 'root', 'Directory does not exist.');
    }
    final files = <File>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final extension = path.extension(entity.path).toLowerCase();
      if (extension == '.md' || extension == '.markdown') files.add(entity);
    }
    files.sort((left, right) => left.path.compareTo(right.path));
    final watch = Stopwatch()..start();
    final notes = <ParsedMarkdownNote>[];
    for (final file in files) {
      if (await file.length() > maximumFileBytes) continue;
      final relativePath = path
          .relative(file.path, from: root.path)
          .replaceAll('\\', '/');
      final markdown = utf8.decode(
        await file.readAsBytes(),
        allowMalformed: false,
      );
      notes.add(parseText(markdown, relativePath: relativePath));
      onProgress?.call(
        MarkdownVaultParseProgress(
          discoveredFiles: files.length,
          parsedFiles: notes.length,
          elapsed: watch.elapsed,
          currentPath: relativePath,
        ),
      );
      if (notes.length % 50 == 0) await Future<void>.delayed(Duration.zero);
    }
    return List.unmodifiable(notes);
  }

  ParsedMarkdownNote parseText(String source, {required String relativePath}) {
    final markdown = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final parsed = _parseFrontmatter(markdown);
    final filename = path.basenameWithoutExtension(relativePath);
    final title = (_scalar(parsed.values['title']) ?? filename).trim();
    if (title.isEmpty) {
      throw const FormatException('Markdown note title cannot be empty.');
    }
    final normalizedTitle = _normalize(title);
    final titleHash = _sha256(normalizedTitle);
    final contentHash = _sha256(parsed.body.trim());
    return ParsedMarkdownNote(
      id: 'legacy_note_${titleHash.substring(0, 24)}',
      relativePath: relativePath,
      title: title,
      markdown: markdown,
      body: parsed.body,
      tags: _stringList(parsed.values['tags'] ?? parsed.values['tag']),
      aliases: _stringList(parsed.values['aliases'] ?? parsed.values['alias']),
      links: _extractLinks(parsed.body),
      createdAt: _date(
        parsed.values['created'] ??
            parsed.values['creation date'] ??
            parsed.values['created_at'] ??
            parsed.values['date'],
      ),
      titleHash: titleHash,
      contentHash: contentHash,
    );
  }

  static ({Map<String, Object> values, String body}) _parseFrontmatter(
    String markdown,
  ) {
    if (!markdown.startsWith('---\n')) {
      return (values: const {}, body: markdown);
    }
    final lines = markdown.split('\n');
    var closing = -1;
    for (var index = 1; index < lines.length; index++) {
      if (lines[index].trim() == '---') {
        closing = index;
        break;
      }
    }
    if (closing < 0) return (values: const {}, body: markdown);
    final values = <String, Object>{};
    String? activeList;
    for (final raw in lines.sublist(1, closing)) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      if (trimmed.startsWith('-') && activeList != null) {
        final list = values.putIfAbsent(activeList, () => <String>[]);
        if (list is List<String>) {
          final value = _unquote(trimmed.substring(1).trim());
          if (value.isNotEmpty) list.add(value);
        }
        continue;
      }
      final separator = raw.indexOf(':');
      if (separator <= 0) {
        activeList = null;
        continue;
      }
      final key = raw.substring(0, separator).trim().toLowerCase();
      final value = raw.substring(separator + 1).trim();
      activeList = value.isEmpty ? key : null;
      values[key] = value.isEmpty ? <String>[] : value;
    }
    return (
      values: Map.unmodifiable(values),
      body: lines.skip(closing + 1).join('\n'),
    );
  }

  static List<MarkdownWikiLink> _extractLinks(String body) {
    final links = <MarkdownWikiLink>[];
    final seen = <String>{};
    for (final match in RegExp(r'(?<!!)\[\[([^\[\]]+)\]\]').allMatches(body)) {
      final value = match.group(1)!.split('|');
      final target = _cleanLinkTarget(value.first);
      if (target.isEmpty || !seen.add(_normalize(target))) continue;
      links.add(
        MarkdownWikiLink(
          target: target,
          alias: value.length > 1 ? value.sublist(1).join('|') : null,
        ),
      );
    }
    for (final match in RegExp(
      r'\[([^\]]+)\]\(([^)]+\.md(?:#[^)]*)?)\)',
    ).allMatches(body)) {
      final rawTarget = Uri.decodeComponent(match.group(2)!);
      final target = _cleanLinkTarget(path.basename(rawTarget));
      if (target.isEmpty || !seen.add(_normalize(target))) continue;
      links.add(MarkdownWikiLink(target: target, alias: match.group(1)));
    }
    return List.unmodifiable(links);
  }

  static String _cleanLinkTarget(String value) {
    var target = value.trim();
    final fragment = target.indexOf(RegExp(r'[#^]'));
    if (fragment >= 0) target = target.substring(0, fragment);
    target = target.replaceFirst(RegExp(r'\.md$', caseSensitive: false), '');
    return target.trim();
  }

  static List<String> _stringList(Object? value) {
    if (value is List) {
      return value
          .map((item) => _unquote('$item').trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    final scalar = _scalar(value);
    if (scalar == null || scalar.isEmpty) return const [];
    final inner = scalar.startsWith('[') && scalar.endsWith(']')
        ? scalar.substring(1, scalar.length - 1)
        : scalar;
    return inner
        .split(RegExp(r'[,;]'))
        .map((item) => _unquote(item.trim()))
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static String? _scalar(Object? value) =>
      value == null ? null : _unquote('$value');

  static DateTime? _date(Object? value) {
    final scalar = _scalar(value);
    if (scalar == null) return null;
    return DateTime.tryParse(scalar)?.toUtc();
  }

  static String _unquote(String value) {
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }

  static String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static String _sha256(String value) =>
      sha256.convert(utf8.encode(value)).toString();
}
