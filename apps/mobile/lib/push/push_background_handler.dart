/// Background push entry point.
///
/// firebase_messaging is not linked while notifications are off, so there is
/// no native background message to handle.
Future<void> firebaseMessagingBackgroundHandler(
  Map<String, dynamic> message,
) async {
  if (message.isEmpty) return;
}
