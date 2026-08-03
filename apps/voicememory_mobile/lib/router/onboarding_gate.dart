import 'package:flutter/foundation.dart';

import '../services/app_services.dart';

/// Drives GoRouter redirect until first-run onboarding is complete.
class OnboardingGate extends ChangeNotifier {
  bool _complete = false;
  bool _archiveHomeRedirectApplied = false;

  bool get complete => _complete;

  bool get archiveHomeRedirectApplied => _archiveHomeRedirectApplied;

  void markArchiveHomeRedirectApplied() {
    _archiveHomeRedirectApplied = true;
  }

  /// Test-only reset for widget/integration tests.
  void resetForTest({bool complete = false}) {
    _complete = complete;
    _archiveHomeRedirectApplied = false;
    notifyListeners();
  }

  void resetSessionRedirectsForTest() {
    _archiveHomeRedirectApplied = false;
  }

  Future<void> refresh() async {
    _complete = await AppServices.instance.prefs.onboardingCompleted;
    notifyListeners();
  }

  void markComplete() {
    _complete = true;
    notifyListeners();
  }
}

final onboardingGate = OnboardingGate();
