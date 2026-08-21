/// Dart mirror of `@voice-memory/shared` [LifeStageLens] — wire values must
/// stay aligned with `packages/shared/types/user-context.ts`.
enum LifeStageLens {
  defaultLens,
  newParent,
  careerTransition,
  recovery,
  griefLoss,
}

extension LifeStageLensWire on LifeStageLens {
  String get wireValue => switch (this) {
        LifeStageLens.defaultLens => 'default',
        LifeStageLens.newParent => 'newParent',
        LifeStageLens.careerTransition => 'careerTransition',
        LifeStageLens.recovery => 'recovery',
        LifeStageLens.griefLoss => 'griefLoss',
      };

  static LifeStageLens? fromWire(String? raw) => switch (raw) {
        'default' || null || '' => LifeStageLens.defaultLens,
        'newParent' => LifeStageLens.newParent,
        'careerTransition' => LifeStageLens.careerTransition,
        'recovery' => LifeStageLens.recovery,
        'griefLoss' => LifeStageLens.griefLoss,
        _ => null,
      };

  bool get isThematic => this != LifeStageLens.defaultLens;
}