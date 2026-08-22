import 'package:archiveme_mobile/billing/archive_entitlement_reader.dart';
import 'package:archiveme_mobile/features/moments/key_moment_model.dart';
import 'package:archiveme_mobile/features/moments/key_moment_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Loads saved key moments for Ask My Archive search.
final askArchiveMomentsProvider = FutureProvider<List<KeyMoment>>((ref) async {
  return KeyMomentStore.instance().loadAll();
});

/// Whether the active account has ArchiveMe Pro (RevenueCat-backed).
final askArchiveIsProProvider = FutureProvider<bool>((ref) async {
  return ArchiveEntitlementReader.forAccessCheck().isPro;
});