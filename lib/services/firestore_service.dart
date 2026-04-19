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
      // Check owners collection
      final ownerDoc = await _db.collection('owners').doc(currentUid).get();
      if (ownerDoc.exists) {
        _cachedRole = 'owner';
        _cachedOwnerId = currentUid;
        return 'owner';
      }

      // Check drivers collection
      final driverDoc = await _db.collection('drivers').doc(currentUid).get();
      if (driverDoc.exists) {
        _cachedRole = 'driver';
        _cachedOwnerId = driverDoc.data()?['ownerId'];
        return 'driver';
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
    return _db.collection('owners').doc(uid).snapshots();
  }

  // Stream driver profile
  Stream<DocumentSnapshot<Map<String, dynamic>>> driverStream(String uid) {
    return _db.collection('drivers').doc(uid).snapshots();
  }

  // Create driver profile (Owner only)
  Future<void> createDriverProfile(String driverUid, Map<String, dynamic> data) async {
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
    await _db.collection('owners').doc(currentUid).update(data);
  }

  // Update driver profile
  Future<void> updateDriverProfile(String driverUid, Map<String, dynamic> data) async {
    await _db.collection('drivers').doc(driverUid).update(data);
  }

  // Delete driver
  Future<void> deleteDriver(String driverUid) async {
    await _db.collection('drivers').doc(driverUid).delete();
  }

  // Get driver count for owner
  Future<Map<String, int>> getFleetStats() async {
    final ownerId = await getEffectiveOwnerId();
    if (ownerId == null) return {'total': 0, 'active': 0, 'idle': 0};

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

    return {
      'total': snapshot.docs.length,
      'active': active,
      'idle': idle,
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

  // Get bookings stream for owner
  Stream<QuerySnapshot<Map<String, dynamic>>> getBookingsStream() {
    return _db.collection('bookings')
        .where('ownerId', isEqualTo: _cachedOwnerId ?? currentUid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Update booking status
  Future<void> updateBookingStatus(String bookingId, String status) async {
    await _db.collection('bookings').doc(bookingId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
