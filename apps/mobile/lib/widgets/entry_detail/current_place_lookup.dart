import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Resolves the device's current GPS fix into a short place name.
Future<String?> lookupCurrentPlaceName() async {
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    return null;
  }
  final position = await Geolocator.getCurrentPosition();
  final marks = await placemarkFromCoordinates(
    position.latitude,
    position.longitude,
  );
  if (marks.isEmpty) return null;
  final mark = marks.first;
  final parts = <String>[
    if ((mark.locality ?? '').trim().isNotEmpty) mark.locality!.trim(),
    if ((mark.administrativeArea ?? '').trim().isNotEmpty)
      mark.administrativeArea!.trim(),
    if ((mark.locality ?? '').trim().isEmpty &&
        (mark.name ?? '').trim().isNotEmpty)
      mark.name!.trim(),
  ];
  if (parts.isEmpty) return null;
  return parts.take(2).join(', ');
}
