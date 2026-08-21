import 'package:flutter/foundation.dart';

/// Compile-time gate for Gemini live conversation on Record.
///
/// Enable with:
/// `--dart-define=VOICEMEMORY_ENABLE_LIVE_CONVERSATION=true`
///
/// Legacy alias: `--dart-define=ENABLE_LIVE_VOICE_CAPTURE=true`
abstract final class LiveConversationFeatureFlags {
  LiveConversationFeatureFlags._();

  static const bool _fromPrimaryDefine = bool.fromEnvironment(
    'VOICEMEMORY_ENABLE_LIVE_CONVERSATION',
  );

  static const bool _fromLegacyDefine = bool.fromEnvironment(
    'ENABLE_LIVE_VOICE_CAPTURE',
  );

  @visibleForTesting
  static bool? debugOverride;

  static bool get enabled =>
      debugOverride ?? (_fromPrimaryDefine || _fromLegacyDefine);
}