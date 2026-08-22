import 'package:archiveme_mobile/core/user/life_stage_lens.dart';

/// Global user preferences — device-local until synced settings ship.
class UserSettings {
  const UserSettings({this.activeLens});

  factory UserSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const UserSettings();
    }
    final lens = LifeStageLensWire.fromWire(json['activeLens']?.toString());
    if (lens == null || lens == LifeStageLens.defaultLens) {
      return const UserSettings();
    }
    return UserSettings(activeLens: lens);
  }

  final LifeStageLens? activeLens;

  LifeStageLens get resolvedLens => activeLens ?? LifeStageLens.defaultLens;

  UserSettings copyWith({LifeStageLens? activeLens, bool clearActiveLens = false}) {
    return UserSettings(
      activeLens: clearActiveLens ? null : (activeLens ?? this.activeLens),
    );
  }

  Map<String, dynamic> toJson() => {
        if (activeLens != null && activeLens!.isThematic)
          'activeLens': activeLens!.wireValue,
      };
}