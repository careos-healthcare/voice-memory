import 'dart:collection';

/// Queue + barge-in generation semantics for live PCM chunk playback.
///
/// Audio I/O stays in [PlaybackService]; this class owns pending chunks and
/// invalidation when [flush] is called (e.g. server barge-in).
class PcmChunkQueueDriver {
  final Queue<List<int>> _pending = Queue<List<int>>();
  var _flushGeneration = 0;
  var _playing = false;
  var _disposed = false;

  int get flushGeneration => _flushGeneration;

  int get queueDepth => _pending.length;

  /// Pending chunks plus the chunk currently playing.
  int get activeQueueDepth => _pending.length + (_playing ? 1 : 0);

  bool get isDisposed => _disposed;

  bool isGenerationCurrent(int generation) => generation == _flushGeneration;

  void setPlaying(bool playing) {
    _playing = playing;
  }

  void enqueue(List<int> pcmBytes) {
    if (_disposed || pcmBytes.isEmpty) return;
    _pending.add(List<int>.from(pcmBytes));
  }

  /// Removes the next chunk when [generation] is still current.
  List<int>? dequeue(int generation) {
    if (_disposed || !isGenerationCurrent(generation) || _pending.isEmpty) {
      return null;
    }
    return _pending.removeFirst();
  }

  /// Drops queued chunks and invalidates any in-flight drain loop.
  void flush() {
    _flushGeneration++;
    _pending.clear();
    _playing = false;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _pending.clear();
    _playing = false;
  }
}
