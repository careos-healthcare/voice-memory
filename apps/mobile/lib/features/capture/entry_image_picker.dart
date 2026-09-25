import 'package:image_picker/image_picker.dart';

/// Opens the system photo picker and returns local file paths.
///
/// On iOS this uses PHPicker, which hands back the chosen photos without
/// requesting access to the whole photo library.
Future<List<String>> pickEntryImages() async {
  final files = await ImagePicker().pickMultiImage(
    maxWidth: 2048,
    maxHeight: 2048,
    imageQuality: 85,
  );
  return [
    for (final file in files)
      if (file.path.trim().isNotEmpty) file.path.trim(),
  ];
}
