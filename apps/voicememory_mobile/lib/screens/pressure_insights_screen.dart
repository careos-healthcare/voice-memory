import 'package:flutter/material.dart';

import '../design/archive_mobile_typography.dart';
import '../features/pressure_retention/archive_reflection_engine.dart';
import '../features/pressure_retention/pressure_check_in_record.dart';
import '../features/pressure_retention/pressure_check_in_store.dart';
import '../features/pressure_retention/pressure_loop_visibility_engine.dart';
import '../features/pressure_retention/pressure_weekly_recap_engine.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/pressure_retention/ask_the_archive_card.dart';
import '../widgets/pressure_retention/pressure_loop_visibility_card.dart';
import '../widgets/pressure_retention/pressure_weekly_recap_card.dart';

/// Pressure loop screen: weekly visibility, recap, and the focused reflection.
class PressureInsightsScreen extends StatefulWidget {
  const PressureInsightsScreen({
    super.key,
    this.store,
    @visibleForTesting this.records,
  });

  final PressureCheckInStore? store;

  /// Injected for tests; production loads from [PressureCheckInStore].
  @visibleForTesting
  final List<PressureCheckInRecord>? records;

  @override
  State<PressureInsightsScreen> createState() => _PressureInsightsScreenState();
}

class _PressureInsightsScreenState extends State<PressureInsightsScreen> {
  static const _visibilityEngine = PressureLoopVisibilityEngine();
  static const _recapEngine = PressureWeeklyRecapEngine();
  static const _reflectionEngine = ArchiveReflectionEngine();

  late Future<List<PressureCheckInRecord>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<PressureCheckInRecord>> _load() async {
    if (widget.records != null) return widget.records!;
    final store = widget.store ?? PressureCheckInStore.instance();
    return store.loadAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        title: const Text('Your pressure loop'),
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: FutureBuilder<List<PressureCheckInRecord>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final records = snapshot.data ?? const <PressureCheckInRecord>[];
            return _buildContent(context, records);
          },
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<PressureCheckInRecord> records,
  ) {
    final visibility = _visibilityEngine.build(records);
    final recap = _recapEngine.build(records);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'What your pressure loop looks like',
            style: ArchiveMobileTypography.responsivePageTitle(context),
          ),
          const SizedBox(height: AppSpacing.md),
          PressureLoopVisibilityCard(visibility: visibility),
          const SizedBox(height: AppSpacing.sm),
          PressureWeeklyRecapCard(recap: recap),
          const SizedBox(height: AppSpacing.sm),
          AskTheArchiveCard(
            records: records,
            engine: _reflectionEngine,
          ),
        ],
      ),
    );
  }
}
