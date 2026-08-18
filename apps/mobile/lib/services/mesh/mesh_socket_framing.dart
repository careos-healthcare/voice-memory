import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Reads a single newline-delimited frame from [socket].
Future<String> readSocketLine(
  Socket socket, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final buffer = StringBuffer();
  final completer = Completer<String>();
  late StreamSubscription<List<int>> subscription;

  subscription = socket.listen(
    (data) {
      buffer.write(utf8.decode(data));
      final text = buffer.toString();
      final newlineIndex = text.indexOf('\n');
      if (newlineIndex >= 0) {
        unawaited(subscription.cancel());
        if (!completer.isCompleted) {
          completer.complete(text.substring(0, newlineIndex));
        }
      }
    },
    onDone: () {
      if (!completer.isCompleted) {
        completer.complete(buffer.toString());
      }
    },
    onError: (Object error, StackTrace stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    },
    cancelOnError: true,
  );

  return completer.future.timeout(timeout);
}
