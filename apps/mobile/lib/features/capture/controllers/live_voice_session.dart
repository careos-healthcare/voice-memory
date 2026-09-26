import 'dart:async';

import 'package:archiveme_mobile/core/audio/audio_session_manager.dart';
import 'package:archiveme_mobile/core/database/database_provider.dart';
import 'package:archiveme_mobile/features/capture/reflect_question_policy.dart';
import 'package:archiveme_mobile/features/capture/services/entry_save_pipeline.dart';
import 'package:archiveme_mobile/services/offline_tts/offline_tts_service.dart';
import 'package:flutter/foundation.dart';

/// Speaks one short question and can be cut off mid-sentence.
///
/// Playback goes through [OfflineTtsService]. [stop] is the barge-in cut,
/// the same moment `flutter_tts.stop()` would cancel speech.
class ReadAloudService {
  ReadAloudService({
    OfflineTtsService? tts,
    Future<void> Function(String text)? speakText,
    Future<void> Function()? stopPlayback,
  }) : _speakText =
           speakText ??
           (tts == null
               ? null
               : (text) async {
                   await tts.speak(text);
                 }),
       _stopPlayback =
           stopPlayback ?? (tts == null ? null : () => tts.stop(bargeIn: true));

  final Future<void> Function(String text)? _speakText;
  final Future<void> Function()? _stopPlayback;

  var playing = false;

  Future<void> speak(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    playing = true;
    try {
      await _speakText?.call(trimmed);
    } finally {
      playing = false;
    }
  }

  Future<void> stop() async {
    playing = false;
    await _stopPlayback?.call();
  }
}

/// One short question from a local template, an older entry, or on-device
/// rephrasing. A cloud model is used only when cloud sync is already on.
class ReflectQuestionGenerator {
  ReflectQuestionGenerator({
    this.findSimilarEntries,
    this.rephrase,
    this.cloudSyncEnabled = false,
    this.cloudQuestion,
  });

  static const templates = <String>[
    'What stood out just then?',
    'What feels most present in that?',
    'What would you want to remember from that?',
  ];

  /// Local memory search. Callers pass [DatabaseProvider.findSimilarEntries]
  /// after they have turned the live transcript into an embedding.
  final Future<List<SimilarEntry>> Function(String transcript)?
  findSimilarEntries;

  /// On-device rephrase, for example flutter_gemma, when that model is loaded.
  final Future<String?> Function(String draft)? rephrase;

  final bool cloudSyncEnabled;

  final Future<String?> Function(String transcript)? cloudQuestion;

  Future<String> next({
    required String transcript,
    required int turn,
  }) async {
    if (!ReflectQuestionPolicy.canAskAnother(questionsAlreadyAsked: turn)) {
      return '';
    }
    final last = ReflectQuestionPolicy.verbatimSentence(transcript);
    String? earlierQuote;
    DateTime? earlierOn;
    final finder = findSimilarEntries;
    if (finder != null && last.isNotEmpty) {
      final matches = await finder(transcript);
      if (matches.isNotEmpty) {
        final quote = ReflectQuestionPolicy.verbatimSentence(
          matches.first.transcript,
        );
        if (quote.isNotEmpty) {
          earlierQuote = quote;
          earlierOn = matches.first.createdAt;
        }
      }
    }
    final template = ReflectQuestionPolicy.localQuestion(
      lastSentence: last,
      earlierQuote: earlierQuote,
      earlierOn: earlierOn,
    );
    final sources = [
      transcript,
      if (earlierQuote != null) earlierQuote,
    ];
    final local = rephrase;
    if (local != null) {
      try {
        final rewritten = await local(template).timeout(
          ReflectQuestionPolicy.gemmaTimeout,
        );
        if (ReflectQuestionPolicy.accept(
          question: rewritten ?? '',
          requiredQuote: earlierQuote,
          sources: sources,
        )) {
          return rewritten!.trim();
        }
      } on TimeoutException {
        // The template is already a question.
      }
    }
    if (cloudSyncEnabled) {
      final remote = cloudQuestion;
      if (remote != null) {
        final rewritten = await remote(transcript);
        if (ReflectQuestionPolicy.accept(
          question: rewritten ?? '',
          requiredQuote: earlierQuote,
          sources: sources,
        )) {
          return rewritten!.trim();
        }
      }
    }
    return template;
  }
}

/// Silence, a short spoken question, then the microphone again.
///
/// After [maxAppTurns] questions the conversation stops and the caller keeps
/// a normal recording. There is no announcement.
class ReflectWithMeSession {
  ReflectWithMeSession({
    AudioSessionManager? audioSession,
    ReadAloudService? readAloud,
    ReflectQuestionGenerator? questions,
    this.silence = ReflectQuestionPolicy.silence,
    this.energyThresholdDb = -45,
    this.maxAppTurns = 3,
    this.onChanged,
    this.onSpeaking,
    DateTime Function()? clock,
    Timer Function(Duration duration, void Function() callback)? startTimer,
  }) : audioSession = audioSession ?? AudioSessionManager(),
       readAloud = readAloud ?? ReadAloudService(),
       _questions = questions ?? ReflectQuestionGenerator(),
       _clock = clock ?? DateTime.now,
       _startTimer = startTimer ?? Timer.new;

  final AudioSessionManager audioSession;
  final ReadAloudService readAloud;
  final ReflectQuestionGenerator _questions;
  final Duration silence;
  final double energyThresholdDb;
  final int maxAppTurns;
  final void Function()? onChanged;
  final void Function(bool speaking)? onSpeaking;
  final DateTime Function() _clock;
  final Timer Function(Duration duration, void Function() callback) _startTimer;

  final List<String> questions = [];
  final List<VoiceChatLine> lines = [];
  var transcript = '';
  var _openUser = '';
  var appTurns = 0;
  var conversationActive = true;
  var readingAloud = false;

  Timer? _silenceTimer;
  var _heardSpeech = false;
  var _asking = false;
  var _speechDuringAsk = false;

  bool get fellBackToRecording => !conversationActive && appTurns >= maxAppTurns;

  Future<void> start() => audioSession.enterReflectMode();

  void notePartial(String text) {
    if (ReflectQuestionPolicy.isClosing(text)) {
      conversationActive = false;
      _silenceTimer?.cancel();
      _silenceTimer = null;
      _openUser = '';
      lines.removeWhere((line) => line.partial);
      onChanged?.call();
      return;
    }
    _openUser = text.trim();
    transcript = _userWords();
    _upsertPartialUser();
    onChanged?.call();
  }

  /// STT reported that the user started a new utterance.
  void onSpeechStart() => _onUserSpeech();

  void noteLevel(double db) {
    if (db > energyThresholdDb) {
      _onUserSpeech();
      return;
    }
    _armSilence();
  }

  Future<void> close() async {
    conversationActive = false;
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _freezeUser();
    transcript = _userWords();
    if (readingAloud) {
      readingAloud = false;
      onSpeaking?.call(false);
      await readAloud.stop();
    }
  }

  void _onUserSpeech() {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _heardSpeech = true;
    if (_asking) _speechDuringAsk = true;
    if (!readingAloud) return;
    readingAloud = false;
    onSpeaking?.call(false);
    unawaited(readAloud.stop());
  }

  void _armSilence() {
    if (!conversationActive || !_heardSpeech || readingAloud || _asking) {
      return;
    }
    _silenceTimer ??= _startTimer(silence, () {
      _silenceTimer = null;
      unawaited(_appTurn());
    });
  }

  Future<void> end() async {
    conversationActive = false;
    _silenceTimer?.cancel();
    _silenceTimer = null;
    await close();
  }

  Future<void> _appTurn() async {
    if (!conversationActive || _asking || !ReflectQuestionPolicy.canAskAnother(questionsAlreadyAsked: appTurns)) {
      if (appTurns >= maxAppTurns) conversationActive = false;
      return;
    }
    _asking = true;
    _speechDuringAsk = false;
    _heardSpeech = false;
    final decided = _clock();
    final String question;
    try {
      question = await _questions.next(transcript: transcript, turn: appTurns);
    } catch (_) {
      _asking = false;
      return;
    }
    if (question.trim().isEmpty || !conversationActive || _speechDuringAsk) {
      _asking = false;
      _speechDuringAsk = false;
      return;
    }
    if (kDebugMode) {
      final waited = _clock().difference(decided).inMilliseconds;
      debugPrint('reflect question latency ${waited}ms');
    }
    appTurns += 1;
    questions.add(question);
    _freezeUser();
    lines.add(
      VoiceChatLine(
        role: VoiceChatRole.app,
        text: question,
        at: _clock().toUtc(),
      ),
    );
    transcript = _userWords();
    readingAloud = true;
    onSpeaking?.call(true);
    onChanged?.call();
    await readAloud.speak(question);
    readingAloud = false;
    onSpeaking?.call(false);
    _asking = false;
    if (appTurns >= maxAppTurns) conversationActive = false;
    onChanged?.call();
  }

  String _userWords() {
    final parts = <String>[
      for (final line in lines)
        if (line.isUser && !line.partial && line.text.trim().isNotEmpty)
          line.text.trim(),
      if (_openUser.isNotEmpty) _openUser,
    ];
    return parts.join(' ');
  }

  void _upsertPartialUser() {
    lines.removeWhere((line) => line.partial);
    if (_openUser.isEmpty) return;
    lines.add(
      VoiceChatLine(
        role: VoiceChatRole.user,
        text: _openUser,
        at: _clock().toUtc(),
        partial: true,
      ),
    );
  }

  void _freezeUser() {
    final text = _openUser.trim();
    _openUser = '';
    lines.removeWhere((line) => line.partial);
    if (text.isEmpty) return;
    lines.add(
      VoiceChatLine(
        role: VoiceChatRole.user,
        text: text,
        at: _clock().toUtc(),
      ),
    );
  }
}
