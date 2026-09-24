import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/features/challenging_questions/challenging_question_coordinator.dart';
import 'package:archiveme_mobile/startup/cold_start_deferred_work.dart';
import 'package:archiveme_mobile/workers/embedding/embedding_index_worker_service.dart';
import 'package:archiveme_mobile/workers/local_llm/local_llm_worker_service.dart';
import 'package:flutter/foundation.dart';

/// Starts embedding and local-LLM isolates only after the user opens a
/// search, insights, or reflection surface.
abstract final class HeavyWorkerWarmup {
  HeavyWorkerWarmup._();

  static var _warmed = false;

  /// True when [location] is a search, insights, or reflection route.
  static bool locationNeedsWorkers(String location) {
    final path = Uri.tryParse(location)?.path ?? location;
    const prefixes = <String>[
      '/explore',
      '/ask-archive',
      '/theories',
      '/belief-detail',
      '/search',
    ];
    if (prefixes.any(path.startsWith)) return true;
    return path.contains('insight') || path.contains('reflection');
  }

  /// Warms background isolates for [location] at most once per process.
  static Future<void> warmForLocation(String location) async {
    if (_warmed || !locationNeedsWorkers(location)) return;
    _warmed = true;
    await ColdStartDeferredWork.run();
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    LocalLlmWorkerHooks.afterReady = ChallengingQuestionCoordinator.refresh;
    unawaited(EmbeddingIndexWorkerService.instance.ensureStarted());
    unawaited(LocalLlmWorkerService.instance.ensureStarted());
    unawaited(ChallengingQuestionCoordinator.refresh());
  }

  @visibleForTesting
  static bool get didWarm => _warmed;

  @visibleForTesting
  static void resetForTest() {
    _warmed = false;
  }
}
