class FirebaseTrackingConstants {
  static const String trackingRoot = 'tracking';
  static const String driverStatsRoot = 'driver_stats';
  
  // Nodes within tracking/{bookingId}
  static const String lat = 'lat';
  static const String lng = 'lng';
  static const String heading = 'heading';
  static const String lastUpdated = 'lastUpdated';
  static const String status = 'status';
  
  // Tracking Statuses
  static const String statusInTransit = 'in_transit';
  static const String statusArrived = 'arrived';
  static const String statusCompleted = 'completed';
}
