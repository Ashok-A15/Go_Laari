import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Pages
import 'pages/role_selection_page.dart';
import 'pages/welcome_auth_page.dart';
import 'pages/login_page.dart';
import 'pages/signup_page.dart';
import 'pages/owner_dashboard_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const GoLorryOwnerApp());
}

class GoLorryOwnerApp extends StatelessWidget {
  const GoLorryOwnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "GO Lorry Owner",
      theme: ThemeData(
        primaryColor: Colors.green,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        fontFamily: "Roboto",
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          iconTheme: IconThemeData(color: Colors.black),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedItemColor: Colors.green,
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.white,
          elevation: 8,
        ),
      ),

      // 👉 Routes for Navigation
      routes: {
        "/welcome": (_) => const WelcomeAuthPage(),
        "/login": (_) => const LoginPage(),
        "/signup": (_) => SignupPage(),
        "/dashboard": (_) => const OwnerDashboardPage(),
      },

      // 👉 App starts from Role Selection Screen
      home: const RoleSelectionPage(),
    );
  }
}
