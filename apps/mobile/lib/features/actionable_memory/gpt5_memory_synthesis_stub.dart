import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/features/actionable_memory/actionable_memory_models.dart';

/// Turns retrieved moments into one notification.
abstract interface class Gpt5MemorySynthesizer {
  Future<ActionableMemoryDraft> synthesize({
    required ActionableMemoryContext context,
    required List<ActionableMemoryHit> hits,
  });
}

/// Prepares a GPT-5 request and writes the notification locally.
///
/// No network call. A later client can send [Gpt5MemorySynthesisRequest]
/// when [AppConfig.enableGpt5ArchiveSynthesis] is on.
class Gpt5MemorySynthesisStub implements Gpt5MemorySynthesizer {
  const Gpt5MemorySynthesisStub();

  static const instruction =
      'Using only the supplied moments, write one short notification '
      'the person can act on today. Name a concrete detail from a moment. '
      'Do not invent events.';

  Gpt5MemorySynthesisRequest prepare({
    required ActionableMemoryContext context,
    required List<ActionableMemoryHit> hits,
  }) {
    return Gpt5MemorySynthesisRequest(
      model: Gpt5MemorySynthesisRequest.modelId,
      instruction: instruction,
      moments: [
        for (final hit in hits)
          {
            'id': hit.entryId,
            'writtenAt': hit.createdAt.toUtc().toIso8601String(),
            'excerpt': _clip(hit.excerpt, 280),
          },
      ],
    );
  }

  @override
  Future<ActionableMemoryDraft> synthesize({
    required ActionableMemoryContext context,
    required List<ActionableMemoryHit> hits,
  }) async {
    final lead = hits.first;
    return ActionableMemoryDraft(
      title: _title(lead.match),
      body: '${_clip(lead.excerpt, 90)} Open it when you have a minute.',
      sourceEntryIds: [for (final hit in hits) hit.entryId],
      request: prepare(context: context, hits: hits),
      readyForRemoteSynthesis: AppConfig.enableGpt5ArchiveSynthesis,
    );
  }

  static String _title(ActionableMemoryMatch match) {
    return switch (match) {
      ActionableMemoryMatch.place => 'From a place you know',
      ActionableMemoryMatch.calendar => 'Tied to what is on today',
      ActionableMemoryMatch.words => 'You wrote about this before',
      ActionableMemoryMatch.timeOfDay => 'Around this time before',
    };
  }

  static String _clip(String text, int max) {
    final compact = text
        .split(RegExp('[ \t\n\r]+'))
        .where((part) => part.isNotEmpty)
        .join(' ');
    if (compact.length <= max) return compact;
    final slice = compact.substring(0, max);
    final lastSpace = slice.lastIndexOf(' ');
    final cut = lastSpace > 40 ? slice.substring(0, lastSpace) : slice;
    return '$cut…';
  }
}
