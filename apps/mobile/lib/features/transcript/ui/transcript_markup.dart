/// A highlighted span, its tags, and the clip that can be shared.
class TranscriptClip {
  const TranscriptClip({
    required this.entryId,
    required this.start,
    required this.end,
    required this.text,
    required this.tags,
  });

  final String entryId;
  final int start;
  final int end;
  final String text;
  final List<String> tags;

  String get shareText {
    final labels = tags.isEmpty ? '' : ' (${tags.join(', ')})';
    return '$text$labels';
  }
}

/// Keeps highlights, tags, and shareable clips for one transcript.
class TranscriptMarkup {
  TranscriptMarkup(this.entryId);

  final String entryId;
  final List<TranscriptClip> clips = [];

  TranscriptClip? saveClip({
    required String transcript,
    required int start,
    required int end,
    required List<String> tags,
  }) {
    final length = transcript.length;
    if (start < 0 || end > length || end <= start) return null;
    final clip = TranscriptClip(
      entryId: entryId,
      start: start,
      end: end,
      text: transcript.substring(start, end),
      tags: [
        for (final tag in tags)
          if (tag.trim().isNotEmpty) tag.trim(),
      ],
    );
    clips.add(clip);
    return clip;
  }
}
