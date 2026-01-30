import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'role_selection_page.dart';
import 'owner_main_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  // Animations
  late Animation<double> _glowScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _truckProgress; // Progress along the G curve
  late Animation<double> _textFadeIn;
  late Animation<double> _textScale;
  late Animation<double> _exitProgress;
  late Animation<double> _wheelRotation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    );

    // 1. Glow & Logo Fade In (0.0 to 0.2)
    _glowScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.2, curve: Curves.easeOut)),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.1, 0.3, curve: Curves.easeIn)),
    );

    // 2. Lorry Motion along the curve (0.3 to 0.7)
    _truckProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.25, 0.75, curve: Curves.easeInOutCubic)),
    );

    // 3. Wheel Rotation (sync with motion)
    _wheelRotation = Tween<double>(begin: 0.0, end: 10 * math.pi).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.25, 0.75, curve: Curves.linear)),
    );

    // 4. Text Reveal (0.6 to 0.8)
    _textFadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.6, 0.8, curve: Curves.easeIn)),
    );
    _textScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.6, 0.85, curve: Curves.elasticOut)),
    );

    // 5. Exit Animation (0.85 to 1.0)
    _exitProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.9, 1.0, curve: Curves.easeInCubic)),
    );

    _controller.forward().then((_) => _navigateToNext());
  }

  void _navigateToNext() {
    if (!mounted) return;
    User? user = FirebaseAuth.instance.currentUser;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (context, animation, secondaryAnimation) => user != null ? const OwnerMainPage() : const RoleSelectionPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E12),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          double exitMove = _exitProgress.value * 500;
          double exitOpacity = 1.0 - _exitProgress.value;

          return Stack(
            children: [
              // Central Glow
              Center(
                child: Opacity(
                  opacity: _glowScale.value * 0.5,
                  child: Container(
                    width: 300 * _glowScale.value,
                    height: 300 * _glowScale.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.blueAccent.withOpacity(0.35),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              Center(
                child: Opacity(
                  opacity: exitOpacity,
                  child: Transform.translate(
                    offset: Offset(exitMove, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Animated G Logo and Truck
                        SizedBox(
                          width: 150,
                          height: 150,
                          child: CustomPaint(
                            painter: GLogoPainter(
                              logoProgress: _logoOpacity.value,
                              truckProgress: _truckProgress.value,
                              wheelRotation: _wheelRotation.value,
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        
                        // "GoLorry" Text Reveal
                        Opacity(
                          opacity: _textFadeIn.value,
                          child: Transform.scale(
                            scale: _textScale.value,
                            child: const Text(
                              "GoLorry",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class GLogoPainter extends CustomPainter {
  final double logoProgress;
  final double truckProgress;
  final double wheelRotation;

  GLogoPainter({
    required this.logoProgress,
    required this.truckProgress,
    required this.wheelRotation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.35;

    final Paint gPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [Color(0xFF43CEA2), Color(0xFF185A9D)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    // 1. Draw the "G" base path
    final Path gPath = Path();
    // Circular arc from top-right around to bottom-right
    gPath.addArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 4, // Starts slightly above the horizontal
      -1.6 * math.pi, // Sweeps counter-clockwise
    );
    
    // The "inward" stroke of G
    gPath.lineTo(center.dx + radius * 0.2, center.dy);

    if (logoProgress > 0) {
      canvas.drawPath(gPath, gPaint..color = gPaint.color.withOpacity(logoProgress));
    }

    // 2. Animate Lorry along the top curve
    // Define the path specifically for the lorry (top section of G)
    final Path truckPath = Path();
    truckPath.addArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // 12 o'clock
      math.pi / 3,  // Sweeps towards 2 o'clock
    );

    final PathMetrics pathMetrics = truckPath.computeMetrics();
    final PathMetric metric = pathMetrics.first;
    
    // Position the truck based on progress
    final Tangent? tangent = metric.getTangentForOffset(metric.length * truckProgress);
    
    if (tangent != null && logoProgress > 0.5) {
      canvas.save();
      canvas.translate(tangent.position.dx, tangent.position.dy);
      canvas.rotate(-tangent.angle); // Align with path curve

      // Draw light trail
      if (truckProgress > 0.1) {
        final Paint trailPaint = Paint()
          ..strokeWidth = 10
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(
            colors: [Colors.white.withOpacity(0.0), const Color(0xFF43CEA2).withOpacity(0.4)],
          ).createShader(const Rect.fromLTWH(-60, -5, 60, 10));
        
        canvas.drawLine(const Offset(-40, 0), const Offset(0, 0), trailPaint);
      }

      // Draw Lorry Icon/Shape (Simplified but matching reference)
      final Paint lorryPaint = Paint()..color = Colors.white.withOpacity(logoProgress);
      final lorryRect = Rect.fromLTWH(-15, -12, 30, 18);
      
      // Lorry Body
      canvas.drawRRect(
        RRect.fromRectAndRadius(lorryRect, const Radius.circular(3)),
        lorryPaint,
      );
      
      // Lorry Cabin (Small box in front)
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          const Rect.fromLTWH(15, -12, 10, 18),
          topRight: const Radius.circular(5),
          bottomRight: const Radius.circular(2),
        ),
        lorryPaint,
      );

      // Wheels
      _drawWheel(canvas, const Offset(-8, 8), wheelRotation, logoProgress);
      _drawWheel(canvas, const Offset(8, 8), wheelRotation, logoProgress);
      _drawWheel(canvas, const Offset(18, 8), wheelRotation, logoProgress);

      canvas.restore();
    }
  }

  void _drawWheel(Canvas canvas, Offset offset, double rotation, double opacity) {
    final wheelPaint = Paint()..color = Colors.black.withOpacity(opacity * 0.7);
    final rimPaint = Paint()
      ..color = Colors.white.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.rotate(rotation);
    
    canvas.drawCircle(Offset.zero, 3.5, wheelPaint);
    canvas.drawCircle(Offset.zero, 3.5, rimPaint);
    
    // Draw wheel spokes to show rotation
    canvas.drawLine(const Offset(-3.5, 0), const Offset(3.5, 0), rimPaint);
    canvas.drawLine(const Offset(0, -3.5), const Offset(0, 3.5), rimPaint);
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GLogoPainter oldDelegate) => true;
}
