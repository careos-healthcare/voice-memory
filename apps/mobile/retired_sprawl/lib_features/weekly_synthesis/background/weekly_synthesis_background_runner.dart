import 'package:archiveme_mobile/core/execution/execution.dart';
import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/database/app_database.dart';
import 'package:archiveme_mobile/features/weekly_synthesis/background/background_task_database_session.dart';
import 'package:archiveme_mobile/features/weekly_synthesis/background/weekly_synthesis_background_constraints.dart';
import 'package:archiveme_mobile/features/weekly_synthesis/data/recurrent_topic_node_query.dart';
import 'package:archiveme_mobile/features/weekly_synthesis/data/weekly_synthesis_repository.dart';
import 'package:archiveme_mobile/features/weekly_synthesis/domain/weekly_topic_synthesis.dart';
import 'package:archiveme_mobile/features/weekly_synthesis/weekly_synthesis_config.dart';
import 'package:archiveme_mobile/services/ai/ai_service.dart';

/// Headless weekly batch: FTS recurrent topics → Gemma synthesis → SQLite node.
abstract final class WeeklySynthesisBackgroundRunner {
  WeeklySynthesisBackgroundRunner._();

  static Future<WeeklySynthesisBackgroundOutcome> run() async {
    if (!await WeeklySynthesisBackgroundConstraints.canRunInference()) {
      return WeeklySynthesisBackgroundOutcome.deferredConstraints;
    }

    final session = await BackgroundTaskDatabaseSession.open();
    if (session == null) {
      return WeeklySynthesisBackgroundOutcome.skippedNoDatabase;
    }

    try {
      final db = session.database;
      final weekStart = _weekStartUtc(DateTime.now().toUtc());
      final weekKey = _weekKey(weekStart);
      final repository = WeeklySynthesisRepository(db);

      if (await repository.hasSynthesisForWeek(weekKey)) {
        return WeeklySynthesisBackgroundOutcome.skippedAlreadyGenerated;
      }

      final since = weekStart.subtract(
        const Duration(days: WeeklySynthesisConfig.lookbackDays),
      );
      final topics = await RecurrentTopicNodeQuery(db).fetchRecurrentTopics(
        since: since,
      );
      if (topics.isEmpty) {
        return WeeklySynthesisBackgroundOutcome.skippedNoRecurrentTopics;
      }

      await AIService.ensureGemmaInitialized();
      if (!AIService.hasLocalGemmaModel) {
        return WeeklySynthesisBackgroundOutcome.deferredModelMissing;
      }

      final llmStrategy = LlmExecutionStrategy(
        backgroundInferenceTimeout: WeeklySynthesisConfig.inferenceTimeBudget,
      );
      final aiService = AIService(llmStrategy: llmStrategy);
      final inference = await llmStrategy.runBackgroundInference(
        operationLabel: 'weekly_topic_synthesis',
        requireInstalledModel: true,
        modelInstalled: () async => AIService.hasLocalGemmaModel,
        action: () => aiService.synthesizeWeeklyTopics(
          topics: topics,
          weekLabel: weekKey,
          requireInstalledModel: true,
        ),
      );

      if (inference.isDeferred) {
        return switch (inference.failureOrNull) {
          LlmFailureModelMissing() =>
            WeeklySynthesisBackgroundOutcome.deferredModelMissing,
          _ => WeeklySynthesisBackgroundOutcome.deferredConstraints,
        };
      }
      if (inference.isFailure) {
        return switch (inference.failureOrNull) {
          LlmFailureTimeout() =>
            WeeklySynthesisBackgroundOutcome.deferredInferenceTimeout,
          _ => WeeklySynthesisBackgroundOutcome.failed,
        };
      }
      if (inference.isCancelled) {
        return WeeklySynthesisBackgroundOutcome.deferredInferenceTimeout;
      }

      final draft = inference.valueOrNull;
      if (draft == null) {
        return WeeklySynthesisBackgroundOutcome.deferredInferenceTimeout;
      }

      final synthesis = WeeklyTopicSynthesis(
        weekStart: weekStart,
        weekKey: weekKey,
        headline: draft.headline,
        summary: draft.summary,
        sourceNodeIds: topics.expand((topic) => topic.nodeIds).toSet().toList(),
        recurringThemeLabels: draft.recurringThemeLabels,
        generatedAt: DateTime.now().toUtc(),
      );

      await repository.saveSynthesis(synthesis);
      AppLogger.debug(
        'Weekly topic synthesis saved for $weekKey',
        name: 'WeeklySynthesis',
      );
      return WeeklySynthesisBackgroundOutcome.success;
    } on Object catch (error, stackTrace) {
      AppLogger.error(
        'Weekly synthesis background task failed',
        name: 'WeeklySynthesis',
        error: error,
        stackTrace: stackTrace,
      );
      return WeeklySynthesisBackgroundOutcome.failed;
    } finally {
      await session.close();
    }
  }

  static DateTime _weekStartUtc(DateTime utcNow) {
    final day = DateTime.utc(utcNow.year, utcNow.month, utcNow.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  static String _weekKey(DateTime weekStartUtc) {
    final year = weekStartUtc.year;
    final jan4 = DateTime.utc(year, 1, 4);
    final jan4WeekStart =
        jan4.subtract(Duration(days: jan4.weekday - DateTime.monday));
    final weekNumber =
        1 + weekStartUtc.difference(jan4WeekStart).inDays ~/ 7;
    return '$year-W${weekNumber.toString().padLeft(2, '0')}';
  }
}
