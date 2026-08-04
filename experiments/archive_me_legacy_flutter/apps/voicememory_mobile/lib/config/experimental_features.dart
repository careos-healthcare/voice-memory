/// Compile-time V2 surface gate. Production V1 builds default to the focused
/// conversion path unless explicitly built with `--dart-define`.
const bool enableExperimentalFeatures = bool.fromEnvironment(
  'ENABLE_EXPERIMENTAL',
);
