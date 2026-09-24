import 'package:archiveme_mobile/core/hardware/hardware_state_provider.dart';
import 'package:archiveme_mobile/features/ai_coaching/gemma_summary_prompts.dart';
import 'package:archiveme_mobile/services/ai/ai_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef GemmaCompleter =
    Future<String> Function({
      required String systemPrompt,
      required String userPrompt,
    });

/// Rewrites a finished transcript with the local Gemma model.
class GemmaSummaryService {
  GemmaSummaryService({
    HardwareSnapshot? snapshot,
    HeavyWorkScheduler? scheduler,
    GemmaCompleter? completer,
  }) : _snapshot = snapshot ?? HardwareSnapshot.relaxed,
       _scheduler = scheduler ?? HeavyWorkScheduler(),
       _completer = completer;

  final HardwareSnapshot _snapshot;
  final HeavyWorkScheduler _scheduler;
  final GemmaCompleter? _completer;

  Future<GemmaSummaryResult> summarize({
    required String transcript,
    required GemmaSummaryStyle style,
    bool forceImmediate = false,
  }) async {
    final systemPrompt = GemmaSummaryPrompts.systemPrompt(style);
    final userPrompt = GemmaSummaryPrompts.userPrompt(transcript);
    final text = await _scheduler.run<String>(
      snapshot: _snapshot,
      forceImmediate: forceImmediate,
      deferredValue: '',
      task: () => _complete(systemPrompt: systemPrompt, userPrompt: userPrompt),
    );
    if (text.isEmpty && _snapshot.shouldDeferHeavyWork && !forceImmediate) {
      return GemmaSummaryResult.waiting;
    }
    return GemmaSummaryResult(text: text.trim(), deferred: false);
  }

  Future<String> _complete({
    required String systemPrompt,
    required String userPrompt,
  }) async {
    final injected = _completer;
    if (injected != null) {
      return injected(systemPrompt: systemPrompt, userPrompt: userPrompt);
    }
    final service = await AIService.create();
    return service.completeLocally(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
    );
  }
}

/// Latest polished text for a saved moment, keyed by entry id.
class GemmaSummaryNotifier extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => const {};

  void save({required String entryId, required String text}) {
    state = {...state, entryId: text};
  }
}

final gemmaSummaryProvider =
    NotifierProvider<GemmaSummaryNotifier, Map<String, String>>(
      GemmaSummaryNotifier.new,
    );
