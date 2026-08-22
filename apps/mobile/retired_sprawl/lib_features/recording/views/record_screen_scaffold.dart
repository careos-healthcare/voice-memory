part of '../recording_screen.dart';

extension RecordScreenScaffold on _RecordScreenState {
  Widget _buildRecordScreenScaffold(BuildContext context, RecordBuildContext ctx) {
    return ColoredBox(
      color: recordScreenBackground,
      child: SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          children: [
            _buildRecordScreenBody(context, ctx),
            if (ctx.showCloseButton)
              const Align(
                alignment: Alignment.topRight,
                child: RecordScreenCloseButton(),
              ),
          ],
        ),
      ),
    );
  }
}
