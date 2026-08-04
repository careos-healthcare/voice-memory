import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/whispering_vault/audio_graph_mapper.dart';
import 'package:voicememory_mobile/features/whispering_vault/ui/whispering_vault_sheet.dart';
import 'package:voicememory_mobile/features/whispering_vault/whispering_vault_controller.dart';

void main() {
  testWidgets('recording waveform transitions into navigable transcript', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = _FakeWhisperingVaultModel();
    String? selectedNode;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WhisperingVaultSheet(
            controller: model,
            onNodeSelected: (nodeId) => selectedNode = nodeId,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('whisper-waveform')), findsOneWidget);
    expect(find.text('Ready for an air-gapped reflection'), findsOneWidget);

    await tester.tap(find.byKey(const Key('whisper-record-toggle')));
    await tester.pump();
    expect(find.text('Listening and transcribing locally…'), findsOneWidget);
    expect(
      find.byKey(const Key('whisper-progressive-transcript')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('whisper-record-toggle')));
    await tester.pump();
    expect(find.text('Encrypted reflection ready'), findsOneWidget);
    expect(find.byKey(const Key('whisper-playback-toggle')), findsOneWidget);

    await tester.tap(find.byKey(const Key('whisper-sentence-node-1')));
    expect(selectedNode, 'node-1');

    await tester.tap(find.byKey(const Key('whisper-speed-1.5x')));
    await tester.pump();
    expect(model.playbackRate, 1.5);
  });
}

final class _FakeWhisperingVaultModel extends ChangeNotifier
    implements WhisperingVaultViewModel {
  @override
  WhisperingVaultState state = WhisperingVaultState.idle;
  @override
  String transcript = '';
  @override
  String? errorMessage;
  @override
  List<double> waveform = const [];
  @override
  AudioGraphMapping? mapping;
  @override
  bool isPlaying = false;
  @override
  double playbackRate = 1;

  @override
  Future<void> toggleRecording() async {
    if (state == WhisperingVaultState.idle) {
      state = WhisperingVaultState.recording;
      transcript = 'A progressive offline thought';
      waveform = const [.2, .5, .8, .4];
    } else {
      state = WhisperingVaultState.ready;
      transcript = 'A progressive offline thought.';
      mapping = AudioGraphMapping(
        audioId: 'audio',
        nodes: const [],
        edges: const [],
        clusterIds: const ['voice'],
        transcriptNodes: const [
          AudioTranscriptNode(
            sentence: 'A progressive offline thought.',
            nodeId: 'node-1',
            startUtf16: 0,
            endUtf16: 30,
          ),
        ],
        emotionalValence: .2,
      );
    }
    notifyListeners();
  }

  @override
  Future<void> togglePlayback() async {
    isPlaying = !isPlaying;
    notifyListeners();
  }

  @override
  Future<void> setPlaybackRate(double rate) async {
    playbackRate = rate;
    notifyListeners();
  }
}
