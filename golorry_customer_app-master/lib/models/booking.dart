class Booking {
  final String pickup;
  final String drop;
  final double distanceKm;
  final double durationMin;
  final double fare;
  final String status;
  final DateTime createdAt;

  Booking({
    required this.pickup,
    required this.drop,
    required this.distanceKm,
    required this.durationMin,
    required this.fare,
    required this.status,
    required this.createdAt,
  });
}
