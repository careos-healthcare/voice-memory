import 'dart:convert';

import 'package:crypto/crypto.dart';

/// What to do with one note before it is written into the vault.
enum ObsidianVaultPush {
  /// Local note is new, or the vault copy is still our last push.
  write,

  /// Vault bytes already match the local note.
  skipDuplicate,

  /// The vault copy changed outside this export. Leave it in place.
  keepVault,
}

/// Compares a local Obsidian note with the file already in the vault.
///
/// The comparison uses content hashes. A vault edit is never overwritten,
/// and an unchanged note is not written again.
abstract final class ObsidianVaultDiff {
  ObsidianVaultDiff._();

  static String hashOf(String markdown) =>
      sha256.convert(utf8.encode(markdown)).toString();

  static ObsidianVaultPush resolve({
    required String localMarkdown,
    required String? vaultMarkdown,
    required String? lastPushedHash,
  }) {
    if (vaultMarkdown == null) return ObsidianVaultPush.write;
    final localHash = hashOf(localMarkdown);
    final vaultHash = hashOf(vaultMarkdown);
    if (vaultHash == localHash) return ObsidianVaultPush.skipDuplicate;
    if (lastPushedHash == null || lastPushedHash == vaultHash) {
      return ObsidianVaultPush.write;
    }
    return ObsidianVaultPush.keepVault;
  }
}
