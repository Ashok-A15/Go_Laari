import '../models/booking.dart';

class DemoBookingStore {
  static final List<Booking> bookings = [];

  static void addBooking(Booking booking) {
    bookings.insert(0, booking); // newest first
  }
}
