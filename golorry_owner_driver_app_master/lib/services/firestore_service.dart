import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _cachedRole;
  String? _cachedOwnerId;

  String get currentUid => _auth.currentUser?.uid ?? "";

  // Get user role with caching
  Future<String> getUserRole() async {
    if (_cachedRole != null) return _cachedRole!;
    if (currentUid.isEmpty) return "guest";

    try {
      final userDoc = await _db.collection('users').doc(currentUid).get();
      if (userDoc.exists) {
        _cachedRole = userDoc.data()?['role'] ?? 'unknown';
        if (_cachedRole == 'owner') {
          _cachedOwnerId = currentUid;
        } else if (_cachedRole == 'driver') {
          final driverDoc = await _db.collection('drivers').doc(currentUid).get();
          if (driverDoc.exists) {
            _cachedOwnerId = driverDoc.data()?['ownerId'];
          }
        }
        return _cachedRole!;
      }
    } catch (e) {
      debugPrint("Error fetching role: $e");
    }

    return "unknown";
  }

  // Get the effective ownerId (Self for owner, Boss for driver)
  Future<String?> getEffectiveOwnerId() async {
    if (_cachedOwnerId != null) return _cachedOwnerId;
    await getUserRole();
    return _cachedOwnerId;
  }

  // Clear cache on logout
  void clearCache() {
    _cachedRole = null;
    _cachedOwnerId = null;
  }

  // Stream owner profile
  Stream<DocumentSnapshot<Map<String, dynamic>>> ownerStream(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }

  // Stream driver profile
  Stream<DocumentSnapshot<Map<String, dynamic>>> driverStream(String uid) {
    return _db.collection('drivers').doc(uid).snapshots();
  }

  // Create driver profile (Owner only)
  Future<void> createDriverProfile(String driverUid, Map<String, dynamic> data) async {
    // 1. Create unified user document with role
    await _db.collection('users').doc(driverUid).set({
      'uid': driverUid,
      'name': data['name'],
      'email': data['email'],
      'phone': data['phone'],
      'role': 'driver',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Create the detailed driver profile
    await _db.collection('drivers').doc(driverUid).set({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'role': 'driver',
    });
  }

  // Stream drivers for a specific owner
  Stream<QuerySnapshot<Map<String, dynamic>>> getDriversStream(String ownerId) {
    return _db.collection('drivers')
        .where('ownerId', isEqualTo: ownerId)
        .snapshots();
  }

  // Update driver location
  Future<void> updateDriverLocation(double lat, double lng) async {
    if (currentUid.isEmpty) return;
    await _db.collection('drivers').doc(currentUid).update({
      'currentLocation': GeoPoint(lat, lng),
      'lastLocationUpdate': FieldValue.serverTimestamp(),
    });
  }

  // Update driver last login
  Future<void> updateLastLogin() async {
    if (currentUid.isEmpty) return;
    await _db.collection('drivers').doc(currentUid).update({
      'lastLogin': FieldValue.serverTimestamp(),
    });
  }

  // Update owner profile
  Future<void> updateOwnerProfile(Map<String, dynamic> data) async {
    if (currentUid.isEmpty) return;
    await _db.collection('users').doc(currentUid).update(data);
  }

  // Update driver profile
  Future<void> updateDriverProfile(String driverUid, Map<String, dynamic> data) async {
    await _db.collection('drivers').doc(driverUid).update(data);
  }

  // Delete driver
  Future<void> deleteDriver(String driverUid) async {
    await _db.collection('drivers').doc(driverUid).delete();
  }

  // Get driver count and earnings for owner
  Future<Map<String, dynamic>> getFleetStats() async {
    final ownerId = await getEffectiveOwnerId();
    if (ownerId == null) return {'total': 0, 'active': 0, 'idle': 0, 'earnings': 0.0};

    final snapshot = await _db.collection('drivers')
        .where('ownerId', isEqualTo: ownerId)
        .get();

    int active = 0;
    int idle = 0;
    for (var doc in snapshot.docs) {
      final status = doc.data()['status'] ?? 'active';
      if (status == 'active') {
        active++;
      } else {
        idle++;
      }
    }

    // Calculate earnings from completed bookings
    final bookingsSnap = await _db.collection('bookings')
        .where('ownerId', isEqualTo: ownerId)
        .where('status', isEqualTo: 'completed')
        .get();

    double totalEarnings = 0;
    for (var doc in bookingsSnap.docs) {
      final data = doc.data();
      final fareInfo = data['totalFare'] ?? data['price'] ?? 0;
      double fare = 0.0;
      if (fareInfo is num) {
        fare = fareInfo.toDouble();
      } else if (fareInfo is String) {
        // remove commas or ₹ signs if any
        String cleanFare = fareInfo.replaceAll(RegExp(r'[^0-9.]'), '');
        fare = double.tryParse(cleanFare) ?? 0.0;
      }
      totalEarnings += fare;
    }

    return {
      'total': snapshot.docs.length,
      'active': active,
      'idle': idle,
      'earnings': totalEarnings,
    };
  }

  // Send password reset email
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Change password
  Future<void> changePassword(String currentPassword, String newPassword) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) throw Exception("No user logged in");
    
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  // ---- Bookings ----

  // Create booking
  Future<void> createBooking(Map<String, dynamic> data) async {
    final ownerId = await getEffectiveOwnerId();
    if (ownerId == null) return;
    await _db.collection('bookings').add({
      ...data,
      'ownerId': ownerId,
      'createdBy': currentUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Get bookings stream for owner/driver
  // - Owner: sees bookings filtered by ownerId
  // - Driver: sees bookings accepted by this driver (by driverId)
  Stream<QuerySnapshot<Map<String, dynamic>>> getBookingsStream() {
    final uid = currentUid;
    if (uid.isEmpty) return const Stream.empty();
    // Always filter by driverId so drivers see their own jobs
    return _db.collection('bookings')
        .where('driverId', isEqualTo: uid)
        .snapshots();
  }

  // Update booking status (uses lowercase)
  Future<void> updateBookingStatus(String bookingId, String status) async {
    await _db.collection('bookings').doc(bookingId).update({
      'status': status.toLowerCase(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Get available pending bookings for drivers (real-time stream)
  // Uses single-field query (no composite index required).
  // Client-side filter removes already-assigned bookings.
  Stream<QuerySnapshot<Map<String, dynamic>>> getAvailableBookingsStream() {
    return _db.collection('bookings')
        .where('status', isEqualTo: 'pending')   // lowercase - must match customer app
        .snapshots();
  }

  // Driver accepts a job
  Future<void> takeJob(String bookingId) async {
    await _db.collection('bookings').doc(bookingId).update({
      'status': 'accepted',       // lowercase, consistent with customer app
      'driverId': currentUid,     // link this driver to the booking
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Update driver live GPS location inside the active booking (for customer tracking)
  Future<void> updateBookingLocation(String bookingId, double lat, double lng) async {
    await _db.collection('bookings').doc(bookingId).update({
      'driverLocation': GeoPoint(lat, lng),
      'locationUpdatedAt': FieldValue.serverTimestamp(),
    });
    // Also update the driver document so owner map shows it
    await updateDriverLocation(lat, lng);
  }

  // Stream the active booking for a driver (real-time)
  Stream<QuerySnapshot<Map<String, dynamic>>> getActiveBookingStream() {
    final uid = currentUid;
    if (uid.isEmpty) return const Stream.empty();
    return _db.collection('bookings')
        .where('driverId', isEqualTo: uid)
        .where('status', whereIn: ['accepted', 'in_transit', 'Confirmed', 'In Transit'])
        .limit(1)
        .snapshots();
  }

  // Update booking status (trip start / complete)
  Future<void> updateTripStatus(String bookingId, String status) async {
    final Map<String, dynamic> update = {
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (status == 'in_transit') update['tripStartedAt'] = FieldValue.serverTimestamp();
    if (status == 'completed') update['tripCompletedAt'] = FieldValue.serverTimestamp();
    await _db.collection('bookings').doc(bookingId).update(update);
  }
}
