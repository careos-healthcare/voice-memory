import '../../storage/mobile_prefs_store.dart';
import 'archive_correction_store.dart';
import 'proof_scope_provider.dart';

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
