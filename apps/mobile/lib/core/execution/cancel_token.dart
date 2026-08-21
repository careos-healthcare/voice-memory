/// Cooperative cancellation for long-running local operations (LLM, sync batches).
class ExecutionCancelToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;

  void throwIfCancelled() {
    if (_cancelled) {
      throw ExecutionCancelledException();
    }
  }
}

/// Thrown when an [ExecutionCancelToken] is cancelled mid-flight.
final class ExecutionCancelledException implements Exception {
  @override
  String toString() => 'ExecutionCancelledException';
}
