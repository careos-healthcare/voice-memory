import 'package:flutter/material.dart';

import '../performance/graph_performance_monitor.dart';

class GraphPerformanceOverlay extends StatelessWidget {
  const GraphPerformanceOverlay({super.key, this.monitor, this.onClose});

  final GraphPerformanceMonitor? monitor;
  final VoidCallback? onClose;

  GraphPerformanceMonitor get _monitor =>
      monitor ?? GraphPerformanceMonitor.instance;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _monitor,
    builder: (context, _) {
      final warning = _monitor.fps < 55;
      return Semantics(
        container: true,
        label: 'Graph performance diagnostics',
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xE6121720),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: warning
                  ? const Color(0xFFFF6B6B)
                  : const Color(0xFF3DDC97),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
            child: DefaultTextStyle(
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 11,
                height: 1.35,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FPS ${_monitor.fps.toStringAsFixed(1)}  '
                    '${_monitor.frameTimeMs.toStringAsFixed(1)}ms\n'
                    'Nodes ${_monitor.visibleNodeCount}/'
                    '${_monitor.activeNodeCount}  '
                    'culled ${_monitor.culledNodeCount}\n'
                    'Edges ${_monitor.visibleEdgeCount}  '
                    'KNN ${_monitor.vectorSearchLatencyMs.toStringAsFixed(2)}ms\n'
                    'RSS ${_megabytes(_monitor.estimatedMemoryBytes)} MB  '
                    '<55fps ${_monitor.below55FpsSamples}',
                  ),
                  if (onClose != null)
                    IconButton(
                      key: const Key('graph-performance-close'),
                      tooltip: 'Hide graph diagnostics',
                      visualDensity: VisualDensity.compact,
                      onPressed: onClose,
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

String _megabytes(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);
