import 'package:archiveme_mobile/features/recording/record_surface_input.dart';
import 'package:archiveme_mobile/features/recording/record_surface_input_cache_key.dart';
import 'package:archiveme_mobile/features/recording/record_surface_resolver.dart';
import 'package:archiveme_mobile/features/recording/record_surface_view_state.dart';

/// Memoized boundary between record screen state and [RecordSurfaceResolver].
///
/// Recomputes [RecordSurfaceViewState] only when [RecordSurfaceInput] cache keys
/// change (entry count, record phase, post-save payload, etc.).
final class RecordSurfaceResolutionNotifier {
  RecordSurfaceInputCacheKey? _cacheKey;
  RecordSurfaceViewState? _viewState;

  RecordSurfaceViewState? get viewState => _viewState;

  RecordSurfaceViewState resolve(RecordSurfaceInput input) {
    final cacheKey = RecordSurfaceInputCacheKey.from(input);
    if (_cacheKey == cacheKey && _viewState != null) {
      return _viewState!;
    }
    _cacheKey = cacheKey;
    _viewState = RecordSurfaceResolver.resolve(input);
    return _viewState!;
  }

  void invalidate() {
    _cacheKey = null;
    _viewState = null;
  }
}