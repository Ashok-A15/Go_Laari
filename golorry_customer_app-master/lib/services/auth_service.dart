import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Handles Firebase Authentication and the linked Firestore user profile.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Auth State ────────────────────────────────────
  Stream<User?> authStateChanges() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // ── Sign In ───────────────────────────────────────
  /// Authenticates an existing user with email + password.
  Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  // ── Sign Up ───────────────────────────────────────
  /// Creates a Firebase Auth account AND saves the user profile
  /// document to Firestore `users/{uid}` in one call.
  Future<UserCredential> signUpWithProfile({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    debugPrint('🔵 [AuthService] Project: ${_db.app.options.projectId}');
    debugPrint('🔵 [AuthService] Creating Auth account for $email…');

    // 1) Create Firebase Auth account
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    final uid = credential.user!.uid;
    debugPrint('✅ [AuthService] Auth account created. UID=$uid');

    // 2) Save user profile to Firestore
    debugPrint('🔵 [AuthService] Writing Firestore users/$uid …');
    await _db.collection('users').doc(uid).set({
      'uid': uid,
      'name': name.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'role': 'customer',
      'totalTrips': 0,
      'totalSpend': 0.0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    debugPrint('✅ [AuthService] Firestore user doc written!');

    // 3) Update display name on Auth profile
    await credential.user!.updateDisplayName(name.trim());

    return credential;
  }

  // ── Sign Out ──────────────────────────────────────
  Future<void> signOut() async => _auth.signOut();

  // ── Change Password ───────────────────────────────
  /// Re-authenticates with [currentPassword] then updates to [newPassword].
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) throw Exception('Not signed in');

    // Re-authenticate first (required by Firebase for sensitive operations)
    final cred = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(cred);
    await user.updatePassword(newPassword);
  }
}
