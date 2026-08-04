import 'dart:async';
import 'dart:io';

import '../../storage/encrypted_json_file_store.dart';
import '../../storage/private_data_encryption_key_store.dart';
import 'weekly_review.dart';
import 'weekly_review_notification.dart';

class WeeklyReviewState {
  const WeeklyReviewState({
    this.review,
    this.notificationOptedIn = WeeklyReviewNotificationPolicy.defaultOptedIn,
    this.lastNotifiedReviewId,
  });

  const WeeklyReviewState.empty() : this();

  /// The most recent generated review. It stays readable regardless of what
  /// happens to the subscription afterwards.
  final WeeklyReview? review;

  final bool notificationOptedIn;
  final String? lastNotifiedReviewId;

  WeeklyReviewState copyWith({
    WeeklyReview? review,
    bool? notificationOptedIn,
    String? lastNotifiedReviewId,
  }) => WeeklyReviewState(
    review: review ?? this.review,
    notificationOptedIn: notificationOptedIn ?? this.notificationOptedIn,
    lastNotifiedReviewId: lastNotifiedReviewId ?? this.lastNotifiedReviewId,
  );
}

/// Durable, archive-scoped home for the weekly review and its opt-in.
///
/// Persisting the review is what makes it survive: once generated it can be
/// reopened later without regenerating it, which is also why an expired
/// subscription never blanks it.
class WeeklyReviewStore {
  WeeklyReviewStore({
    required File file,
    required PrivateDataEncryptionKeyStore keyStore,
    required this.archiveId,
  }) : assert(archiveId != '', 'A weekly review must belong to an archive.'),
       _storage = EncryptedJsonFileStore(file: file, keyStore: keyStore);

  static const storeVersion = 1;
  static const fileName = 'weekly_review.enc';

  final EncryptedJsonFileStore _storage;
  final String archiveId;
  Future<void> _pending = Future.value();

  Future<WeeklyReviewState> read() => _serialized(_readOwned);

  Future<WeeklyReviewState> saveReview(WeeklyReview review) =>
      _serialized(() async {
        final current = await _readOwned();
        final next = current.copyWith(review: review);
        await _writeOwned(next);
        return next;
      });

  Future<WeeklyReviewState> setNotificationOptIn(bool optedIn) =>
      _serialized(() async {
        final current = await _readOwned();
        final next = WeeklyReviewState(
          review: current.review,
          notificationOptedIn: optedIn,
          lastNotifiedReviewId: current.lastNotifiedReviewId,
        );
        await _writeOwned(next);
        return next;
      });

  Future<WeeklyReviewState> markNotified(String reviewId) =>
      _serialized(() async {
        final current = await _readOwned();
        final next = current.copyWith(lastNotifiedReviewId: reviewId);
        await _writeOwned(next);
        return next;
      });

  Future<void> clear() =>
      _serialized(() => _writeOwned(const WeeklyReviewState.empty()));

  Future<T> _serialized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _pending = _pending.then((_) async {
      try {
        completer.complete(await action());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<Map<String, dynamic>> _readEnvelope() async {
    final raw = await _storage.readJson();
    if (raw is! Map) return {};
    final json = Map<String, dynamic>.from(raw);
    if (json['storeVersion'] != storeVersion) return {};
    final archives = json['archives'];
    return archives is Map ? Map<String, dynamic>.from(archives) : {};
  }

  Future<WeeklyReviewState> _readOwned() async {
    final archives = await _readEnvelope();
    final mine = archives[archiveId];
    if (mine is! Map) return const WeeklyReviewState.empty();
    final json = Map<String, dynamic>.from(mine);
    return WeeklyReviewState(
      review: WeeklyReview.fromJson(json['review']),
      notificationOptedIn: json['notificationOptedIn'] == true,
      lastNotifiedReviewId: json['lastNotifiedReviewId']?.toString(),
    );
  }

  Future<void> _writeOwned(WeeklyReviewState state) async {
    final archives = await _readEnvelope();
    archives[archiveId] = {
      if (state.review != null) 'review': state.review!.toJson(),
      'notificationOptedIn': state.notificationOptedIn,
      if (state.lastNotifiedReviewId != null)
        'lastNotifiedReviewId': state.lastNotifiedReviewId,
    };
    await _storage.writeJson({
      'storeVersion': storeVersion,
      'archives': archives,
    });
  }
}
