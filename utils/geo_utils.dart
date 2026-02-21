import 'package:geolocator/geolocator.dart';

class GeoUtils {
  static double distanceMeters({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) {
    return Geolocator.distanceBetween(fromLat, fromLng, toLat, toLng);
  }

  static String formatDistance(double meters) {
    if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
    final km = meters / 1000;
    return '${km.toStringAsFixed(2)} km';
  }

  static String proximityLabel(double meters) {
    if (meters <= 80) return 'ARRIVED (within 80m)';
    if (meters <= 200) return 'VERY NEAR';
    if (meters <= 500) return 'NEAR';
    if (meters <= 1500) return 'ON THE WAY';
    return 'FAR';
  }
}
