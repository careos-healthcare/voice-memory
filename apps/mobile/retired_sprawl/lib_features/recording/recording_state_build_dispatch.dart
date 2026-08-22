part of 'recording_screen.dart';

extension RecordScreenBuildDispatch on _RecordScreenState {
  List<Widget> _buildRecordScreenBodyChildren(
    BuildContext context,
    RecordBuildContext ctx,
  ) {
    return [
      ..._buildRecordPreCaptureCards(context, ctx),
      _buildRecordingPermissionPanel(context, ctx),
      ..._buildRecordCaptureStateSection(context, ctx),
    ];
  }
}
