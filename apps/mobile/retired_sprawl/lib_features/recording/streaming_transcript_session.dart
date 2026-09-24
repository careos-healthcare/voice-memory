import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archiveme_mobile/features/live_audio/domain/models/live_server_event.dart';
import 'package:archiveme_mobile/features/live_audio/domain/services/live_audio_protocol.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Grows a transcript from WebSocket frames or chunked response lines.
///
/// A longer snapshot replaces the current text only when it continues the
/// same string. A shorter snapshot is ignored so the line does not jump back.
class StreamingTranscriptSession {
  final _bytes = BytesBuilder(copy: false);
  final _textController = StreamController<String>.broadcast();
  var _text = '';

  String get current => _text;

  Stream<String> get text => _textController.stream;

  void addWebSocketFrame(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return;
    final events = LiveAudioProtocol.parseServerJson(trimmed);
    String? input;
    String? output;
    for (final event in events) {
      if (event is LiveInputTranscriptionEvent) input = event.text;
      if (event is LiveOutputTranscriptionEvent) output = event.text;
    }
    final spoken = (input != null && input.trim().isNotEmpty) ? input : output;
    if (spoken != null) {
      _publish(spoken, snapshot: true);
      return;
    }
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) return;
    _publish(trimmed, snapshot: false);
  }

  void addChunkBytes(List<int> bytes) {
    if (bytes.isEmpty) return;
    _bytes.add(bytes);
    final data = _bytes.toBytes();
    final newline = data.lastIndexOf(10);
    if (newline < 0) return;
    final complete = utf8.decode(
      data.sublist(0, newline),
      allowMalformed: true,
    );
    final rest = data.sublist(newline + 1);
    _bytes.clear();
    if (rest.isNotEmpty) _bytes.add(rest);
    for (final line in complete.split('\n')) {
      final payload = line.trim().startsWith('data:')
          ? line.trim().substring(5).trim()
          : line;
      addWebSocketFrame(payload);
    }
  }

  void addDelta(String delta) => _publish(delta, snapshot: false);

  void _publish(String incoming, {required bool snapshot}) {
    final next = snapshot
        ? _applySnapshot(_text, incoming)
        : _applyDelta(_text, incoming);
    if (next == _text) return;
    _text = next;
    if (!_textController.isClosed) _textController.add(_text);
  }

  static String _applySnapshot(String current, String incoming) {
    final next = incoming.trim();
    if (next.isEmpty || next == current) return current;
    if (current.isEmpty || next.startsWith(current)) return next;
    if (current.startsWith(next)) return current;
    return _applyDelta(current, next);
  }

  static String _applyDelta(String current, String incoming) {
    final next = incoming.trim();
    if (next.isEmpty) return current;
    if (current.isEmpty) return next;
    final gap = current.endsWith(' ') || next.startsWith(' ') ? '' : ' ';
    return '$current$gap$next';
  }

  Future<void> close() async {
    await _textController.close();
  }
}

class StreamingTranscriptNotifier extends Notifier<String> {
  final _session = StreamingTranscriptSession();

  @override
  String build() {
    ref.onDispose(_session.close);
    return '';
  }

  void addWebSocketFrame(String frame) {
    _session.addWebSocketFrame(frame);
    state = _session.current;
  }

  void addChunkBytes(List<int> bytes) {
    _session.addChunkBytes(bytes);
    state = _session.current;
  }

  void addDelta(String delta) {
    _session.addDelta(delta);
    state = _session.current;
  }
}

final streamingTranscriptProvider =
    NotifierProvider<StreamingTranscriptNotifier, String>(
      StreamingTranscriptNotifier.new,
    );
