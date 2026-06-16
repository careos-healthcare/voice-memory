import '../../services/activation_funnel_analytics.dart';
import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import 'referral_invite_after_value.dart';

/// A parsed invite attribution: the fixed referral channel plus a
/// whitelisted source id. Nothing else can be carried.
class InviteAttribution {
  const InviteAttribution({required this.ref, required this.source});

  /// Always [ReferralInviteAfterValue.inviteRef] — anything else fails the
  /// parse.
  final String ref;

  /// One of [ReferralInviteAfterValue.stableSources] or `default`.
  final String source;
}

/// Invite Attribution Link — parses `/invite?ref=archive_invite&source=...`
/// deep links and persists the first-touch invite source locally.
///
/// Privacy by construction:
/// - Only `ref` and `source` are ever read from the URI; every other query
///   parameter is ignored.
/// - `ref` must equal the fixed channel id or the link is not an invite.
/// - `source` is clamped to the stable whitelist; unknown values become
///   `default` — no user text, ids, or counts can be persisted or logged.
abstract class InviteAttributionLink {
  InviteAttributionLink._();

  /// Parses an invite URI. Returns null when the path is not `/invite` or
  /// the ref is not the fixed invite channel.
  static InviteAttribution? parse(Uri uri) {
    if (uri.path != '/invite') return null;
    if (uri.queryParameters['ref'] != ReferralInviteAfterValue.inviteRef) {
      return null;
    }
    return InviteAttribution(
      ref: ReferralInviteAfterValue.inviteRef,
      source: ReferralInviteAfterValue.linkSource(
        uri.queryParameters['source'] ?? '',
      ),
    );
  }

  /// Router entry point: records attribution (first-touch) and sends the
  /// user on to the normal app entry. Never blocks or fails navigation.
  static Future<String> resolveInviteRedirect(
    Uri uri, {
    InviteAttributionStore? store,
  }) async {
    final attribution = parse(uri);
    if (attribution != null) {
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.inviteAttributionReceived,
        source: attribution.source,
        ref: attribution.ref,
      );
      try {
        await (store ?? InviteAttributionStore()).recordFirstTouch(attribution);
      } catch (_) {
        // Attribution must never break the open path.
      }
    }
    return '/record';
  }
}

/// Local first-touch persistence for the invite source. Stores only the
/// fixed ref and a whitelisted source id; later invite opens never
/// overwrite the first one.
class InviteAttributionStore {
  InviteAttributionStore({MobilePrefsStore? prefs}) : _prefs = prefs;

  final MobilePrefsStore? _prefs;

  static const String prefsKey = 'invite_attribution';

  MobilePrefsStore? get _resolvedPrefs {
    if (_prefs != null) return _prefs;
    if (!AppServices.isInitialized) return null;
    return AppServices.instance.prefs;
  }

  /// Persists the attribution if none exists yet. Returns true when this
  /// was the first touch.
  Future<bool> recordFirstTouch(InviteAttribution attribution) async {
    final prefs = _resolvedPrefs;
    if (prefs == null) return false;
    try {
      if (await prefs.readMap(prefsKey) != null) return false;
      await prefs.writeMap(prefsKey, {
        'ref': attribution.ref,
        'source': ReferralInviteAfterValue.linkSource(attribution.source),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// The persisted first-touch attribution, or null when none exists or
  /// the stored record is malformed.
  Future<InviteAttribution?> firstTouch() async {
    final prefs = _resolvedPrefs;
    if (prefs == null) return null;
    try {
      final data = await prefs.readMap(prefsKey);
      if (data == null) return null;
      final ref = data['ref'];
      final source = data['source'];
      if (ref != ReferralInviteAfterValue.inviteRef || source is! String) {
        return null;
      }
      return InviteAttribution(
        ref: ReferralInviteAfterValue.inviteRef,
        source: ReferralInviteAfterValue.linkSource(source),
      );
    } catch (_) {
      return null;
    }
  }
}
