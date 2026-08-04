import 'dart:collection';

enum CodexPublicationTemplate {
  minimalistJournal('Minimalist Journal'),
  academicMonograph('Academic Monograph'),
  cinematicMemoir('Cinematic Memoir'),
  cyberpunkChronicle('Cyberpunk Chronicle');

  const CodexPublicationTemplate(this.label);
  final String label;
}

enum CodexOrganization { chronological, thematic }

enum CodexSourceKind { journal, audioTranscript, graphNode, semanticCluster }

enum CodexExportFormat { codex, pdf, epub, offlineHtml }

final class CodexSourceOption {
  CodexSourceOption({
    required this.id,
    required this.kind,
    required DateTime occurredAt,
    required String label,
  }) : occurredAt = occurredAt.toUtc(),
       label = label.trim();

  final String id;
  final CodexSourceKind kind;
  final DateTime occurredAt;
  final String label;
}

final class CodexCitation {
  CodexCitation({
    required this.sourceId,
    required this.kind,
    required DateTime occurredAt,
    required String label,
  }) : occurredAt = occurredAt.toUtc(),
       label = label.trim();

  final String sourceId;
  final CodexSourceKind kind;
  final DateTime occurredAt;
  final String label;

  Map<String, Object?> toJson() => {
    'sourceId': sourceId,
    'kind': kind.name,
    'occurredAt': occurredAt.toIso8601String(),
    'label': label,
  };
}

final class CodexPassage {
  CodexPassage({
    required String heading,
    required String text,
    required Iterable<CodexCitation> citations,
  }) : heading = heading.trim(),
       text = text.trim(),
       citations = UnmodifiableListView(citations);

  final String heading;
  final String text;
  final List<CodexCitation> citations;

  Map<String, Object?> toJson() => {
    'heading': heading,
    'text': text,
    'citations': citations.map((item) => item.toJson()).toList(),
  };
}

final class CodexChapter {
  CodexChapter({
    required this.id,
    required String title,
    required this.ordinal,
    required DateTime start,
    required DateTime end,
    required Iterable<CodexPassage> passages,
    Iterable<String> clusterIds = const [],
  }) : title = title.trim(),
       start = start.toUtc(),
       end = end.toUtc(),
       passages = UnmodifiableListView(passages),
       clusterIds = UnmodifiableListView(clusterIds);

  final String id;
  final String title;
  final int ordinal;
  final DateTime start;
  final DateTime end;
  final List<CodexPassage> passages;
  final List<String> clusterIds;

  CodexChapter copyWith({int? ordinal}) => CodexChapter(
    id: id,
    title: title,
    ordinal: ordinal ?? this.ordinal,
    start: start,
    end: end,
    passages: passages,
    clusterIds: clusterIds,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'ordinal': ordinal,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'clusterIds': clusterIds,
    'passages': passages.map((item) => item.toJson()).toList(),
  };
}

final class CodexManuscript {
  CodexManuscript({
    required this.id,
    required String title,
    required this.template,
    required this.organization,
    required DateTime generatedAt,
    required Iterable<CodexChapter> chapters,
  }) : title = title.trim(),
       generatedAt = generatedAt.toUtc(),
       chapters = UnmodifiableListView(chapters);

  final String id;
  final String title;
  final CodexPublicationTemplate template;
  final CodexOrganization organization;
  final DateTime generatedAt;
  final List<CodexChapter> chapters;

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'id': id,
    'title': title,
    'template': template.name,
    'organization': organization.name,
    'generatedAt': generatedAt.toIso8601String(),
    'chapters': chapters.map((item) => item.toJson()).toList(),
  };
}

final class CodexCompilationRequest {
  const CodexCompilationRequest({
    required this.title,
    required this.template,
    required this.organization,
    this.selectedClusterIds = const [],
    this.selectedSourceIds = const [],
    this.chapterOrder = const [],
    this.includeUnclustered = true,
  });

  final String title;
  final CodexPublicationTemplate template;
  final CodexOrganization organization;
  final List<String> selectedClusterIds;
  final List<String> selectedSourceIds;
  final List<String> chapterOrder;
  final bool includeUnclustered;
}

final class CodexCancellation {
  bool _cancelled = false;
  bool get cancelled => _cancelled;
  void cancel() => _cancelled = true;
  void throwIfCancelled() {
    if (_cancelled) throw const CodexCancelledException();
  }
}

final class CodexCancelledException implements Exception {
  const CodexCancelledException();
}

final class CodexRenderedArtifacts {
  CodexRenderedArtifacts({
    required this.pdf,
    required this.epub,
    required this.offlineHtml,
  });

  final List<int> pdf;
  final List<int> epub;
  final List<int> offlineHtml;
}
