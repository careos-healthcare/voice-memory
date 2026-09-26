import 'dart:async';

import 'package:archiveme_mobile/core/audio/audio_session_manager.dart';
import 'package:archiveme_mobile/core/database/database_provider.dart';
import 'package:archiveme_mobile/services/offline_tts/offline_tts_service.dart';

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
    var question = templates[turn % templates.length];
    final finder = findSimilarEntries;
    if (finder != null && transcript.trim().isNotEmpty) {
      final matches = await finder(transcript);
      if (matches.isNotEmpty) {
        final quote = shortVerbatimQuote(matches.first.transcript);
        if (quote.isNotEmpty) {
          question = 'You once said "$quote". What is different now?';
        }
      }
    }

    final local = rephrase;
    if (local != null) {
      final rewritten = await local(question);
      final spoken = _oneSentence(rewritten);
      if (spoken != null) return spoken;
    }

    if (cloudSyncEnabled) {
      final remote = cloudQuestion;
      if (remote != null) {
        final rewritten = await remote(transcript);
        final spoken = _oneSentence(rewritten);
        if (spoken != null) return spoken;
      }
    }
    return question;
  }
}

String? _oneSentence(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  final match = RegExp(r'[.?!]').firstMatch(trimmed);
  if (match == null) return trimmed;
  return trimmed.substring(0, match.end);
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
    this.silence = const Duration(milliseconds: 1500),
    this.energyThresholdDb = -45,
    this.maxAppTurns = 3,
    this.onChanged,
    Timer Function(Duration duration, void Function() callback)? startTimer,
  }) : audioSession = audioSession ?? AudioSessionManager(),
       readAloud = readAloud ?? ReadAloudService(),
       _questions = questions ?? ReflectQuestionGenerator(),
       _startTimer = startTimer ?? Timer.new;

  final AudioSessionManager audioSession;
  final ReadAloudService readAloud;
  final ReflectQuestionGenerator _questions;
  final Duration silence;
  final double energyThresholdDb;
  final int maxAppTurns;
  final void Function()? onChanged;
  final Timer Function(Duration duration, void Function() callback) _startTimer;

  final List<String> questions = [];
  var transcript = '';
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
    transcript = text;
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
    if (readingAloud) {
      readingAloud = false;
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

  Future<void> _appTurn() async {
    if (!conversationActive || _asking || appTurns >= maxAppTurns) {
      if (appTurns >= maxAppTurns) conversationActive = false;
      return;
    }
    _asking = true;
    _speechDuringAsk = false;
    _heardSpeech = false;
    final String question;
    try {
      question = await _questions.next(transcript: transcript, turn: appTurns);
    } catch (_) {
      _asking = false;
      return;
    }
    if (!conversationActive || _speechDuringAsk) {
      _asking = false;
      _speechDuringAsk = false;
      return;
    }
    appTurns += 1;
    questions.add(question);
    readingAloud = true;
    onChanged?.call();
    await readAloud.speak(question);
    readingAloud = false;
    _asking = false;
    if (appTurns >= maxAppTurns) conversationActive = false;
    onChanged?.call();
  }
}
