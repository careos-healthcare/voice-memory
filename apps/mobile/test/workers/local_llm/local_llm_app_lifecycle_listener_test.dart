import 'dart:async';

import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/workers/isolate_worker_client.dart';
import 'package:archiveme_mobile/workers/local_llm/local_llm_app_lifecycle_listener.dart';
import 'package:archiveme_mobile/workers/local_llm/local_llm_worker_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IsolateWorkerControlOperations', () {
    test('cancel ack response completes pending dispatch', () async {
      final client = LocalLlmWorkerService.instance;
      const requestId = 42;
      final completer = client.pending[requestId] = Completer<Object?>();

      client.handleWorkerResponse(
        IsolateWorkerResponse(
          requestId: requestId,
          controlSignal: IsolateWorkerControlSignals.cancelAcknowledged,
        ).toJson(),
      );

      expect(
        await completer.future,
        IsolateWorkerControlSignals.cancelAcknowledged,
      );
      expect(client.pending.containsKey(requestId), isFalse);
    });
  });

  group('LocalLlmWorkerService', () {
    test('unloadModelForBackground notifies listeners without blocking', () {
      final service = LocalLlmWorkerService.instance;
      var unloadNotified = false;
      service.addModelUnloadedListener(() => unloadNotified = true);

      service.unloadModelForBackground();

      expect(unloadNotified, isTrue);
    });
  });

  group('LocalLlmAppLifecycleListener', () {
    testWidgets('handles paused lifecycle without throwing', (tester) async {
      await tester.pumpWidget(
        const LocalLlmAppLifecycleListener(
          child: SizedBox.shrink(),
        ),
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      expect(AppServices.releaseLocalLlmMemoryForBackground, returnsNormally);
    });
  });
}
