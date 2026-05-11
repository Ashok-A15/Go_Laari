import 'package:cloud_firestore/cloud_firestore.dart';

class BookingModel {
  final String id;
  final String customerId;
  final String pickupAddress;
  final String dropAddress;
  final String vehicleName;
  final String tier;
  final List<String> itemTypes;
  final String valueOfGoods;
  final String paymentMethod;
  final double totalFare;
  final String status;
  final DateTime createdAt;
  final String? driverId;

  // We keep route/distance roughly as strings if needed, or just rely on pickup/drop
  final String route;
  final String distance;

  BookingModel({
    required this.id,
    required this.customerId,
    required this.pickupAddress,
    required this.dropAddress,
    required this.vehicleName,
    required this.tier,
    required this.itemTypes,
    required this.valueOfGoods,
    required this.paymentMethod,
    required this.totalFare,
    required this.status,
    required this.createdAt,
    this.driverId,
    required this.route,
    required this.distance,
  });

  factory BookingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BookingModel(
      id: doc.id,
      customerId: data['customerId'] ?? '',
      pickupAddress: data['pickupAddress'] ?? '',
      dropAddress: data['dropAddress'] ?? '',
      vehicleName: data['vehicleName'] ?? 'Unknown',
      tier: data['tier'] ?? 'Regular',
      itemTypes: List<String>.from(data['itemTypes'] ?? []),
      valueOfGoods: data['valueOfGoods'] ?? '',
      paymentMethod: data['paymentMethod'] ?? 'Cash',
      totalFare: (data['totalFare'] ?? 0).toDouble(),
      status: data['status'] ?? 'Pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      driverId: data['driverId'],
      route: data['route'] ?? 'Unknown Route',
      distance: data['distance'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'customerId': customerId,
      'pickupAddress': pickupAddress,
      'dropAddress': dropAddress,
      'vehicleName': vehicleName,
      'tier': tier,
      'itemTypes': itemTypes,
      'valueOfGoods': valueOfGoods,
      'paymentMethod': paymentMethod,
      'totalFare': totalFare,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
      'driverId': driverId,
      'route': route,
      'distance': distance,
    };
  }
}
