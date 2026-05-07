class FareCalculator {
  static const double baseFare = 150;
  static const double perKmRate = 18;
  static const double perMinuteRate = 2;

  static double calculateFare({
    required double distanceKm,
    required double durationMin,
  }) {
    final fare =
        baseFare +
        (distanceKm * perKmRate) +
        (durationMin * perMinuteRate);

    return fare;
  }
}
