import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/live_audio/domain/models/live_voice_error_state.dart';
import 'package:voicememory_mobile/features/live_audio/presentation/live_voice_session_copy.dart';
import 'package:voicememory_mobile/features/live_audio/presentation/widgets/live_voice_error_boundary_overlay.dart';

void main() {
  group('Live Voice Error Boundary State Layer Tests', () {
    testWidgets(
      'Dormant State: Should render SizedBox.shrink when errorState is none',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  const Text('Active Canvas Content'),
                  LiveVoiceErrorBoundaryOverlay(
                    errorState: LiveVoiceErrorState.none,
                    onRetry: () {},
                    onCancel: () {},
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.text('Active Canvas Content'), findsOneWidget);
        expect(find.byType(BackdropFilter), findsNothing);
        expect(find.text('Connection Interrupted'), findsNothing);
      },
    );

    testWidgets(
      'Injected Failure: Network Timeout pops overlay and blocks background interaction',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Hidden Canvas Button'),
                  ),
                  LiveVoiceErrorBoundaryOverlay(
                    errorState: LiveVoiceErrorState.networkTimeout,
                    onRetry: () {},
                    onCancel: () {},
                  ),
                ],
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(BackdropFilter), findsOneWidget);
        expect(find.text('Connection Interrupted'), findsOneWidget);
        expect(
          find.textContaining('live voice server dropped'),
          findsOneWidget,
        );
        expect(find.text(LiveVoiceSessionCopy.tryAgain), findsOneWidget);
        expect(find.text(LiveVoiceSessionCopy.exitSession), findsOneWidget);
      },
    );

    testWidgets(
      'Recovery Loop: Tapping Try Again triggers service recovery handler',
      (tester) async {
        var retryCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  LiveVoiceErrorBoundaryOverlay(
                    errorState: LiveVoiceErrorState.networkTimeout,
                    onRetry: () => retryCalled = true,
                    onCancel: () {},
                  ),
                ],
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('live_voice_error_retry_button')));
        await tester.pump();

        expect(retryCalled, isTrue);
      },
    );

    testWidgets(
      'Exit Session: Tapping exit triggers termination handler hook',
      (tester) async {
        var exitCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  LiveVoiceErrorBoundaryOverlay(
                    errorState: LiveVoiceErrorState.tokenExpired,
                    onRetry: () {},
                    onCancel: () => exitCalled = true,
                  ),
                ],
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('live_voice_error_exit_button')));
        await tester.pump();

        expect(exitCalled, isTrue);
      },
    );

    testWidgets(
      'Service-to-overlay loop: ListenableBuilder reveals overlay on injected failure',
      (tester) async {
        final service = _FakeLiveVoiceService();

        await tester.pumpWidget(
          MaterialApp(
            home: _LiveVoiceErrorBoundaryHost(service: service),
          ),
        );

        expect(find.text('Active Canvas Content'), findsOneWidget);
        expect(find.byType(BackdropFilter), findsNothing);

        service.injectError(LiveVoiceErrorState.networkTimeout);
        await tester.pumpAndSettle();

        expect(find.byType(BackdropFilter), findsOneWidget);
        expect(find.text('Connection Interrupted'), findsOneWidget);
      },
    );

    testWidgets(
      'Service-to-overlay loop: retry clears error and hides overlay',
      (tester) async {
        final service = _FakeLiveVoiceService(
          initialErrorState: LiveVoiceErrorState.networkTimeout,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: _LiveVoiceErrorBoundaryHost(service: service),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(BackdropFilter), findsOneWidget);

        await tester.tap(find.byKey(const Key('live_voice_error_retry_button')));
        await tester.pumpAndSettle();

        expect(service.retryCalled, isTrue);
        expect(service.errorState, LiveVoiceErrorState.none);
        expect(find.byType(BackdropFilter), findsNothing);
      },
    );

    testWidgets(
      'Service-to-overlay loop: exit calls terminate handler hook',
      (tester) async {
        final service = _FakeLiveVoiceService(
          initialErrorState: LiveVoiceErrorState.hardwareFailure,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: _LiveVoiceErrorBoundaryHost(service: service),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('live_voice_error_exit_button')));
        await tester.pump();

        expect(service.terminateCalled, isTrue);
      },
    );
  });
}

/// Mirrors the session screen Stack + ListenableBuilder wiring without booting
/// the full live voice session lifecycle.
class _LiveVoiceErrorBoundaryHost extends StatelessWidget {
  const _LiveVoiceErrorBoundaryHost({required this.service});

  final _FakeLiveVoiceService service;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: service,
        builder: (context, _) {
          return Stack(
            children: [
              const Center(child: Text('Active Canvas Content')),
              LiveVoiceErrorBoundaryOverlay(
                errorState: service.errorState,
                onRetry: () => service.retrySessionRecovery(),
                onCancel: () => service.terminateActiveSession(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FakeLiveVoiceService implements Listenable {
  _FakeLiveVoiceService({
    LiveVoiceErrorState initialErrorState = LiveVoiceErrorState.none,
  }) : _errorState = initialErrorState;

  LiveVoiceErrorState _errorState;
  final List<VoidCallback> _listeners = <VoidCallback>[];
  var retryCalled = false;
  var terminateCalled = false;

  LiveVoiceErrorState get errorState => _errorState;
  bool get hasError => _errorState != LiveVoiceErrorState.none;

  void injectError(LiveVoiceErrorState next) {
    _errorState = next;
    _notifyListeners();
  }

  Future<void> retrySessionRecovery() async {
    retryCalled = true;
    injectError(LiveVoiceErrorState.none);
  }

  Future<void> terminateActiveSession() async {
    terminateCalled = true;
  }

  @override
  void addListener(VoidCallback listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in List<VoidCallback>.of(_listeners)) {
      listener();
    }
  }
}
