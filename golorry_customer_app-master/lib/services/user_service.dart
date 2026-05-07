import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Handles all reads/writes to the `users/{uid}` Firestore collection.
class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  // ── Get Profile ───────────────────────────────────
  /// Returns the current user's profile document, or null if not found.
  Future<Map<String, dynamic>?> getUserProfile() async {
    if (_uid == null) return null;
    final doc = await _db.collection('users').doc(_uid).get();
    return doc.exists ? doc.data() : null;
  }

  /// Stream version — updates in real time.
  Stream<Map<String, dynamic>?> getUserProfileStream() {
    if (_uid == null) return const Stream.empty();
    return _db.collection('users').doc(_uid!).snapshots().map(
          (doc) => doc.exists ? doc.data() : null,
        );
  }

  // ── Update Profile ────────────────────────────────
  /// Merges [fields] into the user's profile document.
  Future<void> updateProfile(Map<String, dynamic> fields) async {
    if (_uid == null) throw Exception('Not signed in');
    await _db.collection('users').doc(_uid).set(
      {...fields, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  // ── Booking Stats ─────────────────────────────────
  /// Recalculates trip count + total spend and writes them back to the user doc.
  /// Call this after a booking is confirmed.
  Future<void> refreshBookingStats() async {
    if (_uid == null) return;
    try {
      final snap = await _db
          .collection('bookings')
          .where('customerId', isEqualTo: _uid)
          .get();

      double spend = 0;
      for (final doc in snap.docs) {
        final data = doc.data();
        spend += (data['totalFare'] ?? 0.0).toDouble();
      }

      await _db.collection('users').doc(_uid).set({
        'totalTrips': snap.docs.length,
        'totalSpend': spend,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Non-critical — ignore silently
    }
  }
}
