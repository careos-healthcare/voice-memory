/// Typed payload embedded in curiosity loop notification taps.
abstract final class CuriosityNotificationPayload {
  CuriosityNotificationPayload._();

  static const _prefix = 'curiosity_hook_v1:';

  static String encode(String hookId) {
    final trimmed = hookId.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(hookId, 'hookId', 'must not be empty');
    }
    return '$_prefix$trimmed';
  }

  static String? decodeHookId(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    if (!payload.startsWith(_prefix)) return null;
    final hookId = payload.substring(_prefix.length).trim();
    return hookId.isEmpty ? null : hookId;
  }
}
