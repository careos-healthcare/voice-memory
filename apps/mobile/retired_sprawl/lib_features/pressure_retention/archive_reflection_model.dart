/// A single focused, evidence-based question the archive can answer.
class ArchiveReflectionQuestion {
  const ArchiveReflectionQuestion({required this.id, required this.prompt});

  final String id;
  final String prompt;
}

/// An answer derived only from local saved pressure data.
class ArchiveReflectionAnswer {
  const ArchiveReflectionAnswer({
    required this.text,
    required this.hasEvidence,
  });

  final String text;

  /// False when the archive had to fall back to the insufficient-evidence line.
  final bool hasEvidence;
}
