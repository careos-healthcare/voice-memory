import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../billing/archive_entitlement_reader.dart';
import '../../services/app_services.dart';
import '../../storage/private_data_encryption_key_store.dart';
import '../changes/change_thread_repository.dart';
import '../monetization/domain/access_policy_engine.dart';
import 'weekly_review.dart';
import 'weekly_review_engine.dart';
import 'weekly_review_notification.dart';
import 'weekly_review_store.dart';
import 'weekly_review_sufficiency.dart';

/// What the Changes surface needs in order to offer this week's review.
class WeeklyReviewSnapshot {
  const WeeklyReviewSnapshot({
    this.review,
    this.shortfall,
    this.notificationOptedIn = WeeklyReviewNotificationPolicy.defaultOptedIn,
    this.pendingNotification,
  });

  const WeeklyReviewSnapshot.none() : this();

  /// The review to show: this week's if one was generated, otherwise the last
  /// one that was, which stays readable.
  final WeeklyReview? review;

  /// Why no new review was generated, when none was.
  final WeeklyReviewShortfall? shortfall;

  final bool notificationOptedIn;

  /// Ready to hand to the notification scheduler. Null unless the user opted
  /// in and a new review was generated this pass.
  final WeeklyReviewNotification? pendingNotification;

  bool get hasReview => review != null;
}

/// Resolves the archive's weekly review store and keeps generation, reading,
/// and the notification opt-in behind one door.
abstract final class WeeklyReviewRepository {
  static WeeklyReviewStore? _store;
  static String? _storeArchiveId;

  static WeeklyReviewStore? storeOrNull() {
    if (!AppServices.isInitialized) return null;
    final journal = AppServices.instance.journalStore;
    final archiveId = journal.ownerArchiveId;
    if (_store != null && _storeArchiveId == archiveId) return _store;
    _store = WeeklyReviewStore(
      file: File('${journal.file.parent.path}/${WeeklyReviewStore.fileName}'),
      keyStore: _keyStore(),
      archiveId: archiveId,
    );
    _storeArchiveId = archiveId;
    return _store;
  }

  /// Reads the stored review, then tries to generate this week's.
  ///
  /// Reading comes first and never depends on the outcome of generation, so a
  /// review the user has already been given stays on screen even when a new
  /// one cannot be produced.
  static Future<WeeklyReviewSnapshot> load(ChangesSnapshot changes) async {
    final store = storeOrNull();
    if (store == null) return const WeeklyReviewSnapshot.none();
    final state = await store.read();

    final entitlement =
        await ArchiveEntitlementReader.forAccessCheck().entitlement;
    final outcome = WeeklyReviewEngine.build(
      projection: changes.projection,
      archive: changes.resurfacing,
      entitlement: entitlement,
      // Periodic-review allowances are metered by the server, matching how the
      // other metered capabilities are evaluated on device.
      usage: const UsageSnapshot.serverAuthoritative(),
    );

    final generated = outcome.review;
    if (generated == null) {
      return WeeklyReviewSnapshot(
        review: state.review,
        shortfall: outcome.shortfall,
        notificationOptedIn: state.notificationOptedIn,
      );
    }

    await store.saveReview(generated);
    final notification = WeeklyReviewNotificationPolicy.notificationFor(
      review: generated,
      userOptedIn: state.notificationOptedIn,
      lastNotifiedReviewId: state.lastNotifiedReviewId,
    );
    if (notification != null) await store.markNotified(notification.reviewId);
    return WeeklyReviewSnapshot(
      review: generated,
      notificationOptedIn: state.notificationOptedIn,
      pendingNotification: notification,
    );
  }

  static Future<void> setNotificationOptIn(bool optedIn) async {
    await storeOrNull()?.setNotificationOptIn(optedIn);
  }

  static PrivateDataEncryptionKeyStore _keyStore() =>
      Platform.environment.containsKey('FLUTTER_TEST')
      ? InMemoryPrivateDataEncryptionKeyStore()
      : SecurePrivateDataEncryptionKeyStore(
          secure: AppServices.instance.secureStorage,
        );

  @visibleForTesting
  static void resetForTest() {
    _store = null;
    _storeArchiveId = null;
  }
}
