import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter/foundation.dart';

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