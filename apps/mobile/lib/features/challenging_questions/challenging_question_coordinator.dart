import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/challenging_questions/challenging_question_prompt.dart';
import 'package:archiveme_mobile/features/challenging_questions/stance_anchor.dart';
import 'package:archiveme_mobile/features/challenging_questions/stance_evolution_scanner.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/services/local_llm/local_llm_types.dart';
import 'package:flutter/foundation.dart';

/// One generated question kept for the daily reflection surface.
final class ChallengingQuestion {
  const ChallengingQuestion({
    required this.text,
    required this.topic,
    required this.dateString,
  });

  final String text;
  final String topic;
  final String dateString;
}

/// Quiet scan-and-ask flow. refresh is the hook the local model worker
/// runs after its lazy start on reflection and insight routes.
abstract final class ChallengingQuestionCoordinator {
  ChallengingQuestionCoordinator._();

  static const prefsKey = 'challenging_question_v1';

  static ChallengingQuestion? latest;
  static final List<VoidCallback> _listeners = <VoidCallback>[];
  static Future<void>? _inFlight;

  static void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  static void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  static Future<void> refresh() {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return Future<void>.value();
    }
    final current = _inFlight;
    if (current != null) return current;
    final run = _runQuietly();
    _inFlight = run;
    return run.whenComplete(() {
      if (identical(_inFlight, run)) _inFlight = null;
    });
  }

  static Future<String?> ask({
    required StanceAnchor anchor,
    required Future<String> Function(LocalLlmCompletionRequest request)
    complete,
  }) async {
    final raw = await complete(ChallengingQuestionPrompt.requestFor(anchor));
    return ChallengingQuestionPrompt.singleQuestion(raw);
  }

  static Future<void> _runQuietly() async {
    if (!AppServices.isInitialized) return;
    try {
      final today = _today();
      final stored = await _readStored();
      if (stored != null && stored.dateString == today) {
        _publish(stored);
        return;
      }

      final entries = await AppServices.instance.journal.loadAll();
      final evolution = await AppServices.instance.beliefEvolution.loadState();
      final anchors = const StanceEvolutionScanner().scan(
        entries: entries,
        evolution: evolution,
      );
      if (anchors.isEmpty) return;

      final llm = await AppServices.instance.resolveLocalLlm();
      if (llm == null) return;
      final question = await ask(
        anchor: anchors.first,
        complete: (request) async {
          final buffer = StringBuffer();
          await llm.streamCompletion(request).forEach(buffer.write);
          return buffer.toString();
        },
      );
      if (question == null) return;
      final published = ChallengingQuestion(
        text: question,
        topic: anchors.first.topic,
        dateString: today,
      );
      await AppServices.instance.prefs.writeJsonMap(prefsKey, {
        'text': published.text,
        'topic': published.topic,
        'date': published.dateString,
      });
      _publish(published);
    } on Object catch (error, stackTrace) {
      AppLogger.debug(
        'Challenging question scan skipped',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static Future<ChallengingQuestion?> readStored() => _readStored();

  static Future<ChallengingQuestion?> _readStored() async {
    if (!AppServices.isInitialized) return null;
    final raw = await AppServices.instance.prefs.readJsonMap(prefsKey);
    if (raw == null) return null;
    final text = raw['text']?.toString().trim() ?? '';
    final topic = raw['topic']?.toString().trim() ?? '';
    final date = raw['date']?.toString().trim() ?? '';
    if (text.isEmpty || date.isEmpty) return null;
    return ChallengingQuestion(text: text, topic: topic, dateString: date);
  }

  static void _publish(ChallengingQuestion question) {
    latest = question;
    List<VoidCallback>.of(_listeners).forEach(_callListener);
  }

  static void _callListener(VoidCallback listener) {
    listener();
  }

  static String _today() {
    final now = DateTime.now().toLocal();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  @visibleForTesting
  static void resetForTest() {
    latest = null;
    _inFlight = null;
    _listeners.clear();
  }
}
