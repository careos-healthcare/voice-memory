import '../../../models/journal_entry.dart';
import '../models/curiosity_hook.dart';
import '../yesterdays_snapshot_copy.dart';

/// High-level yesterday bullets — reflection metadata only, never raw transcript.
class YesterdaysSnapshotBullets {
  const YesterdaysSnapshotBullets({required this.summaries});

  final List<String> summaries;
}

abstract final class YesterdaysSnapshotEngine {
  YesterdaysSnapshotEngine._();

  static const _maxBullets = 3;
  static const _maxBulletLength = 120;

  static YesterdaysSnapshotBullets build({
    required CuriosityHook hook,
    JournalEntry? entry,
  }) {
    final bullets = <String>[];

    if (entry != null) {
      final reflection = entry.reflection;
      _addIfPresent(bullets, reflection.concreteObservation);
      _addIfPresent(
        bullets,
        reflection.repeatedSignal.isNotEmpty
            ? reflection.repeatedSignal
            : reflection.exactLanguagePattern,
      );
      _addIfPresent(bullets, reflection.tensionOrContradiction);
      _addIfPresent(bullets, reflection.nextSmallAction);
      if (reflection.mood.trim().isNotEmpty && reflection.recurringThemes.isNotEmpty) {
        _addIfPresent(
          bullets,
          '${reflection.mood.trim()} around ${reflection.recurringThemes.first.trim()}',
        );
      } else {
        _addIfPresent(bullets, reflection.mood);
      }
    }

    if (hook.primaryAnchor.trim().isNotEmpty) {
      _addIfPresent(
        bullets,
        YesterdaysSnapshotCopy.anchorBullet(hook.primaryAnchor.trim()),
      );
    }

    if (bullets.isEmpty) {
      bullets.addAll(const [
        YesterdaysSnapshotCopy.fallbackBulletOne,
        YesterdaysSnapshotCopy.fallbackBulletTwo,
        YesterdaysSnapshotCopy.fallbackBulletThree,
      ]);
    }

    while (bullets.length < _maxBullets) {
      final fallback = _fallbackForIndex(bullets.length, hook.primaryAnchor);
      if (!bullets.contains(fallback)) {
        bullets.add(fallback);
      } else {
        break;
      }
    }

    return YesterdaysSnapshotBullets(
      summaries: bullets.take(_maxBullets).toList(growable: false),
    );
  }

  static void _addIfPresent(List<String> bullets, String? raw) {
    if (bullets.length >= _maxBullets) return;
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) return;
    final clipped = trimmed.length <= _maxBulletLength
        ? trimmed
        : '${trimmed.substring(0, _maxBulletLength - 1).trim()}…';
    if (bullets.contains(clipped)) return;
    bullets.add(clipped);
  }

  static String _fallbackForIndex(int index, String anchor) {
    switch (index) {
      case 0:
        return YesterdaysSnapshotCopy.fallbackBulletOne;
      case 1:
        final trimmed = anchor.trim();
        return trimmed.isEmpty
            ? YesterdaysSnapshotCopy.fallbackBulletTwo
            : YesterdaysSnapshotCopy.anchorBullet(trimmed);
      default:
        return YesterdaysSnapshotCopy.fallbackBulletThree;
    }
  }
}
