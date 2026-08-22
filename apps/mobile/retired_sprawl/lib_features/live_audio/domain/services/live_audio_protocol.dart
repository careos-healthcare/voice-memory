import 'dart:convert';

import 'package:archiveme_mobile/features/live_audio/domain/models/live_server_event.dart';
import 'package:archiveme_mobile/features/live_audio/live_audio_constants.dart';

/// Pure Bidi protocol helpers mirrored from the backend live-audio protocol.
abstract final class LiveAudioProtocol {
  LiveAudioProtocol._();

  static Map<String, dynamic> buildAudioInputMessage(List<int> pcm16kBytes) {
    return {
      'realtimeInput': {
        'audio': {
          'mimeType': liveInputAudioMime,
          'data': base64Encode(pcm16kBytes),
        },
      },
    };
  }

  static Map<String, dynamic> buildAudioStreamEndMessage() {
    return {
      'realtimeInput': {'audioStreamEnd': true},
    };
  }

  /// First client frame for a Gemini Live Bidi session.
  static Map<String, dynamic> buildSetupMessage({
    required String model,
    String? systemInstruction,
    String voiceName = 'Aoede',
  }) {
    final trimmedModel = model.trim();
    final modelResource = trimmedModel.startsWith('models/')
        ? trimmedModel
        : 'models/$trimmedModel';
    final setup = <String, dynamic>{
      'model': modelResource,
      'generationConfig': {
        'responseModalities': ['AUDIO'],
        'speechConfig': {
          'voiceConfig': {
            'prebuiltVoiceConfig': {
              'voiceName': voiceName,
            },
          },
        },
      },
    };
    final instruction = systemInstruction?.trim();
    if (instruction != null && instruction.isNotEmpty) {
      setup['systemInstruction'] = {
        'parts': [
          {'text': instruction},
        ],
      };
    }
    return {'setup': setup};
  }

  static String encodeClientMessage(Map<String, dynamic> message) {
    return jsonEncode(message);
  }

  static List<LiveServerEvent> parseServerJson(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      return parseServerMessage(decoded);
    } catch (_, stackTrace) {
      return const [LiveServerErrorEvent(message: 'invalid_server_json')];
    }
  }

  static List<LiveServerEvent> parseServerMessage(Object? raw) {
    final message = _asMap(raw);
    if (message == null) return const [];

    final events = <LiveServerEvent>[];

    if (message.containsKey('setupComplete')) {
      events.add(const LiveSetupCompleteEvent());
    }

    if (message.containsKey('goAway')) {
      final goAway = _asMap(message['goAway']);
      events.add(LiveGoAwayEvent(timeLeft: goAway?['timeLeft'] as String?));
    }

    final serverContent = _asMap(message['serverContent']);
    if (serverContent != null) {
      if (serverContent['interrupted'] == true) {
        events.add(const LiveInterruptedEvent());
      }
      if (serverContent['turnComplete'] == true) {
        events.add(const LiveTurnCompleteEvent());
      }

      final inputTranscription = _readTranscription(
        serverContent['inputTranscription'],
      );
      if (inputTranscription != null) {
        events.add(LiveInputTranscriptionEvent(text: inputTranscription));
      }

      final outputTranscription = _readTranscription(
        serverContent['outputTranscription'],
      );
      if (outputTranscription != null) {
        events.add(LiveOutputTranscriptionEvent(text: outputTranscription));
      }

      final modelTurn = _asMap(serverContent['modelTurn']);
      final parts = modelTurn?['parts'];
      if (parts is List) {
        for (final part in parts) {
          final audio = _readInlineAudio(_asMap(part));
          if (audio != null) events.add(audio);
        }
      }
    }

    final error = _asMap(message['error']);
    if (error != null) {
      final messageText =
          error['message'] as String? ??
          error['status'] as String? ??
          'live_server_error';
      events.add(LiveServerErrorEvent(message: messageText));
    }

    if (events.isEmpty) {
      events.add(LiveUnknownServerEvent(topLevelKeys: message.keys.toList()));
    }

    return events;
  }

  static ClientMessageValidation validateClientMessage(Object? raw) {
    final message = _asMap(raw);
    if (message == null) {
      return const ClientMessageValidation.invalid('invalid_client_json');
    }

    if (message.length != 1) {
      return const ClientMessageValidation.invalid(
        'client_message_must_have_exactly_one_top_level_key',
      );
    }

    const allowed = {'setup', 'clientContent', 'realtimeInput', 'toolResponse'};
    final key = message.keys.first;
    if (!allowed.contains(key)) {
      return const ClientMessageValidation.invalid(
        'unsupported_client_message_key',
      );
    }

    if (key == 'realtimeInput') {
      final realtimeInput = _asMap(message['realtimeInput']);
      if (realtimeInput == null) {
        return const ClientMessageValidation.invalid('invalid_realtime_input');
      }
      if (realtimeInput.containsKey('mediaChunks')) {
        return const ClientMessageValidation.invalid('deprecated_media_chunks');
      }
      if (realtimeInput.containsKey('audio')) {
        final audio = _asMap(realtimeInput['audio']);
        if (audio == null ||
            audio['data'] is! String ||
            audio['mimeType'] is! String) {
          return const ClientMessageValidation.invalid('invalid_audio_blob');
        }
        if (audio['mimeType'] != liveInputAudioMime) {
          return const ClientMessageValidation.invalid(
            'invalid_input_audio_mime',
          );
        }
      }
    }

    return ClientMessageValidation.valid(message);
  }

  static Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static String? _readTranscription(Object? value) {
    final record = _asMap(value);
    final text = record?['text'];
    if (text is! String || text.trim().isEmpty) return null;
    return text;
  }

  static LiveAudioOutputEvent? _readInlineAudio(Map<String, dynamic>? part) {
    final inlineData = _asMap(part?['inlineData']);
    final data = inlineData?['data'];
    if (data is! String || data.isEmpty) return null;
    return LiveAudioOutputEvent(
      pcmBytes: base64Decode(data),
      mimeType: inlineData?['mimeType'] as String?,
    );
  }
}

final class ClientMessageValidation {
  const ClientMessageValidation._({
    required this.ok,
    this.reason,
    this.message,
  });

  const ClientMessageValidation.valid(Map<String, dynamic> message)
    : this._(ok: true, message: message);

  const ClientMessageValidation.invalid(String reason)
    : this._(ok: false, reason: reason);

  final bool ok;
  final String? reason;
  final Map<String, dynamic>? message;
}