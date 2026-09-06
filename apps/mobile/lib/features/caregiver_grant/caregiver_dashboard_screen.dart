import 'package:archiveme_mobile/features/caregiver/caregiver_mode_controller.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_read_service.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// What a caregiver sees once local caregiver mode is active — real,
/// permission-gated data from [CaregiverReadService], never a fixed set
/// of streams the owner didn't actually consent to.
class CaregiverDashboardScreen extends StatefulWidget {
  const CaregiverDashboardScreen({super.key});

  @override
  State<CaregiverDashboardScreen> createState() =>
      _CaregiverDashboardScreenState();
}

class _CaregiverDashboardScreenState extends State<CaregiverDashboardScreen> {
  late final Future<CaregiverDashboardSnapshot?> _snapshotFuture;

  @override
  void initState() {
    super.initState();
    final service = CaregiverReadService(
      journalStore: AppServices.instance.journalStore,
      modeController: CaregiverModeController.instance,
    );
    _snapshotFuture = service.loadDashboardSnapshot();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Archive Overview')),
      body: SafeArea(
        child: FutureBuilder<CaregiverDashboardSnapshot?>(
          future: _snapshotFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data;
            if (data == null) {
              return _buildNoAccessState();
            }
            return _buildDashboard(data);
          },
        ),
      ),
    );
  }

  Widget _buildNoAccessState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.md),
            const Text(
              "Access isn't available right now",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'This may be because the archive owner has not shared their '
              'journal with you, or access was turned off.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(CaregiverDashboardSnapshot data) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.accentLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.menu_book_outlined, color: AppColors.accentPrimary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '${data.evidenceCount} preserved moments',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (data.priorityAlerts.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          ...data.priorityAlerts.map(
            (alert) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(alert, style: const TextStyle(fontSize: 14)),
            ),
          ),
        ],
        if (data.recentEvidenceLabels.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'Recent moments',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...data.recentEvidenceLabels.map(_buildEvidenceCard),
        ],
        if (data.timelineSummaries.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'Timeline',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...data.timelineSummaries.map(_buildEvidenceCard),
        ],
      ],
    );
  }

  Widget _buildEvidenceCard(String label) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderSubtle),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: const TextStyle(fontSize: 14)),
    );
  }
}
