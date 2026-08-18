import 'package:archiveme_mobile/features/archive_theory/theory_tracker_models.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Tracks discover/theories visits after first working theory (web parity).
abstract final class EvolvingUnderstandingReturnCoordinator {
  EvolvingUnderstandingReturnCoordinator._();

  static const _stateKey = 'evolving_understanding_state_v1';
  static const _returnWindow = Duration(hours: 24);

  static Future<void> onTheoriesVisit() async {
    if (!AppServices.isInitialized) return;
    final prefs = AppServices.instance.prefs;
    final state = await _readState(prefs);
    if (state.returnedTracked) return;

    final firstSeen = state.firstWorkingTheorySeenAt;
    if (firstSeen == null) return;

    if (DateTime.now().toUtc().difference(firstSeen) <= _returnWindow) {
      await prefs.writeJsonMap(_stateKey, {
        ...state.toJson(),
        'returnedTracked': true,
        'returnedAt': DateTime.now().toUtc().toIso8601String(),
        'route': 'theories',
      });
    }
  }

  static Future<void> recordFirstWorkingTheoryIfNeeded(
    TheoryTrackerReport report,
  ) async {
    if (!AppServices.isInitialized || report.all.isEmpty) return;
    final prefs = AppServices.instance.prefs;
    final state = await _readState(prefs);
    if (state.firstWorkingTheorySeenAt != null) return;

    await prefs.writeJsonMap(_stateKey, {
      ...state.toJson(),
      'firstWorkingTheorySeenAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  static Future<_EvolvingState> _readState(MobilePrefsStore prefs) async {
    final raw = await prefs.readJsonMap(_stateKey);
    if (raw == null) return const _EvolvingState();
    return _EvolvingState(
      firstWorkingTheorySeenAt: DateTime.tryParse(
        raw['firstWorkingTheorySeenAt'] as String? ?? '',
      )?.toUtc(),
      returnedTracked: raw['returnedTracked'] == true,
    );
  }
}

class _EvolvingState {
  const _EvolvingState({
    this.firstWorkingTheorySeenAt,
    this.returnedTracked = false,
  });

  final DateTime? firstWorkingTheorySeenAt;
  final bool returnedTracked;

  Map<String, dynamic> toJson() => {
    if (firstWorkingTheorySeenAt != null)
      'firstWorkingTheorySeenAt':
          firstWorkingTheorySeenAt!.toUtc().toIso8601String(),
    'returnedTracked': returnedTracked,
  };
}