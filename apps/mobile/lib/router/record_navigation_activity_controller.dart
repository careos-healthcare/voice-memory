import 'package:flutter/foundation.dart';

enum RecordNavigationActivity {
  idle,
  requestingPermission,
  recording,
  processing,
}

class RecordNavigationActivityController extends ChangeNotifier {
  RecordNavigationActivity _activity = RecordNavigationActivity.idle;
  bool _disposed = false;

  RecordNavigationActivity get activity => _activity;
  bool get isNavigationLocked =>
      _activity != RecordNavigationActivity.idle && !_disposed;

  void update(RecordNavigationActivity activity) {
    if (_disposed || activity == _activity) return;
    _activity = activity;
    notifyListeners();
  }

  void release() => update(RecordNavigationActivity.idle);

  @visibleForTesting
  void reset() {
    if (_disposed) return;
    release();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _activity = RecordNavigationActivity.idle;
    _disposed = true;
    super.dispose();
  }
}

final recordNavigationActivityController = RecordNavigationActivityController();
