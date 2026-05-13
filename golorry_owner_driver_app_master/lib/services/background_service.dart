import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:firebase_database/firebase_database.dart';

class BackgroundService {
  static const String notificationChannelId = 'my_foreground';
  static const int notificationId = 888;

  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      notificationChannelId,
      'GoLorry Tracking',
      description: 'This channel is used for live location tracking.',
      importance: Importance.low,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'Tracking Active',
        initialNotificationContent: 'Updating location in background',
        foregroundServiceNotificationId: notificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();
    
    // Initialize Firebase in background isolate
    await Firebase.initializeApp();
    final DatabaseReference dbRef = FirebaseDatabase.instance.ref();

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // Listen for current booking ID
    String? bookingId;
    service.on('setBookingId').listen((event) {
      bookingId = event?['bookingId'];
      debugPrint('BACKGROUND: Active Booking ID set to $bookingId');
    });

    // HIGH FREQUENCY: Update every 1 second for Uber-like smoothness
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          service.setForegroundNotificationInfo(
            title: 'GoLorry Live',
            content: 'Trip in progress - Syncing location...',
          );
        }
      }

      // Track location
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );

        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          // 1. Update Firestore (for records)
          await FirebaseFirestore.instance.collection('drivers').doc(uid).update({
            'currentLocation': GeoPoint(pos.latitude, pos.longitude),
            'heading': pos.heading,
            'lastLocationUpdate': FieldValue.serverTimestamp(),
          });

          // 2. Update Realtime Database (for LIVE tracking sync)
          if (bookingId != null && bookingId!.isNotEmpty) {
            await dbRef.child('tracking').child(bookingId!).set({
              'lat': pos.latitude,
              'lng': pos.longitude,
              'heading': pos.heading,
              'lastUpdated': ServerValue.timestamp,
              'status': 'in_transit',
            });
            
            // Also update booking doc in Firestore
            await FirebaseFirestore.instance.collection('bookings').doc(bookingId).update({
              'driverLocation': GeoPoint(pos.latitude, pos.longitude),
              'driverHeading': pos.heading,
              'locationUpdatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      } catch (e) {
        debugPrint('Background location error: $e');
      }
    });
  }
}
