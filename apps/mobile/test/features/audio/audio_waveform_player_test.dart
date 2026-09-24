import 'dart:typed_data';

import 'package:archiveme_mobile/features/audio/pitch_preserving_playback.dart';
import 'package:archiveme_mobile/features/audio/waveform_picture.dart';
import 'package:archiveme_mobile/features/audio/widgets/interactive_audio_player_bar.dart';
import 'package:archiveme_mobile/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pcm peaks normalize against the loudest bar', () {
    final bytes = ByteData(8)
      ..setInt16(0, 1000, Endian.little)
      ..setInt16(2, 1000, Endian.little)
      ..setInt16(4, 20000, Endian.little)
      ..setInt16(6, 20000, Endian.little);

    final bars = amplitudesFromPcm(bytes.buffer.asUint8List(), barCount: 2);

    expect(bars, hasLength(2));
    expect(bars[1], 1);
    expect(bars[0], closeTo(1000 / 20000, 0.001));
  });

  test('speech windows invert into sherpa pause gaps', () {
    final gaps = silencesFromSpeech(const [
      WaveformSilence(start: 0.2, end: 0.8),
    ]);

    expect(gaps.map((gap) => (gap.start, gap.end)), [
      (0.0, 0.2),
      (0.8, 1.0),
    ]);
  });

  test('skip silence jumps to the end of the current pause', () {
    const pauses = [WaveformSilence(start: 0.2, end: 0.5)];

    expect(
      skipSilenceTarget(position: 0.3, silences: pauses, enabled: true),
      0.5,
    );
    expect(
      skipSilenceTarget(position: 0.3, silences: pauses, enabled: false),
      isNull,
    );
    expect(
      skipSilenceTarget(position: 0.5, silences: pauses, enabled: true),
      isNull,
    );
  });

  test('bars use green, blue, amber, and red for stored tone', () {
    expect(
      waveformBarColor(WaveformTone.positive, silent: false),
      const Color(0xFF15803D),
    );
    expect(
      waveformBarColor(WaveformTone.neutral, silent: false),
      AppTokens.primary600,
    );
    expect(
      waveformBarColor(WaveformTone.tension, silent: false),
      const Color(0xFFD97706),
    );
    expect(
      waveformBarColor(WaveformTone.highTension, silent: false),
      const Color(0xFFDC2626),
    );
    expect(
      waveformBarColor(WaveformTone.positive, silent: true),
      AppTokens.neutral300,
    );
  });

  test('pause handles are touchable around the silence start', () {
    const geometry = WaveformGeometry(size: Size(200, 96), barCount: 4);
    const silence = WaveformSilence(start: 0.25, end: 0.4);

    expect(geometry.handleAt(const Offset(50, 48), const [silence]), 0);
    expect(geometry.handleAt(const Offset(120, 48), const [silence]), isNull);
    expect(geometry.fractionAt(100), 0.5);
  });

  test('speed changes stay at the preserved pitch', () async {
    final rates = <double>[];
    final transport = PitchPreservingTransport(
      setRate: (speed) async => rates.add(speed),
      seekTo: (_) async {},
    );

    await transport.setSpeed(1.25);

    expect(rates, [1.25]);
    expect(PitchPreservingPlayback.preservedPitch, 1);
    expect(PitchPreservingPlayback.speeds, [1, 1.25, 1.5, 2]);
    expect(PitchPreservingPlayback.label(1), '1.0x');
    expect(PitchPreservingPlayback.label(1.25), '1.25x');
    expect(PitchPreservingPlayback.label(1.5), '1.5x');
    expect(PitchPreservingPlayback.label(2), '2.0x');
    expect(() => transport.setSpeed(3), throwsArgumentError);
  });

  testWidgets('drag, speed, and skip silence drive the player bar', (
    tester,
  ) async {
    final seeks = <double>[];
    final rates = <double>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _PlayerHost(
            seeks: seeks,
            rates: rates,
          ),
        ),
      ),
    );

    final box = tester.getRect(
      find.byKey(const Key('audio_waveform_visualizer')),
    );
    await tester.tapAt(box.centerLeft + Offset(box.width * 0.1, 0));
    await tester.pump();
    expect(seeks.last, closeTo(0.1, 0.02));

    await tester.dragFrom(box.centerLeft, Offset(box.width * 0.6, 0));
    await tester.pump();
    expect(seeks.last, greaterThan(0.4));

    await tester.tap(find.byKey(const Key('audio_speed_1_5')));
    await tester.pump();
    expect(rates, [1.5]);
    expect(find.text('1.0x'), findsOneWidget);
    expect(find.text('2.0x'), findsOneWidget);
    expect(find.text('Skip Silence'), findsOneWidget);
  });

  testWidgets('skip silence jumps past a sherpa pause during playback', (
    tester,
  ) async {
    final seeks = <double>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _PlayerHost(
            seeks: seeks,
            rates: const [],
            initialPosition: 0.3,
            silences: const [WaveformSilence(start: 0.2, end: 0.5)],
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('audio_skip_silence')));
    await tester.pump();
    await tester.pump();

    expect(seeks, [0.5]);
  });
}

class _PlayerHost extends StatefulWidget {
  const _PlayerHost({
    required this.seeks,
    required this.rates,
    this.initialPosition = 0,
    this.silences = const [WaveformSilence(start: 0.1, end: 0.2)],
  });

  final List<double> seeks;
  final List<double> rates;
  final double initialPosition;
  final List<WaveformSilence> silences;

  @override
  State<_PlayerHost> createState() => _PlayerHostState();
}

class _PlayerHostState extends State<_PlayerHost> {
  double position = 0;
  double speed = 1;
  bool skipSilence = false;

  @override
  void initState() {
    super.initState();
    position = widget.initialPosition;
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveAudioPlayerBar(
      picture: WaveformPicture(
        amplitudes: const [0.2, 0.8, 0.1, 0.6],
        tones: const [
          WaveformToneSpan(start: 0, end: 0.25, tone: WaveformTone.positive),
          WaveformToneSpan(start: 0.25, end: 0.5, tone: WaveformTone.neutral),
          WaveformToneSpan(start: 0.5, end: 0.75, tone: WaveformTone.tension),
          WaveformToneSpan(
            start: 0.75,
            end: 1,
            tone: WaveformTone.highTension,
          ),
        ],
        silences: widget.silences,
      ),
      position: position,
      speed: speed,
      skipSilence: skipSilence,
      onSeek: (fraction) => setState(() {
        position = fraction;
        widget.seeks.add(fraction);
      }),
      onSpeed: (value) => setState(() => speed = value),
      onSkipSilence: (value) => setState(() => skipSilence = value),
      transport: PitchPreservingTransport(
        setRate: (value) async => widget.rates.add(value),
        seekTo: (_) async {},
      ),
    );
  }
}
