import 'package:archiveme_mobile/features/proof_admission/archive_correction_store.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_scope_provider.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Reconciles [ArchiveCorrectionStore] with the active account namespace.
///
/// Call once at cold start (with [migrateLegacyFeedback]) and on every
/// account switch (without migration).
Future<void> reconcileArchiveCorrectionStoreForActiveNamespace(
  MobilePrefsStore prefs, {
  bool migrateLegacyFeedback = false,
}) async {
  ArchiveCorrectionStore.instance.configure(prefs);
  await ArchiveCorrectionStore.instance.switchArchive(
    const AppServicesProofScopeProvider().activeArchiveScope,
  );
  await ArchiveCorrectionStore.instance.ensureLoaded();
  if (migrateLegacyFeedback) {
    await ArchiveCorrectionStore.instance.migrateLegacyArchiveFeedback();
  }
}