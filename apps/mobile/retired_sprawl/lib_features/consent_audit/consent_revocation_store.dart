/// Re-export of the single [ConsentRevocationStore].
///
/// This file used to declare its own byte-identical copy of the class. Static
/// fields are per-class, so the caregiver/coach verification path and
/// `MultiPartyAccessService` each kept a private `_revoked` set while
/// persisting a whole-set snapshot to the same `consent_revoked_tokens_v1`
/// key: revoking through one path overwrote revocations recorded by the other,
/// silently reinstating access the user had withdrawn.
///
/// Re-exporting keeps every existing `features/consent_audit/…` import working
/// while collapsing the two classes into one, so no migration of stored data is
/// needed — the key, its JSON shape, and its owner are unchanged.
export 'package:archiveme_mobile/features/auth/infrastructure/consent_revocation_store.dart';
