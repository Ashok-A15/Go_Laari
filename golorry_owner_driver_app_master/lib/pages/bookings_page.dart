import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';

class BookingsPage extends StatefulWidget {
  const BookingsPage({super.key});

  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage>
    with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  late AnimationController _animController;
  String _filterStatus = "all";

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _showCreateBookingSheet() {
    final routeCtrl = TextEditingController();
    final distanceCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    String selectedStatus = "Confirmed";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text("New Booking", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(
                  controller: routeCtrl,
                  decoration: const InputDecoration(labelText: "Route (e.g. Bangalore to Mysore)", prefixIcon: Icon(Icons.route_rounded)),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: distanceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "Distance (km)", prefixIcon: Icon(Icons.straighten_rounded)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "Price (₹)", prefixIcon: Icon(Icons.currency_rupee_rounded)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: ["Confirmed", "Pending", "In Transit"].map((s) {
                    return ChoiceChip(
                      label: Text(s),
                      selected: selectedStatus == s,
                      selectedColor: _getStatusColor(s).withValues(alpha: 0.2),
                      onSelected: (_) => setModalState(() => selectedStatus = s),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (routeCtrl.text.isEmpty || priceCtrl.text.isEmpty) return;
                      try {
                        await _firestoreService.createBooking({
                          'route': routeCtrl.text.trim(),
                          'distance': distanceCtrl.text.trim(),
                          'price': priceCtrl.text.trim(),
                          'status': selectedStatus,
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: const Text("Booking created!"),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              backgroundColor: const Color(0xFF43CEA2),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF185A9D),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text("Create Booking", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted': return Colors.green;
      case 'in transit': return Colors.blue;
      case 'pending': return Colors.orange;
      case 'cancelled': return Colors.red;
      case 'completed': return const Color(0xFF43CEA2);
      default: return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'accepted': return Icons.check_circle_rounded;
      case 'in transit': return Icons.moving_rounded;
      case 'pending': return Icons.access_time_filled_rounded;
      case 'cancelled': return Icons.cancel_rounded;
      case 'completed': return Icons.task_alt_rounded;
      default: return Icons.local_shipping_rounded;
    }
  }

  // Capitalize first letter of each word for display
  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s.split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      backgroundColor: isDark ? const Color(0xFF0F171A) : const Color(0xFFF8FAF9),
      appBar: AppBar(
        title: const Text("Bookings"),
        elevation: 0,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: FloatingActionButton.extended(
          backgroundColor: const Color(0xFF43CEA2),
          onPressed: _showCreateBookingSheet,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text("New Booking", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      body: Column(
        children: [
          // Filter chips
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: ["all", "accepted", "pending", "in transit", "completed", "cancelled"].map((s) {
                final isSelected = _filterStatus == s;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(s == "all" ? "All" : _capitalize(s)),
                    selected: isSelected,
                    selectedColor: const Color(0xFF43CEA2).withValues(alpha: 0.15),
                    checkmarkColor: const Color(0xFF185A9D),
                    onSelected: (_) => setState(() => _filterStatus = s),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          // Bookings list
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestoreService.getBookingsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                final filtered = _filterStatus == "all"
                    ? docs
                    : docs.where((d) =>
                        (d.data()['status'] ?? '').toString().toLowerCase() == _filterStatus
                      ).toList();

                if (filtered.isEmpty) {
                  return _buildEmptyState();
                }

                return FadeTransition(
                  opacity: _animController,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final data = filtered[index].data();
                      final docId = filtered[index].id;
                      final status = data['status'] ?? 'Pending';
                      final statusColor = _getStatusColor(status);

                      return _buildBookingCard(
                        context: context,
                        route: data['route'] ?? data['pickupAddress'] ?? 'Unknown Route',
                        distance: data['distance'] ?? '',
                        price: (data['totalFare'] ?? data['price'] ?? '0').toString(),
                        status: status,
                        statusColor: statusColor,
                        icon: _getStatusIcon(status),
                        createdAt: data['createdAt'] as Timestamp?,
                        onStatusChange: (newStatus) async {
                          await _firestoreService.updateBookingStatus(docId, newStatus);
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF185A9D).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.receipt_long_rounded, size: 60, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 20),
          Text("No bookings yet", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          Text("Tap '+' to create your first booking", style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildBookingCard({
    required BuildContext context,
    required String route,
    required String distance,
    required String price,
    required String status,
    required Color statusColor,
    required IconData icon,
    Timestamp? createdAt,
    required Future<void> Function(String) onStatusChange,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateStr = createdAt != null 
        ? DateFormat('dd MMM yyyy, hh:mm a').format(createdAt.toDate())
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E272E) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: statusColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        route,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        distance.isNotEmpty ? "$distance km" : "",
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                      if (dateStr.isNotEmpty)
                        Text(
                          dateStr,
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                        ),
                    ],
                  ),
                ),
                Text(
                  "₹$price",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF185A9D),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(_capitalize(status), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                PopupMenuButton<String>(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF185A9D).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("Update", style: TextStyle(color: Color(0xFF185A9D), fontWeight: FontWeight.bold, fontSize: 12)),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF185A9D)),
                      ],
                    ),
                  ),
                  onSelected: (val) => onStatusChange(val),
                  itemBuilder: (_) => ["accepted", "pending", "in transit", "completed", "cancelled"]
                      .map((s) => PopupMenuItem(value: s, child: Text(_capitalize(s))))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
