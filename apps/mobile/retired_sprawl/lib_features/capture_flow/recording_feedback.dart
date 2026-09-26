import 'dart:convert';
import 'dart:io';

import 'package:archiveme_mobile/models/journal_entry.dart';

/// Pause-aware elapsed time for the capture timer.
///
/// The recorder's own duration keeps running through a pause on some
/// platforms, so the visible timer uses this clock instead.
class RecordingElapsedClock {
  RecordingElapsedClock({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  Duration _accumulated = Duration.zero;
  DateTime? _runningSince;
  bool _paused = false;

  bool get isPaused => _paused;

  void start() {
    _accumulated = Duration.zero;
    _runningSince = _now();
    _paused = false;
  }

  void pause() {
    final since = _runningSince;
    if (since == null || _paused) return;
    _accumulated += _now().difference(since);
    _runningSince = null;
    _paused = true;
  }

  void resume() {
    if (!_paused) return;
    _runningSince = _now();
    _paused = false;
  }

  Duration get elapsed {
    final since = _runningSince;
    if (since == null) return _accumulated;
    return _accumulated + _now().difference(since);
  }
}

/// Live bars plus a downsampled series stored beside the audio file.
class RecordingAmplitudeSeries {
  RecordingAmplitudeSeries({this.barCount = 40});

  static const sidecarSuffix = '.waveform.json';
  static const persistGap = Duration(milliseconds: 100);

  final int barCount;
  final List<double> persisted = [];
  DateTime? _lastPersistedAt;

  List<double> _bars = const [];

  List<double> get displayBars {
    if (_bars.length == barCount) return List<double>.unmodifiable(_bars);
    return List<double>.unmodifiable(
      List<double>.filled(barCount, 0)..setAll(
        barCount - _bars.length,
        _bars,
      ),
    );
  }

  static double normalizeDb(double db) {
    final clamped = db.clamp(-60.0, 0.0);
    return (clamped + 60) / 60;
  }

  void addDb(double db, {DateTime? at}) {
    final level = normalizeDb(db);
    final next = List<double>.from(displayBars);
    next.removeAt(0);
    next.add(level);
    _bars = next;
    final moment = at ?? DateTime.now();
    final last = _lastPersistedAt;
    if (last != null && moment.difference(last) < persistGap) return;
    persisted.add(level);
    _lastPersistedAt = moment;
  }

  static File sidecarFor(File audio) => File('${audio.path}$sidecarSuffix');

  Future<void> writeBeside(File audio) async {
    await sidecarFor(audio).writeAsString(jsonEncode(persisted));
  }

  static Future<List<double>> readBeside(File audio) async {
    final file = sidecarFor(audio);
    if (!await file.exists()) return const [];
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! List) return const [];
    return [
      for (final value in decoded)
        if (value is num) value.toDouble(),
    ];
  }
}

/// Live partials stay on screen. The saved transcript is the final pipeline.
abstract final class RecordingDraftPolicy {
  static String savedTranscript({
    required String pipelineTranscript,
    String? draft,
  }) {
    // [draft] is display-only. Returning it would stamp a partial as the
    // saved transcript.
    if (draft == pipelineTranscript && draft != null && draft.isEmpty) {
      return pipelineTranscript;
    }
    return pipelineTranscript;
  }

  static JournalEntry entryKeepingPipelineTranscript({
    required JournalEntry entry,
    String? draft,
  }) {
    final transcript = savedTranscript(
      pipelineTranscript: entry.transcript,
      draft: draft,
    );
    if (transcript == entry.transcript) return entry;
    return entry.copyWith(transcript: transcript);
  }
}
