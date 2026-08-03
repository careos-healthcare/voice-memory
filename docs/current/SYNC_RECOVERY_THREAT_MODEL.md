# Sync recovery threat model

## Security goal

Recovery restores the existing random 32-byte sync data key to another device
without giving the server that key or the recovery secret. It does not change
the encryption of synced records and is not an end-to-end-encryption claim.

## Design

- The client generates the sync key and a separate 256-bit recovery secret with
  the operating system cryptographic random source.
- PBKDF2-HMAC-SHA256 with 310,000 iterations and a random 128-bit salt derives a
  256-bit wrapping key. AES-256-GCM wraps the sync key with a random 96-bit
  nonce.
- The schema, KDF and iteration count, algorithm, account id, archive id, data
  key epoch, monotonic envelope revision, and timestamps are additional
  authenticated data.
- The server stores ciphertext, salt, nonce, authentication tag, and
  authenticated metadata only. It scopes reads and writes to the active
  session, rate-limits operations, and rejects stale and conflicting revisions.
- Replacing a recovery code rewraps the same data key. It does not rotate the
  data key or require re-encryption of the archive.

## Threats and controls

- **Server/database compromise:** an attacker gets an offline password-guessing
  target, but the recovery secret has 256 random bits rather than
  user-selected entropy. The plaintext sync key and secret are absent.
- **Envelope tampering:** AES-GCM authentication fails before a key is
  installed. All security-relevant metadata is authenticated.
- **Cross-account/archive substitution:** both server ownership and client AAD
  binding must match. On a new device, the authenticated envelope's archive id
  is adopted only after successful unwrap while the same account remains active.
- **Replay:** the server accepts only a higher envelope revision, or the exact
  same envelope idempotently. The client can require a minimum revision.
- **Wrong or partial code:** strict decoding and authenticated decryption fail
  closed. No candidate key is installed.
- **Account switch during recovery:** identity is checked before and after the
  network operation and immediately before installation.
- **Storage loss:** recovery works only when an envelope exists and the user has
  retained the one-time code. Otherwise loss remains permanent.
- **Leakage through secondary systems:** the code is never submitted to the
  backend, persisted by the app, added to analytics/crash reports, or included
  in archive exports. API handlers do not log request bodies or envelope fields.
- **Deletion:** disabling recovery deletes only the wrapping envelope. Account
  deletion removes the envelope, synced ciphertext, and local key through their
  respective deletion paths.

## Residual limitations

- A compromised unlocked client can read the local sync key and any code the
  user pastes into that process.
- A user can expose the one-time code through screenshots, clipboard history,
  insecure notes, or sharing. The app cannot revoke copies already made.
- PBKDF2 cost is a defense-in-depth control; security primarily comes from the
  randomly generated high-entropy code.
- Rate limiting is per application instance. Distributed deployments should
  enforce an additional shared edge or datastore limit.
- Key epoch 1 is the only supported data-key epoch. Recovery-code replacement
  does not claim full data-key rotation.
- Availability of server ciphertext is not guaranteed by encryption. Users
  should retain exports separately, and exports deliberately omit the code.
