import 'package:archiveme_mobile/router/primary_destination.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Selected bottom-tab destination. The timeline is the daily default.
class PrimaryNavigationNotifier extends Notifier<PrimaryDestination> {
  @override
  PrimaryDestination build() => PrimaryDestination.archive;

  void activate(PrimaryDestination destination, {bool reselected = false}) {
    if (!reselected && destination == state) return;
    state = destination;
  }
}

final primaryNavigationProvider =
    NotifierProvider<PrimaryNavigationNotifier, PrimaryDestination>(
      PrimaryNavigationNotifier.new,
    );
