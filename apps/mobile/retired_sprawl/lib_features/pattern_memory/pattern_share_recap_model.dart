/// Which part of the pattern story a shareable recap is built from.
enum PatternShareRecapType { weekly, progress, memory, fallback }

extension PatternShareRecapTypeIds on PatternShareRecapType {
  String get id => name;
}

/// A simple, keepable text recap a user can copy or share.
class PatternShareRecap {
  const PatternShareRecap({
    required this.id,
    required this.createdAt,
    required this.type,
    required this.title,
    required this.body,
    required this.lines,
    required this.plainText, this.nextQuestion,
  });

  final String id;
  final DateTime createdAt;
  final PatternShareRecapType type;
  final String title;
  final String body;
  final List<String> lines;
  final String? nextQuestion;
  final String plainText;
}