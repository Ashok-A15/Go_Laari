import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;

class LocationInterpolator {
  /// Linearly interpolates between two [LatLng] points.
  static LatLng interpolate(double fraction, LatLng from, LatLng to) {
    final double lat = (to.latitude - from.latitude) * fraction + from.latitude;
    double lngDiff = to.longitude - from.longitude;

    // Handle wrap-around at 180 degrees
    if (lngDiff.abs() > 180) {
      lngDiff -= lngDiff.sign * 360;
    }
    final double lng = lngDiff * fraction + from.longitude;
    return LatLng(lat, lng);
  }

  /// Calculates the bearing between two [LatLng] points.
  static double calculateBearing(LatLng start, LatLng end) {
    final double lat1 = start.latitude * math.pi / 180;
    final double lon1 = start.longitude * math.pi / 180;
    final double lat2 = end.latitude * math.pi / 180;
    final double lon2 = end.longitude * math.pi / 180;

    final double dLon = lon2 - lon1;

    final double y = math.sin(dLon) * math.cos(lat2);
    final double x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final double bearing = math.atan2(y, x);
    return (bearing * 180 / math.pi + 360) % 360;
  }

  /// Animates a marker from [start] to [end] over [duration].
  /// [onUpdate] is called with the interpolated position and bearing.
  static void animateMarker({
    required LatLng start,
    required LatLng end,
    required Duration duration,
    required Function(LatLng position, double bearing) onUpdate,
  }) {
    const int frameRate = 60;
    final int totalFrames = (duration.inMilliseconds / (1000 / frameRate)).round();
    int currentFrame = 0;

    final double bearing = calculateBearing(start, end);

    Timer.periodic(Duration(milliseconds: (1000 / frameRate).round()), (timer) {
      currentFrame++;
      final double fraction = currentFrame / totalFrames;

      if (fraction >= 1.0) {
        onUpdate(end, bearing);
        timer.cancel();
      } else {
        final LatLng position = interpolate(fraction, start, end);
        onUpdate(position, bearing);
      }
    });
  }
}
