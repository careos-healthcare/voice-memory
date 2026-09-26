import 'dart:async';

enum LiveSttRoute { onDevice, offline }

class LiveConversationTurn {
  const LiveConversationTurn({
    required this.text,
    this.partial = false,
  });

  final String text;
  final bool partial;
}

/// On-device dictation when the phone can stream it. Otherwise the meter
/// waits for the saved recording. There is no assistant reply.
LiveSttRoute resolveLiveStt({required bool onDeviceStreaming}) {
  if (onDeviceStreaming) return LiveSttRoute.onDevice;
  return LiveSttRoute.offline;
}

/// Turns a mic level and partial transcript into one user dictation.
class LiveVoiceSession {
  LiveVoiceSession({
    this.onChanged,
    this.silenceThresholdDb = -45,
    this.silenceHold = const Duration(milliseconds: 800),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final void Function()? onChanged;
  final double silenceThresholdDb;
  final Duration silenceHold;
  final DateTime Function() _clock;

  final List<LiveConversationTurn> turns = [];
  var closed = false;
  String _partial = '';
  DateTime? _silentSince;
  var _heardSpeech = false;
  var _committing = false;

  void noteLevel(double db) {
    if (closed || _committing) return;
    final speaking = db > silenceThresholdDb;
    if (speaking) {
      _heardSpeech = true;
      _silentSince = null;
      return;
    }
    if (!_heardSpeech || _partial.trim().isEmpty) return;
    final now = _clock();
    _silentSince ??= now;
    if (now.difference(_silentSince!) >= silenceHold) {
      unawaited(commitTurn());
    }
  }

  void notePartial(String text) {
    if (closed) return;
    _partial = text;
    _upsertPartial();
  }

  Future<void> commitTurn() async {
    if (closed || _committing) return;
    final utterance = _partial.trim();
    if (utterance.isEmpty) return;
    _committing = true;
    _silentSince = null;
    _heardSpeech = false;
    _partial = '';
    _replacePartial(LiveConversationTurn(text: utterance));
    _committing = false;
    onChanged?.call();
  }

  Future<void> close() async {
    closed = true;
    _silentSince = null;
  }

  void _upsertPartial() {
    final text = _partial.trim();
    if (text.isEmpty) return;
    _replacePartial(LiveConversationTurn(text: text, partial: true));
    onChanged?.call();
  }

  void _replacePartial(LiveConversationTurn turn) {
    if (turns.isNotEmpty && turns.last.partial) {
      turns[turns.length - 1] = turn;
    } else {
      turns.add(turn);
    }
  }
}
