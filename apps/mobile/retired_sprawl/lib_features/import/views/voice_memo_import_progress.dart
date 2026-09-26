import 'package:archiveme_mobile/features/import/voice_memo_queue.dart';
import 'package:archiveme_mobile/router/app_router.dart';
import 'package:flutter/material.dart';

/// "Importing 1 of 3" while a batch of shared memos is transcribed.
class VoiceMemoImportProgressView extends StatelessWidget {
  const VoiceMemoImportProgressView({required this.progress, super.key});

  final VoiceMemoImportProgress progress;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          progress.label,
          key: const Key('voice_memo_import_progress'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}

abstract final class VoiceMemoImportProgressHub {
  VoiceMemoImportProgressHub._();

  static final current = ValueNotifier<VoiceMemoImportProgress?>(null);
  static bool _open = false;

  static void report(VoiceMemoImportProgress progress) {
    current.value = progress;
    final nav = appRootNavigatorKey.currentState;
    if (nav != null && !_open) {
      _open = true;
      nav
          .push<void>(
            MaterialPageRoute<void>(
              builder: (_) => ValueListenableBuilder<VoiceMemoImportProgress?>(
                valueListenable: current,
                builder: (context, value, _) {
                  final shown = value ?? progress;
                  if (shown.done >= shown.total && shown.total > 0) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    });
                  }
                  return VoiceMemoImportProgressView(progress: shown);
                },
              ),
            ),
          )
          .whenComplete(() {
            _open = false;
            current.value = null;
          });
    }
  }
}
