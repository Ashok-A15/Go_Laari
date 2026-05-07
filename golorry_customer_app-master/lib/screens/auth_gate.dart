import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_screen.dart';
import 'auth_screen.dart';
import 'onboarding_screen.dart';
import '../utils/app_colors.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        // Logged in -> go right to Dashboard
        if (snapshot.hasData) {
          return const DashboardScreen();
        }

        // Not logged in -> Checking Onboarding
        return FutureBuilder<SharedPreferences>(
          future: SharedPreferences.getInstance(),
          builder: (context, prefsSnapshot) {
            if (!prefsSnapshot.hasData) {
              return Scaffold(
                backgroundColor: AppColors.background,
                body: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              );
            }
            
            final prefs = prefsSnapshot.data!;
            final done = prefs.getBool('onboarding_done') ?? false;
            
            if (done) {
              return const AuthScreen(); // We import this
            } else {
              return const OnboardingScreen();
            }
          },
        );
      },
    );
  }
}
