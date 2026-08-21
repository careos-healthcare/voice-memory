import 'package:archiveme_mobile/router/primary_destination.dart';
import 'package:flutter/foundation.dart';

/// Announces primary branch activation without creating a second router.
class PrimaryNavigationController extends ChangeNotifier {
  PrimaryDestination _activeDestination = PrimaryDestination.record;
  int _revision = 0;

  PrimaryDestination get activeDestination => _activeDestination;
  int get revision => _revision;

  void activate(PrimaryDestination destination, {bool reselected = false}) {
    if (!reselected && destination == _activeDestination) return;
    _activeDestination = destination;
    _revision += 1;
    notifyListeners();
  }

  @visibleForTesting
  void reset() {
    _activeDestination = PrimaryDestination.record;
    _revision = 0;
    notifyListeners();
  }
}

final primaryNavigationController = PrimaryNavigationController();