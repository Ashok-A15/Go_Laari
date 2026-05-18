import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:golorry_customer_app/screens/auth_gate.dart';
import 'package:golorry_customer_app/utils/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Force Legacy Maps Renderer & Hybrid Composition (AndroidViewSurface) to completely resolve green/blank map rendering bugs on low-end hardware
  final GoogleMapsFlutterPlatform mapsImplementation = GoogleMapsFlutterPlatform.instance;
  if (mapsImplementation is GoogleMapsFlutterAndroid) {
    mapsImplementation.useAndroidViewSurface = true;
    try {
      await mapsImplementation.initializeWithRenderer(AndroidMapRenderer.legacy);
      debugPrint('DEBUG [Maps]: Successfully initialized Google Maps with Renderer.legacy');
    } catch (e) {
      debugPrint('DEBUG [Maps]: Legacy renderer initialization skipped or already initialized: $e');
    }
  }

  // Initialise color values for the default theme (dark) immediately
  AppColors.init();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const GoLorryApp());
}

class GoLorryApp extends StatelessWidget {
  const GoLorryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppColors.themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          title: 'GoLorry',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          // Light Theme configuration
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1D4ED8),
              brightness: Brightness.light,
            ),
            textTheme: GoogleFonts.interTextTheme(),
            scaffoldBackgroundColor: const Color(0xFFF3F4F6),
          ),
          // Dark Theme configuration
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1D4ED8),
              brightness: Brightness.dark,
              surface: const Color(0xFF0F172A),
            ),
            textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
            scaffoldBackgroundColor: const Color(0xFF0F172A),
          ),
          home: const AuthGate(),
        );
      },
    );
  }
}
