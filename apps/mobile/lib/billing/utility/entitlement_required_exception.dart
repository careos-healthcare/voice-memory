/// A utility action that is outside the free journaling and local-search path.
enum UtilityLimit { exportArchive, cloudLlm, mediaStorage }

/// Thrown when a free quota or a Pro-only utility is used up.
class EntitlementRequiredException implements Exception {
  const EntitlementRequiredException(this.limit);

  final UtilityLimit limit;

  @override
  String toString() => 'EntitlementRequiredException(${limit.name})';
}
