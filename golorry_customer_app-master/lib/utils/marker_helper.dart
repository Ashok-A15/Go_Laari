import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MarkerHelper {
  static Future<BitmapDescriptor> getCustomMarker(IconData iconData, Color color) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 120.0;
    
    // Draw outer circle
    final Paint paint = Paint()..color = color;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, paint);
    
    // Draw inner white circle
    paint.color = Colors.white;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 * 0.85, paint);

    // Draw Icon
    final TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: size * 0.5,
        fontFamily: iconData.fontFamily,
        color: color,
        package: iconData.fontPackage,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(size / 2 - textPainter.width / 2, size / 2 - textPainter.height / 2),
    );

    final ui.Image image = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  static Future<BitmapDescriptor> getTruckMarker() async {
    return getCustomMarker(Icons.local_shipping_rounded, const Color(0xFF00D4AA));
  }

  static Future<BitmapDescriptor> getStationaryMarker(IconData icon, Color color) async {
    return getCustomMarker(icon, color);
  }
}
