import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:golorry_customer_app/services/auth_service.dart';
import 'package:golorry_customer_app/utils/app_colors.dart';
import 'package:golorry_customer_app/screens/login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;
  bool _success = false; // Added success state based on screenshot

  /// Maps Firebase Auth error codes to clean user-facing messages.
  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'network-request-failed':
        return 'No internet connection. Please check your network and try again.';
      case 'email-already-in-use':
        return 'This email is already registered. Please log in instead.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'operation-not-allowed':
        return 'Sign-up is currently disabled. Please try later.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      default:
        return 'Sign up failed. Please try again.';
    }
  }

  Future<void> _signup() async {
    setState(() { _loading = true; _error = null; });

    try {
      if (_nameController.text.trim().isEmpty) {
        throw Exception('Please enter your Full Name.');
      }
      if (_emailController.text.trim().isEmpty) {
        throw Exception('Please enter your Email Address.');
      }
      if (_passwordController.text.length < 6) {
        setState(() => _error = 'Password must be at least 6 characters.');
        return;
      }

      await _authService.signUpWithProfile(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        password: _passwordController.text.trim(),
      );

      setState(() => _success = true);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _friendlyAuthError(e));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted && !_success) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // Back Button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),

                  // Header
                  const SizedBox(height: 10),
                  const Icon(
                    Icons.local_shipping_rounded,
                    size: 80,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Create Account',
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Join GoLorry as a Customer',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Form Card
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 24),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                            ),
                            child: Column(
                              children: [
                                _buildTextField(
                                  controller: _nameController,
                                  icon: Icons.person_outline_rounded,
                                  hint: 'Full Name',
                                  isDark: isDark,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _emailController,
                                  icon: Icons.email_outlined,
                                  hint: 'Email Address',
                                  isDark: isDark,
                                  inputType: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _phoneController,
                                  icon: Icons.phone_iphone_rounded,
                                  hint: 'Phone Number',
                                  isDark: isDark,
                                  inputType: TextInputType.phone,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _passwordController,
                                  icon: Icons.lock_outline_rounded,
                                  hint: 'Password',
                                  isPassword: true,
                                  obscureText: _obscurePassword,
                                  onVisibilityToggle: () {
                                    setState(() => _obscurePassword = !_obscurePassword);
                                  },
                                  isDark: isDark,
                                ),

                                if (_error != null) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.wifi_off_rounded,
                                            size: 16,
                                            color: AppColors.error),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _error!,
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              color: AppColors.error,
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                        if (_error!.contains('internet') || _error!.contains('network'))
                                          GestureDetector(
                                            onTap: _signup,
                                            child: Padding(
                                              padding: const EdgeInsets.only(left: 8),
                                              child: Text(
                                                'Retry',
                                                style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.error,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 24),

                                // Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: ElevatedButton(
                                    onPressed: _loading ? null : _signup,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1D4ED8),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: _loading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Text(
                                            'Sign Up',
                                            style: GoogleFonts.inter(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Login bottom text
                          GestureDetector(
                            onTap: () => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                            ),
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                                children: [
                                  const TextSpan(text: "Already have an account? "),
                                  TextSpan(
                                    text: 'Login',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Success Overlay (matches the 3rd screenshot)
              if (_success)
                Container(
                  color: Colors.black.withValues(alpha: 0.6),
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surface : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Success',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.textPrimary : const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Hii Customer, Your account creation is successful',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: isDark ? AppColors.textSecondary : const Color(0xFF4B5563),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {},
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                              ),
                              child: Text(
                                'OK',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
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
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    TextInputType inputType = TextInputType.text,
    bool isPassword = false,
    bool? obscureText,
    VoidCallback? onVisibilityToggle,
    required bool isDark,
  }) {
    final bgColor = Colors.white.withValues(alpha: 0.15);
    final iconColor = Colors.white.withValues(alpha: 0.8);
    const textColor = Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText ?? false,
        keyboardType: inputType,
        style: GoogleFonts.inter(color: textColor, fontSize: 16, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5), fontSize: 16),
          prefixIcon: Icon(icon, color: iconColor, size: 22),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    obscureText! ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: iconColor,
                    size: 22,
                  ),
                  onPressed: onVisibilityToggle,
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.white, width: 1.5),
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
      ),
    );
  }
}
