import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/live_audio/application/live_voice_capture_service.dart';
import 'package:voicememory_mobile/features/live_audio/application/live_voice_telemetry_source.dart';
import 'package:voicememory_mobile/features/live_audio/domain/models/live_voice_session_fault.dart';
import 'package:voicememory_mobile/features/live_audio/presentation/live_audio_ui_providers.dart';

void main() {
  group('ThrottledTelemetryNotifier', () {
    late StreamController<LiveVoiceDiagnosticsSnapshot> diagnosticsController;
    late _FakeTelemetrySource telemetrySource;
    late ProviderContainer container;

    LiveVoiceDiagnosticsSnapshot snapshot(int pcmChunksSent) {
      return LiveVoiceDiagnosticsSnapshot(
        pcmChunksSent: pcmChunksSent,
        audioChunksReceived: 0,
        audioBytesReceived: 0,
        reconnectAttempts: 0,
        sessionFaults: 0,
        firstAudioLatencyMs: null,
        playbackQueueDepth: 0,
      );
    }

    setUp(() {
      diagnosticsController =
          StreamController<LiveVoiceDiagnosticsSnapshot>.broadcast();
      telemetrySource = _FakeTelemetrySource(
        diagnosticsStream: diagnosticsController.stream,
      );
      container = ProviderContainer(
        overrides: [
          throttledTelemetryConfigProvider.overrideWithValue(
            ThrottledTelemetryConfig(
              captureService: telemetrySource,
              diagnosticsStream: diagnosticsController.stream,
              refreshInterval: const Duration(milliseconds: 100),
            ),
          ),
        ],
      );
      container.read(throttledTelemetryProvider);
    });

    tearDown(() async {
      container.dispose();
      await diagnosticsController.close();
    });

    test('exposes latest snapshot and engine state', () async {
      expect(container.read(throttledTelemetryProvider).snapshot, isNull);
      expect(
        container.read(throttledTelemetryProvider).engineState,
        LiveVoiceCaptureState.active,
      );

      diagnosticsController.add(snapshot(1));
      await pumpEventQueue();
      expect(
        container.read(throttledTelemetryProvider).snapshot?.pcmChunksSent,
        1,
      );
    });

    test(
      'throttles rapid diagnostics to at most ten UI updates per second',
      () async {
        var notifyCount = 0;
        container.listen(throttledTelemetryProvider, (_, _) => notifyCount++);

        for (var i = 0; i < 50; i++) {
          diagnosticsController.add(snapshot(i));
        }

        await Future<void>.delayed(const Duration(milliseconds: 20));
        final immediateCount = notifyCount;

        await Future<void>.delayed(const Duration(milliseconds: 120));
        final afterWindowCount = notifyCount;

        expect(immediateCount, lessThanOrEqualTo(2));
        expect(afterWindowCount, lessThan(15));
        expect(
          container.read(throttledTelemetryProvider).snapshot?.pcmChunksSent,
          49,
        );
      },
    );

    test(
      'updates when capture engine state changes through service listener',
      () {
        telemetrySource.emitCaptureStateChange(LiveVoiceCaptureState.paused);

        expect(
          container.read(throttledTelemetryProvider).engineState,
          LiveVoiceCaptureState.paused,
        );
      },
    );
  });
}

class _FakeTelemetrySource implements LiveVoiceTelemetrySource {
  _FakeTelemetrySource({
    required this.diagnosticsStream,
    LiveVoiceCaptureState initialState = LiveVoiceCaptureState.active,
  }) : _captureState = initialState;

  @override
  final Stream<LiveVoiceDiagnosticsSnapshot> diagnosticsStream;

  LiveVoiceCaptureState _captureState;
  final List<VoidCallback> _listeners = <VoidCallback>[];

  @override
  LiveVoiceCaptureState get captureState => _captureState;

  @override
  LiveVoiceDiagnosticsSnapshot get diagnostics => LiveVoiceDiagnosticsSnapshot(
    pcmChunksSent: 0,
    audioChunksReceived: 0,
    audioBytesReceived: 0,
    reconnectAttempts: 0,
    sessionFaults: 0,
    firstAudioLatencyMs: null,
    playbackQueueDepth: 0,
  );

  void emitCaptureStateChange(LiveVoiceCaptureState next) {
    _captureState = next;
    for (final listener in List<VoidCallback>.of(_listeners)) {
      listener();
    }
  }

  @override
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }
}
