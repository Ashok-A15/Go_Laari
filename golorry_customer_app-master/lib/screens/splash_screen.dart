import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:golorry_customer_app/screens/dashboard_screen.dart';
import 'package:golorry_customer_app/screens/auth_screen.dart';
import 'package:golorry_customer_app/screens/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _gController;
  
  // App Icon animations
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

  // Custom G animations
  late Animation<double> _glowScale;
  late Animation<double> _gOpacity;
  late Animation<double> _truckProgress;
  late Animation<double> _wheelRotation;
  late Animation<double> _textFadeIn;
  late Animation<double> _textScale;
  late Animation<double> _exitProgress;

  bool _showCustomG = false;

  @override
  void initState() {
    super.initState();

    // 1. Initial Logo Presentation (0 to 2.5 seconds)
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _logoOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 30), // Fade in
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 50),          // Hold
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 20), // Fade out
    ]).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeInOut));

    _logoScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.5, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 40),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.8).chain(CurveTween(curve: Curves.easeInBack)), weight: 20),
    ]).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeInOut));

    // 2. Custom G animation (after logo controller completes)
    _gController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );

    _glowScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _gController, curve: const Interval(0.0, 0.25, curve: Curves.easeOut)),
    );
    _gOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _gController, curve: const Interval(0.1, 0.35, curve: Curves.easeIn)),
    );

    _truckProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _gController, curve: const Interval(0.2, 0.75, curve: Curves.easeInOutCubic)),
    );

    _wheelRotation = Tween<double>(begin: 0.0, end: 10 * math.pi).animate(
      CurvedAnimation(parent: _gController, curve: const Interval(0.2, 0.75, curve: Curves.linear)),
    );

    _textFadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _gController, curve: const Interval(0.6, 0.8, curve: Curves.easeIn)),
    );
    _textScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _gController, curve: const Interval(0.6, 0.85, curve: Curves.elasticOut)),
    );

    _exitProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _gController, curve: const Interval(0.85, 1.0, curve: Curves.easeInCubic)),
    );

    _runSplashPipeline();
  }

  Future<void> _runSplashPipeline() async {
    await _logoController.forward();
    if (!mounted) return;
    setState(() {
      _showCustomG = true;
    });
    await _gController.forward();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    Widget nextPage;
    
    if (user != null) {
      nextPage = const DashboardScreen();
    } else {
      final prefs = await SharedPreferences.getInstance();
      final onboardingDone = prefs.getBool('onboarding_done') ?? false;
      if (onboardingDone) {
        nextPage = const AuthScreen();
      } else {
        nextPage = const OnboardingScreen();
      }
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (context, animation, secondaryAnimation) => nextPage,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _gController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E12),
      body: Stack(
        children: [
          // 1. Initial Logo Presentation
          if (!_showCustomG)
            Center(
              child: AnimatedBuilder(
                animation: _logoController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _logoOpacity.value,
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 15,
                              offset: Offset(0, 5),
                            )
                          ],
                        ),
                        child: ClipOval(
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Image.asset(
                              'assets/app_icon.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // 2. Cinematic 3D Lorry & G Logo Transition
          if (_showCustomG)
            AnimatedBuilder(
              animation: _gController,
              builder: (context, child) {
                double exitMove = _exitProgress.value * 500;
                double exitOpacity = 1.0 - _exitProgress.value;

                return Stack(
                  children: [
                    // Glowing background
                    Center(
                      child: Opacity(
                        opacity: _glowScale.value * 0.4 * exitOpacity,
                        child: Container(
                          width: 320 * _glowScale.value,
                          height: 320 * _glowScale.value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.blueAccent.withValues(alpha: 0.3),
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
                              // Smooth Vector Lorry along G
                              SizedBox(
                                width: 160,
                                height: 160,
                                child: CustomPaint(
                                  painter: GLogoPainter(
                                    logoProgress: _gOpacity.value,
                                    truckProgress: _truckProgress.value,
                                    wheelRotation: _wheelRotation.value,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 30),

                              // Text Reveal
                              Opacity(
                                opacity: _textFadeIn.value,
                                child: Transform.scale(
                                  scale: _textScale.value,
                                  child: const Text(
                                    "GoLorry",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 38,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2.0,
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
        ],
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

    // Draw the "G" base path
    final Path gPath = Path();
    gPath.addArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 4,
      -1.6 * math.pi,
    );
    gPath.lineTo(center.dx + radius * 0.2, center.dy);

    if (logoProgress > 0) {
      canvas.drawPath(gPath, gPaint..color = gPaint.color.withOpacity(logoProgress));
    }

    // Animate Lorry along the top curve
    final Path truckPath = Path();
    truckPath.addArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi / 3,
    );

    final PathMetrics pathMetrics = truckPath.computeMetrics();
    final PathMetric metric = pathMetrics.first;
    final Tangent? tangent = metric.getTangentForOffset(metric.length * truckProgress);

    if (tangent != null && logoProgress > 0.5) {
      canvas.save();
      canvas.translate(tangent.position.dx, tangent.position.dy);
      canvas.rotate(-tangent.angle);

      // Light trail
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

      final Paint lorryPaint = Paint()..color = Colors.white.withOpacity(logoProgress);
      final lorryRect = Rect.fromLTWH(-15, -12, 30, 18);

      // Lorry Body
      canvas.drawRRect(
        RRect.fromRectAndRadius(lorryRect, const Radius.circular(3)),
        lorryPaint,
      );

      // Lorry Cabin
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

    canvas.drawLine(const Offset(-3.5, 0), const Offset(3.5, 0), rimPaint);
    canvas.drawLine(const Offset(0, -3.5), const Offset(0, 3.5), rimPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GLogoPainter oldDelegate) => true;
}
