import 'dart:async';

enum LiveTurnRole { user, assistant }

enum LiveSttRoute { onDevice, whisper, offline }

class LiveConversationTurn {
  const LiveConversationTurn({
    required this.role,
    required this.text,
    this.partial = false,
  });

  final LiveTurnRole role;
  final String text;
  final bool partial;
}

/// On-device streaming when the phone can do it. Whisper only while online.
/// Offline keeps the meter and waits for the saved recording.
LiveSttRoute resolveLiveStt({
  required bool onDeviceStreaming,
  required bool online,
}) {
  if (onDeviceStreaming) return LiveSttRoute.onDevice;
  if (online) return LiveSttRoute.whisper;
  return LiveSttRoute.offline;
}

typedef LiveTurnResponder = Future<String> Function(
  String utterance,
  List<LiveConversationTurn> history,
);

/// Turns a mic level and partial transcript into user and assistant bubbles.
class LiveVoiceSession {
  LiveVoiceSession({
    required this.respond,
    this.onChanged,
    this.silenceThresholdDb = -45,
    this.silenceHold = const Duration(milliseconds: 800),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final LiveTurnResponder respond;
  final void Function()? onChanged;
  final double silenceThresholdDb;
  final Duration silenceHold;
  final DateTime Function() _clock;

  final List<LiveConversationTurn> turns = [];
  var closed = false;
  String _partial = '';
  DateTime? _silentSince;
  var _heardSpeech = false;
  var _replying = false;

  void noteLevel(double db) {
    if (closed || _replying) return;
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
    if (closed || _replying) return;
    final utterance = _partial.trim();
    if (utterance.isEmpty) return;
    _replying = true;
    _silentSince = null;
    _heardSpeech = false;
    _partial = '';
    _replacePartial(LiveConversationTurn(role: LiveTurnRole.user, text: utterance));
    onChanged?.call();
    try {
      final reply = (await respond(utterance, List.unmodifiable(turns))).trim();
      if (!closed && reply.isNotEmpty) {
        turns.add(LiveConversationTurn(role: LiveTurnRole.assistant, text: reply));
      }
    } finally {
      _replying = false;
      onChanged?.call();
    }
  }

  Future<void> close() async {
    closed = true;
    _silentSince = null;
  }

  void _upsertPartial() {
    final text = _partial.trim();
    if (text.isEmpty) return;
    _replacePartial(
      LiveConversationTurn(role: LiveTurnRole.user, text: text, partial: true),
    );
    onChanged?.call();
  }

  void _replacePartial(LiveConversationTurn turn) {
    if (turns.isNotEmpty &&
        turns.last.role == LiveTurnRole.user &&
        turns.last.partial) {
      turns[turns.length - 1] = turn;
    } else {
      turns.add(turn);
    }
  }
}
