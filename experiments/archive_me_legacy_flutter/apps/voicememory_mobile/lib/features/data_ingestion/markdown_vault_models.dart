import 'dart:collection';
import 'dart:typed_data';

final class MarkdownWikiLink {
  MarkdownWikiLink({required String target, String? alias})
    : target = target.trim(),
      alias = alias?.trim();

  final String target;
  final String? alias;
}

final class ParsedMarkdownNote {
  ParsedMarkdownNote({
    required this.id,
    required this.relativePath,
    required String title,
    required this.markdown,
    required this.body,
    required Iterable<String> tags,
    required Iterable<String> aliases,
    required Iterable<MarkdownWikiLink> links,
    required this.createdAt,
    required this.titleHash,
    required this.contentHash,
  }) : title = title.trim(),
       tags = UnmodifiableListView(tags.toSet().toList()..sort()),
       aliases = UnmodifiableListView(aliases.toSet().toList()..sort()),
       links = UnmodifiableListView(links);

  final String id;
  final String relativePath;
  final String title;
  final String markdown;
  final String body;
  final List<String> tags;
  final List<String> aliases;
  final List<MarkdownWikiLink> links;
  final DateTime? createdAt;
  final String titleHash;
  final String contentHash;
}

final class MarkdownChunk {
  const MarkdownChunk({
    required this.index,
    required this.text,
    required this.start,
    required this.end,
  });

  final int index;
  final String text;
  final int start;
  final int end;
}

final class EmbeddedMarkdownChunk {
  EmbeddedMarkdownChunk({
    required this.noteId,
    required this.chunk,
    required Float32List embedding,
  }) : embedding = Float32List.fromList(embedding);

  final String noteId;
  final MarkdownChunk chunk;
  final Float32List embedding;
}

final class MarkdownVaultParseProgress {
  const MarkdownVaultParseProgress({
    required this.discoveredFiles,
    required this.parsedFiles,
    required this.elapsed,
    required this.currentPath,
  });

  final int discoveredFiles;
  final int parsedFiles;
  final Duration elapsed;
  final String currentPath;

  double get filesPerSecond => elapsed.inMilliseconds <= 0
      ? 0
      : parsedFiles * 1000 / elapsed.inMilliseconds;
}
