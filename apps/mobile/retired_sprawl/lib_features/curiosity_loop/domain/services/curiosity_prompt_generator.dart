import 'package:archiveme_mobile/features/curiosity_loop/domain/models/curiosity_hook.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Synthesizes clinically-aware curiosity prompts from hook and entry context.
abstract interface class CuriosityPromptGenerator {
  Future<String> generatePrompt({
    required CuriosityHook hook,
    JournalEntry? sourceEntry,
  });
}

class DefaultCuriosityPromptGenerator implements CuriosityPromptGenerator {
  const DefaultCuriosityPromptGenerator({
    this.lowLexicalDiversityThreshold = 0.5,
    this.highCohesionDriftThreshold = 0.75,
  });

  static const lowCognitiveLoadLeadIn = 'You touched on';
  static const lowCognitiveLoadTail = 'Short thoughts are perfect.';
  static const advancedRecallLeadIn = 'Reflecting back on your notes regarding';
  static const advancedRecallTail =
      'what structural changes have occurred since that moment?';
  static const groundingLeadIn = "Let's focus on right now.";
  static const groundingQuestion =
      'What is one clear thing you finished today?';

  final double lowLexicalDiversityThreshold;
  final double highCohesionDriftThreshold;

  @override
  Future<String> generatePrompt({
    required CuriosityHook hook,
    JournalEntry? sourceEntry,
  }) async {
    if (hook.isMemoryRecallCheck) {
      if (sourceEntry == null) {
        return _fallbackPrompt(hook);
      }
      return _memoryRecallPrompt(hook: hook, sourceEntry: sourceEntry);
    }

    return _standardPrompt(hook: hook, sourceEntry: sourceEntry);
  }

  String _memoryRecallPrompt({
    required CuriosityHook hook,
    required JournalEntry sourceEntry,
  }) {
    final topic = _topicLabel(hook: hook, sourceEntry: sourceEntry);
    final lexicalDiversity = sourceEntry.biomarkers?.lexicalDiversity;

    if (lexicalDiversity != null &&
        lexicalDiversity < lowLexicalDiversityThreshold) {
      return '$lowCognitiveLoadLeadIn $topic recently. '
          'How does it look right now? $lowCognitiveLoadTail';
    }

    return '$advancedRecallLeadIn $topic—$advancedRecallTail';
  }

  String _standardPrompt({
    required CuriosityHook hook,
    JournalEntry? sourceEntry,
  }) {
    final cohesionDrift = sourceEntry?.biomarkers?.cohesionDrift;
    if (cohesionDrift != null && cohesionDrift > highCohesionDriftThreshold) {
      return '$groundingLeadIn $groundingQuestion';
    }

    return _forwardLookingPrompt(hook);
  }

  String _fallbackPrompt(CuriosityHook hook) {
    final existing = hook.dynamicPrompt.trim();
    if (existing.isNotEmpty) return existing;
    return _forwardLookingPrompt(hook);
  }

  String _forwardLookingPrompt(CuriosityHook hook) {
    final existing = hook.dynamicPrompt.trim();
    if (existing.isNotEmpty) return existing;

    final anchor = hook.primaryAnchor.trim();
    if (anchor.isEmpty) {
      return 'What feels most worth noticing right now?';
    }

    return switch (hook.hookType) {
      CuriosityHookType.blocker =>
        'Before "$anchor" shows up again, what do you want to watch for first?',
      CuriosityHookType.momentum =>
        'You named "$anchor" — what feels different about it now?',
      CuriosityHookType.returnWatch =>
        'Come back to "$anchor" — what changed since you last named it?',
      CuriosityHookType.anchorFollowUp =>
        'Next time "$anchor" comes up, what do you want to notice first?',
    };
  }

  String _topicLabel({required CuriosityHook hook, JournalEntry? sourceEntry}) {
    final anchor = hook.primaryAnchor.trim();
    if (anchor.isNotEmpty) return anchor;

    final reflectionTopic = sourceEntry?.reflectionSummary.trim();
    if (reflectionTopic != null && reflectionTopic.isNotEmpty) {
      return reflectionTopic;
    }

    final transcript = sourceEntry?.transcript.trim();
    if (transcript != null && transcript.isNotEmpty) {
      if (transcript.length <= 72) return transcript;
      return '${transcript.substring(0, 71).trim()}…';
    }

    return 'that moment';
  }
}