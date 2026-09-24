import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/features/ambient_capture/ambient_capture_router.dart';
import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/import/share_intent_handler.dart';
import 'package:archiveme_mobile/features/import/sherpa_speech_queue.dart';
import 'package:archiveme_mobile/features/live_audio/infrastructure/native_audio_lifecycle_bridge.dart';
import 'package:archiveme_mobile/router/app_router.dart';
import 'package:archiveme_mobile/router/route_catalog.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Control Center and Quick Settings both ask the app to start recording.
abstract final class QuickRecordAction {
  QuickRecordAction._();

  static const channelName = 'com.archiveme/quick_actions';
  static const startRecording = 'start_recording';
  static const openTranscript = 'open_transcript';
  static const onQuickAction = 'onQuickAction';
  static const consumePending = 'consumePendingQuickAction';

  static bool isStartRecordingLink(Uri uri) {
    if (uri.scheme.toLowerCase() != 'archiveme') return false;
    if (uri.host.toLowerCase() != 'action') return false;
    final path = uri.path.toLowerCase();
    return path == '/record' || path == 'record';
  }

  static bool isTranscriptLink(Uri uri) {
    if (uri.scheme.toLowerCase() != 'archiveme') return false;
    if (uri.host.toLowerCase() != 'action') return false;
    final path = uri.path.toLowerCase();
    return path == '/transcript' || path == 'transcript';
  }

  /// Opens the recording surface, which holds the live transcript.
  static void openTranscriptScreen() {
    final context = appRootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    context.go(RouteCatalog.recordHome);
  }

  /// Starts capture through [NativeAudioLifecycleBridge], the Dart side of
  /// the iOS `LiveAudioLifecycleBridge`. While live voice is gated off, the
  /// same control starts the on-device recorder used by the record screen.
  static Future<void> startCapture() async {
    if (!AppServices.isInitialized) return;
    if (V1CapabilityRegistry.liveVoice) {
      final bridge = NativeAudioLifecycleBridge(
        AppServices.instance.liveVoiceCapture,
      );
      await bridge.startRecordingSequence();
      return;
    }
    await AppServices.instance.recording.startRecording();
  }
}

class QuickRecordActionNotifier extends Notifier<void> {
  StreamSubscription<Uri>? _links;
  MethodChannel? _channel;
  Future<void> Function()? _startRecording;
  DateTime? _lastStart;
  var _bound = false;

  @visibleForTesting
  Duration duplicateWindow = const Duration(seconds: 2);

  @override
  void build() {}

  Future<void> bind({
    MethodChannel? channel,
    Stream<Uri>? linkStream,
    Future<Uri?>? initialLink,
    Future<void> Function()? startRecording,
    bool listenToAppLinks = true,
  }) async {
    if (_bound) return;
    _bound = true;
    _startRecording = startRecording ?? QuickRecordAction.startCapture;
    _channel = channel ?? const MethodChannel(QuickRecordAction.channelName);
    _channel!.setMethodCallHandler(_onMethodCall);
    ref.onDispose(() {
      _channel?.setMethodCallHandler(null);
      unawaited(_links?.cancel());
      _links = null;
      _bound = false;
    });

    if (listenToAppLinks) {
      final stream = linkStream ?? AppLinks().uriLinkStream;
      _links = stream.listen(
        _onLink,
        onError: (Object error, StackTrace stackTrace) {
          AppLogger.debug(
            'Quick record link stream skipped',
            error: error,
            stackTrace: stackTrace,
          );
        },
      );
    }

    try {
      final pending = await _channel!.invokeMethod<String>(
        QuickRecordAction.consumePending,
      );
      await _handleAction(pending);
    } on MissingPluginException {
      // Desktop and tests have no native tile.
    } on PlatformException catch (error, stackTrace) {
      AppLogger.debug(
        'Quick record pending action skipped',
        error: error,
        stackTrace: stackTrace,
      );
    }

    final initial = initialLink ?? _initialAppLink();
    final uri = await initial;
    if (uri != null) _onLink(uri);
  }

  Future<void> _onMethodCall(MethodCall call) async {
    if (call.method != QuickRecordAction.onQuickAction) return;
    final action = call.arguments;
    if (action is String) await _handleAction(action);
  }

  void _onLink(Uri uri) {
    if (QuickRecordAction.isTranscriptLink(uri)) {
      unawaited(_handleAction(QuickRecordAction.openTranscript));
      return;
    }
    if (!QuickRecordAction.isStartRecordingLink(uri)) return;
    unawaited(_handleAction(QuickRecordAction.startRecording));
  }

  Future<void> _handleAction(String? action) async {
    if (action == QuickRecordAction.openTranscript) {
      QuickRecordAction.openTranscriptScreen();
      return;
    }
    if (action != QuickRecordAction.startRecording) return;
    final now = DateTime.now();
    final previous = _lastStart;
    if (previous != null && now.difference(previous) < duplicateWindow) {
      return;
    }
    _lastStart = now;
    try {
      await (_startRecording ?? QuickRecordAction.startCapture)();
    } on Object catch (error, stackTrace) {
      AppLogger.debug(
        'Quick record start skipped',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<Uri?> _initialAppLink() async {
    try {
      return await AppLinks().getInitialLink();
    } on Object catch (error, stackTrace) {
      AppLogger.debug(
        'Quick record initial link skipped',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}

final quickRecordActionProvider =
    NotifierProvider<QuickRecordActionNotifier, void>(
      QuickRecordActionNotifier.new,
    );

/// Binds the Control Center / Quick Settings listener once the shell mounts.
class QuickRecordActionListenerHost extends ConsumerStatefulWidget {
  const QuickRecordActionListenerHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<QuickRecordActionListenerHost> createState() =>
      _QuickRecordActionListenerHostState();
}

class _QuickRecordActionListenerHostState
    extends ConsumerState<QuickRecordActionListenerHost> {
  @override
  void initState() {
    super.initState();
    unawaited(ref.read(quickRecordActionProvider.notifier).bind());
    AmbientCaptureRouter.flush();
    importTranscriptionQueue.transcribe ??= SherpaSpeechQueue.instance.enqueue;
    unawaited(ShareIntentHandler().start());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
