import 'package:archiveme_mobile/features/onboarding/record_return_pro_state.dart';

/// Pro / return-bridge snapshot for record-surface resolution.
final class RecordUserProState {
  const RecordUserProState({
    required this.recordReturnProState,
    required this.isPro,
  });

  final RecordReturnProState? recordReturnProState;
  final bool isPro;

  @override
  bool operator ==(Object other) {
    return other is RecordUserProState &&
        other.recordReturnProState == recordReturnProState &&
        other.isPro == isPro;
  }

  @override
  int get hashCode => Object.hash(recordReturnProState, isPro);
}