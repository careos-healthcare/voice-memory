import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/curiosity_loop/domain/models/curiosity_hook.dart';
import 'package:archiveme_mobile/features/curiosity_loop/domain/services/curiosity_prompt_generator.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Resolves clinically synthesized display prompts for curiosity hooks.
class CuriosityPromptResolver {
  CuriosityPromptResolver({CuriosityPromptGenerator? generator})
    : _generator = generator ?? const DefaultCuriosityPromptGenerator();

  final CuriosityPromptGenerator _generator;

  Future<String> resolveDisplayPrompt({
    required CuriosityHook hook,
    JournalEntry? sourceEntry,
    JournalEntry? hookEntry,
  }) async {
    final contextEntry = hook.isMemoryRecallCheck
        ? sourceEntry
        : (hookEntry ?? sourceEntry);

    try {
      final synthesized = await _generator.generatePrompt(
        hook: hook,
        sourceEntry: contextEntry,
      );
      final trimmed = synthesized.trim();
      if (trimmed.isNotEmpty) return trimmed;
    } catch (e, stackTrace) {
      AppLogger.error('Unhandled error caught', error: e, stackTrace: stackTrace);
      // Fall back to the stored hook prompt when synthesis fails.
    }

    final fallback = hook.dynamicPrompt.trim();
    return fallback.isEmpty
        ? 'What feels most worth noticing right now?'
        : fallback;
  }
}