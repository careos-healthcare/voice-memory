import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/core/database/vector_store.dart';
import 'package:archiveme_mobile/core/diagnostics/database_health_service.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

/// Power-user view of local database health.
class SystemDiagnosticsScreen extends StatefulWidget {
  const SystemDiagnosticsScreen({
    super.key,
    this.snapshot,
    this.database,
    this.scratchDirectory,
    this.onVacuum,
  });

  final DatabaseDiagnosticsSnapshot? snapshot;
  final Database? database;
  final Directory? scratchDirectory;
  final Future<int> Function()? onVacuum;

  @override
  State<SystemDiagnosticsScreen> createState() =>
      _SystemDiagnosticsScreenState();
}

class _SystemDiagnosticsScreenState extends State<SystemDiagnosticsScreen> {
  String? _vacuumMessage;

  DatabaseDiagnosticsSnapshot get _snapshot {
    return widget.snapshot ??
        DatabaseDiagnosticsSnapshot(
          vectorFootprintBytes: VectorStore.scanBudgetBytes,
          quantizationBits: _quantizationBits,
          fileSizeBytes: 0,
          connectionOpen: widget.database != null,
          schemaVersion: 0,
          migrationHistory: const [],
          tasks: DatabaseHealthService.backgroundTasks(),
        );
  }

  int get _quantizationBits {
    final match = RegExp(r'qbits=(\d+)').firstMatch(VectorStore.quantOptions);
    return int.tryParse(match?.group(1) ?? '') ?? 4;
  }

  Future<void> _vacuum() async {
    final custom = widget.onVacuum;
    final database = widget.database;
    final int removed;
    if (custom != null) {
      removed = await custom();
    } else if (database != null) {
      removed = await DatabaseHealthService().vacuumAndReindex(
        database: database,
        scratchDirectory: widget.scratchDirectory,
      );
    } else {
      if (!mounted) return;
      setState(() => _vacuumMessage = 'No open database.');
      return;
    }
    if (!mounted) return;
    setState(
      () => _vacuumMessage = 'Vacuum finished. Removed $removed temp files.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return Scaffold(
      key: const Key('system_diagnostics_screen'),
      appBar: AppBar(title: const Text('System health')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Vector store',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            'Memory footprint ${snapshot.footprintLabel}',
            key: const Key('diagnostics_vector_footprint'),
          ),
          Text(
            'Quantization ${snapshot.quantizationBits}-bit',
            key: const Key('diagnostics_quant_bits'),
          ),
          const SizedBox(height: 16),
          Text('Database', style: Theme.of(context).textTheme.titleMedium),
          Text(
            'File size ${snapshot.fileSizeLabel}',
            key: const Key('diagnostics_file_size'),
          ),
          Text(
            snapshot.connectionOpen ? 'Connection open' : 'Connection closed',
            key: const Key('diagnostics_connection'),
          ),
          Text(
            snapshot.historyLabel,
            key: const Key('diagnostics_migrations'),
          ),
          Text(
            'Schema version ${snapshot.schemaVersion}',
            key: const Key('diagnostics_schema_version'),
          ),
          const SizedBox(height: 16),
          Text(
            'Background tasks',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final task in snapshot.tasks)
            Text(
              '${task.name}: ${task.detail}',
              key: Key(
                task.name == 'Sunday life memo'
                    ? 'diagnostics_life_memo'
                    : 'diagnostics_p2p',
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('diagnostics_vacuum'),
            onPressed: () => unawaited(_vacuum()),
            child: const Text('Run Vacuum & Re-Index'),
          ),
          if (_vacuumMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _vacuumMessage!,
                key: const Key('diagnostics_vacuum_result'),
              ),
            ),
        ],
      ),
    );
  }
}
