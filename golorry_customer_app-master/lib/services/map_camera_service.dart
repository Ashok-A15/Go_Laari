import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapCameraService {
  static void followDriver({
    required GoogleMapController? controller,
    required LatLng driverPos,
    double heading = 0.0,
    double zoom = 17.5,
    double tilt = 45.0,
  }) {
    if (controller == null) return;
    
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: driverPos,
          zoom: zoom,
          tilt: tilt,
          bearing: heading,
        ),
      ),
    );
  }

  static void fitRoute({
    required GoogleMapController? controller,
    required LatLng pickup,
    required LatLng drop,
  }) {
    if (controller == null) return;

    final bounds = LatLngBounds(
      southwest: LatLng(
        pickup.latitude < drop.latitude ? pickup.latitude : drop.latitude,
        pickup.longitude < drop.longitude ? pickup.longitude : drop.longitude,
      ),
      northeast: LatLng(
        pickup.latitude > drop.latitude ? pickup.latitude : drop.latitude,
        pickup.longitude > drop.longitude ? pickup.longitude : drop.longitude,
      ),
    );

    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }
}
