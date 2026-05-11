import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:golorry_customer_app/models/booking_model.dart';
import 'user_service.dart';

/// Handles all reads/writes to the `bookings` Firestore collection.
///
/// Every booking document stores `customerId` = Firebase Auth uid, so
/// queries always filter to the current user's trips only.
class BookingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();

  String? get _uid => _auth.currentUser?.uid;

  // ── Create Booking ────────────────────────────────
  /// Saves a new booking to Firestore and updates the user's stats.
  /// Returns the generated Firestore document ID.
  Future<String> createBooking(BookingModel booking) async {
    final docRef = await _db.collection('bookings').add(booking.toFirestore());

    // Update totalTrips + totalSpend on the user document in the background
    _userService.refreshBookingStats();

    return docRef.id;
  }

  // ── Cancel Booking ────────────────────────────────
  /// Sets [bookingId] status to 'Cancelled'.
  Future<void> cancelBooking(String bookingId) async {
    await _db.collection('bookings').doc(bookingId).update({
      'status': 'Cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
    });
    _userService.refreshBookingStats();
  }

  // ── Complete Booking ──────────────────────────────
  /// Sets [bookingId] status to 'Completed'.
  Future<void> completeBooking(String bookingId) async {
    await _db.collection('bookings').doc(bookingId).update({
      'status': 'Completed',
      'completedAt': FieldValue.serverTimestamp(),
    });
    _userService.refreshBookingStats();
  }

  // ── User Booking Stream ───────────────────────────
  /// Live stream of ALL bookings for the signed-in user, newest first.
  /// Used by the Activity / Bookings screen.
  Stream<List<BookingModel>> getUserBookings() {
    if (_uid == null) return const Stream.empty();

    return _db
        .collection('bookings')
        .where('customerId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => BookingModel.fromFirestore(doc)).toList());
  }

  // ── Active Booking Stream ─────────────────────────
  /// Live stream of the most recent 'In Transit' booking.
  /// Used by the Live Map tab to show the tracking panel.
  Stream<BookingModel?> getActiveBooking() {
    if (_uid == null) return const Stream.empty();

    return _db
        .collection('bookings')
        .where('customerId', isEqualTo: _uid)
        .where('status', isEqualTo: 'In Transit')
        .limit(1)
        .snapshots()
        .map((snap) =>
            snap.docs.isNotEmpty ? BookingModel.fromFirestore(snap.docs.first) : null);
  }

  // ── Single Booking ────────────────────────────────
  /// Fetches one booking by ID (e.g. for a details screen).
  Future<BookingModel?> getBookingById(String bookingId) async {
    final doc = await _db.collection('bookings').doc(bookingId).get();
    return doc.exists ? BookingModel.fromFirestore(doc) : null;
  }
}
