import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:golorry_customer_app/utils/app_colors.dart';

class SkeletonLoader extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;
    
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF1E2028) : const Color(0xFFE0E0E0),
      highlightColor: isDark ? const Color(0xFF2A2E39) : const Color(0xFFF5F5F5),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
  
  /// A preset for activity cards
  static Widget activityCard() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const SkeletonLoader(width: 44, height: 44, borderRadius: 12),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(width: double.infinity, height: 14),
                SizedBox(height: 6),
                SkeletonLoader(width: 100, height: 10),
              ],
            ),
          ),
          const SizedBox(width: 20),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SkeletonLoader(width: 50, height: 14),
              SizedBox(height: 6),
              SkeletonLoader(width: 40, height: 12, borderRadius: 10),
            ],
          ),
        ],
      ),
    );
  }
}
