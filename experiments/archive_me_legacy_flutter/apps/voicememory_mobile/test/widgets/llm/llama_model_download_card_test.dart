import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/widgets/llm/llama_model_download_card.dart';
import 'package:voicememory_mobile/widgets/llm/llama_model_download_copy.dart';

void main() {
  testWidgets('renders every model state and its expected control', (
    tester,
  ) async {
    final cases = <LlamaModelDownloadState, String?>{
      const LlamaModelDownloadState(
        status: LlamaModelDownloadStatus.notConfigured,
      ): null,
      const LlamaModelDownloadState(
        status: LlamaModelDownloadStatus.optInRequired,
      ): 'Download',
      const LlamaModelDownloadState(
        status: LlamaModelDownloadStatus.notInstalled,
      ): 'Download',
      const LlamaModelDownloadState(
        status: LlamaModelDownloadStatus.checkingStorage,
      ): null,
      const LlamaModelDownloadState(
        status: LlamaModelDownloadStatus.waitingForWifi,
      ): 'Pause',
      const LlamaModelDownloadState(
        status: LlamaModelDownloadStatus.downloading,
        progress: 0.42,
      ): 'Pause',
      const LlamaModelDownloadState(
        status: LlamaModelDownloadStatus.userPaused,
      ): 'Resume',
      const LlamaModelDownloadState(status: LlamaModelDownloadStatus.verifying):
          null,
      const LlamaModelDownloadState(status: LlamaModelDownloadStatus.ready):
          'Remove',
      const LlamaModelDownloadState(
        status: LlamaModelDownloadStatus.failed,
        failureDetail: 'Network unavailable.',
      ): 'Retry',
    };

    for (final entry in cases.entries) {
      final controller = _FakeController(entry.key);
      await tester.pumpWidget(_harness(controller: controller));

      expect(
        find.byKey(const Key('llama_model_download_card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('llama_model_download_source_test')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('llama_model_download_status')),
        findsOneWidget,
      );
      final expectedStatus = switch (entry.key.status) {
        LlamaModelDownloadStatus.notConfigured =>
          LlamaModelDownloadCopy.notConfigured,
        LlamaModelDownloadStatus.optInRequired ||
        LlamaModelDownloadStatus.notInstalled =>
          LlamaModelDownloadCopy.optInRequired,
        LlamaModelDownloadStatus.checkingStorage =>
          LlamaModelDownloadCopy.checkingStorage,
        LlamaModelDownloadStatus.waitingForWifi =>
          LlamaModelDownloadCopy.waitingForWifi,
        LlamaModelDownloadStatus.downloading =>
          LlamaModelDownloadCopy.downloading(42),
        LlamaModelDownloadStatus.userPaused =>
          LlamaModelDownloadCopy.userPaused,
        LlamaModelDownloadStatus.verifying => LlamaModelDownloadCopy.verifying,
        LlamaModelDownloadStatus.ready => LlamaModelDownloadCopy.ready,
        LlamaModelDownloadStatus.failed => LlamaModelDownloadCopy.failed,
      };
      expect(find.text(expectedStatus), findsOneWidget);
      if (entry.value == null) {
        expect(
          find.byKey(const Key('llama_model_download_action')),
          findsNothing,
        );
      } else {
        expect(find.text(entry.value!), findsOneWidget);
        expect(
          find.byKey(const Key('llama_model_download_action')),
          findsOneWidget,
        );
      }

      final expectsProgress =
          entry.key.status == LlamaModelDownloadStatus.downloading;
      expect(
        find.byKey(const Key('llama_model_download_progress')),
        expectsProgress ? findsOneWidget : findsNothing,
      );
    }
  });

  testWidgets('invokes download pause resume retry and remove', (tester) async {
    final actions = <LlamaModelDownloadStatus, String>{
      LlamaModelDownloadStatus.optInRequired: 'download',
      LlamaModelDownloadStatus.waitingForWifi: 'pause',
      LlamaModelDownloadStatus.downloading: 'pause',
      LlamaModelDownloadStatus.userPaused: 'resume',
      LlamaModelDownloadStatus.failed: 'retry',
      LlamaModelDownloadStatus.ready: 'remove',
    };

    for (final entry in actions.entries) {
      final controller = _FakeController(
        LlamaModelDownloadState(status: entry.key, progress: 0.25),
      );
      await tester.pumpWidget(_harness(controller: controller));
      await tester.tap(find.byKey(const Key('llama_model_download_action')));
      await tester.pump();
      expect(controller.calls, [entry.value]);
    }
  });

  testWidgets('announces status and determinate progress as live semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final controller = _FakeController(
      const LlamaModelDownloadState(
        status: LlamaModelDownloadStatus.downloading,
        progress: 0.42,
      ),
    );

    await tester.pumpWidget(_harness(controller: controller));

    expect(
      tester.getSemantics(find.byKey(const Key('llama_model_download_status'))),
      matchesSemantics(
        label: 'Model download status. Downloading · 42%',
        isLiveRegion: true,
      ),
    );
    expect(
      tester.getSemantics(
        find.byKey(const Key('llama_model_download_progress')),
      ),
      matchesSemantics(label: 'Model download progress', value: '42%'),
    );
    expect(
      tester.getSemantics(find.text(LlamaModelDownloadCopy.title)),
      matchesSemantics(label: LlamaModelDownloadCopy.title, isHeader: true),
    );
    semantics.dispose();
  });

  testWidgets('exposes an actionable, labelled semantic button', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final controller = _FakeController(
      const LlamaModelDownloadState(
        status: LlamaModelDownloadStatus.optInRequired,
      ),
    );

    await tester.pumpWidget(_harness(controller: controller));

    expect(
      tester.getSemantics(find.byKey(const Key('llama_model_download_action'))),
      matchesSemantics(
        label: 'Download',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('updates locally from injected controller stream', (
    tester,
  ) async {
    final controller = _FakeController(
      const LlamaModelDownloadState(
        status: LlamaModelDownloadStatus.optInRequired,
      ),
    );
    await tester.pumpWidget(_harness(controller: controller));

    controller.emit(
      const LlamaModelDownloadState(
        status: LlamaModelDownloadStatus.ready,
        progress: 1,
      ),
    );
    await tester.pump();

    expect(find.text(LlamaModelDownloadCopy.ready), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);
  });

  testWidgets('accepts a card-local Riverpod provider adapter', (tester) async {
    final controller = _FakeController(
      const LlamaModelDownloadState(
        status: LlamaModelDownloadStatus.userPaused,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: LlamaModelDownloadCard(providerAdapter: (ref) => controller),
          ),
        ),
      ),
    );

    expect(find.text('Resume'), findsOneWidget);
  });

  testWidgets('shows privacy size Wi-Fi removal and attribution copy', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(controller: null));

    expect(find.textContaining('about 1 GB'), findsOneWidget);
    expect(find.textContaining('locally'), findsOneWidget);
    expect(find.textContaining('Wi-Fi only'), findsOneWidget);
    expect(find.textContaining('removed at any time'), findsOneWidget);
    expect(find.textContaining('Qwen2.5'), findsOneWidget);
    expect(find.textContaining('Apache-2.0'), findsOneWidget);
  });
}

Widget _harness({required LlamaModelDownloadController? controller}) =>
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LlamaModelDownloadCard(
              controller: controller,
              source: 'test',
            ),
          ),
        ),
      ),
    );

final class _FakeController implements LlamaModelDownloadController {
  _FakeController(this._state);

  final _states = StreamController<LlamaModelDownloadState>.broadcast();
  final List<String> calls = [];
  LlamaModelDownloadState _state;

  @override
  LlamaModelDownloadState get state => _state;

  @override
  Stream<LlamaModelDownloadState> get states => _states.stream;

  void emit(LlamaModelDownloadState state) {
    _state = state;
    _states.add(state);
  }

  @override
  Future<void> download() async => calls.add('download');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> remove() async => calls.add('remove');

  @override
  Future<void> resume() async => calls.add('resume');

  @override
  Future<void> retry() async => calls.add('retry');
}
