import 'package:archiveme_mobile/billing/archive_intelligence_proof_copy.dart';
import 'package:archiveme_mobile/billing/archive_paywall_stats.dart';

/// Bullet lines or fallback — derived from [ArchivePaywallStats] only.
class ArchiveIntelligenceProofView {
  const ArchiveIntelligenceProofView({
    required this.recurringThemeCount,
    required this.activeTheoryCount,
    required this.changeCount,
    required this.bullets,
    required this.useFallback,
  });

  factory ArchiveIntelligenceProofView.fromStats(ArchivePaywallStats stats) {
    final bullets = <String>[];
    final themes = stats.recurringThemeCount;
    final theories = stats.activeTheoryCount;
    final changes = stats.changeCount;

    if (themes > 0) {
      bullets.add('• $themes recurring theme${themes == 1 ? '' : 's'}');
    }
    if (theories > 0) {
      bullets.add('• $theories active theor${theories == 1 ? 'y' : 'ies'}');
    }
    if (changes > 0) {
      bullets.add('• $changes change${changes == 1 ? '' : 's'} over time');
    }

    return ArchiveIntelligenceProofView(
      recurringThemeCount: themes,
      activeTheoryCount: theories,
      changeCount: changes,
      bullets: bullets,
      useFallback: bullets.isEmpty,
    );
  }

  final int recurringThemeCount;
  final int activeTheoryCount;
  final int changeCount;
  final List<String> bullets;
  final bool useFallback;

  String get bodyText =>
      useFallback ? ArchiveIntelligenceProofCopy.fallback : bullets.join('\n');
}