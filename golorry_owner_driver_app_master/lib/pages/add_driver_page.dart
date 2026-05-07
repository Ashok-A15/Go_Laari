import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../services/firestore_service.dart';
import '../firebase_options.dart';

class AddDriverPage extends StatefulWidget {
  const AddDriverPage({super.key});

  @override
  State<AddDriverPage> createState() => _AddDriverPageState();
}

class _AddDriverPageState extends State<AddDriverPage> {
  final _formKey = GlobalKey<FormState>();
  final FirestoreService _firestoreService = FirestoreService();
  
  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _vehicleController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();

  bool _obscurePassword = true;
  bool _isSuccess = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _generateSystemEmail();
  }

  void _generateSystemEmail() {
    // Generate a system email like dr1234@golorry.com
    final random = Random();
    final id = "${1000 + random.nextInt(9000)}";
    _emailController.text = "dr$id@golorry.com";
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        // Create a secondary Firebase App instance to create the driver account
        // without logging out the current Owner session.
        FirebaseApp secondaryApp = await Firebase.initializeApp(
          name: 'DriverCreationApp',
          options: DefaultFirebaseOptions.currentPlatform,
        );

        FirebaseAuth secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

        // 1. Create User in Firebase Auth
        UserCredential userCredential = await secondaryAuth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // 2. Save Driver Profile in Firestore
        await _firestoreService.createDriverProfile(
          userCredential.user!.uid,
          {
            'ownerId': _firestoreService.currentUid,
            'name': _nameController.text.trim(),
            'email': _emailController.text.trim(),
            'phone': _mobileController.text.trim(),
            'vehicleNumber': _vehicleController.text.trim(),
            'status': 'active',
          },
        );

        // 3. Clean up the secondary app
        await secondaryApp.delete();

        setState(() {
          _isSuccess = true;
          _isLoading = false;
        });
      } on FirebaseAuthException catch (e) {
        setState(() => _isLoading = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? "Creation failed")),
        );
      } catch (e) {
        setState(() => _isLoading = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Credentials copied to clipboard")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_isSuccess) {
      return _buildSuccessState();
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F171A) : const Color(0xFFF8FAF9),
      appBar: AppBar(
        title: const Text("Create Driver Account"),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Header ---
              const Text(
                "Driver Identity",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                "Generate secure login details for your fleet driver",
                style: TextStyle(color: Colors.grey.shade600),
              ),
              
              const SizedBox(height: 30),
              
              // --- Driver Details Card ---
              _buildSectionTitle("Personal Details"),
              const SizedBox(height: 12),
              _buildCard(
                context,
                [
                  _buildTextField(
                    controller: _nameController,
                    label: "Driver Name",
                    hint: "Full name",
                    icon: Icons.person_rounded,
                    validator: (v) => v!.isEmpty ? "Enter driver name" : null,
                  ),
                  const Divider(height: 32),
                  _buildTextField(
                    controller: _mobileController,
                    label: "Mobile Number",
                    hint: "+91 00000 00000",
                    icon: Icons.phone_android_rounded,
                    keyboard: TextInputType.phone,
                    validator: (v) {
                      if (v!.isEmpty) return "Enter mobile number";
                      if (v.length < 10) return "Enter valid 10-digit number";
                      return null;
                    },
                  ),
                  const Divider(height: 32),
                  _buildTextField(
                    controller: _vehicleController,
                    label: "Vehicle / Lorry Number",
                    hint: "KA 01 AB 1234",
                    icon: Icons.local_shipping_rounded,
                    validator: (v) => v!.isEmpty ? "Enter vehicle number" : null,
                  ),
                ],
              ),
              
              const SizedBox(height: 30),
              
              // --- Credentials Card ---
              _buildSectionTitle("Login Credentials"),
              const SizedBox(height: 4),
              Text(
                "Driver will use this Email (or Driver ID) to login",
                style: TextStyle(fontSize: 12, color: Colors.blue.shade700, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              _buildCard(
                context,
                [
                  _buildTextField(
                    controller: _emailController,
                    label: "Login Email / Driver ID",
                    hint: "dr0000@golorry.com",
                    icon: Icons.alternate_email_rounded,
                    keyboard: TextInputType.emailAddress,
                    validator: (v) {
                      if (v!.isEmpty) return "Provide an email or system ID";
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
                        return "Enter a valid email format";
                      }
                      return null;
                    },
                  ),
                  const Divider(height: 32),
                  _buildTextField(
                    controller: _passwordController,
                    label: "Create Password",
                    hint: "Min. 6 characters",
                    icon: Icons.lock_rounded,
                    isPassword: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    validator: (v) {
                      if (v!.isEmpty) return "Create a password";
                      if (v.length < 6) return "Password too weak (min 6 chars)";
                      return null;
                    },
                  ),
                  const Divider(height: 32),
                  _buildTextField(
                    controller: _confirmPassController,
                    label: "Confirm Password",
                    hint: "Re-type password",
                    icon: Icons.lock_outline_rounded,
                    isPassword: _obscurePassword,
                    validator: (v) {
                      if (v != _passwordController.text) return "Passwords do not match";
                      return null;
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 40),
              
              // --- Buttons ---
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    backgroundColor: const Color(0xFF185A9D),
                  ),
                  child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Create Driver Account", style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel & Go Back", style: TextStyle(color: Colors.grey.shade600)),
                ),
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildCard(BuildContext context, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    required IconData icon,
    TextInputType? keyboard,
    bool isPassword = false,
    bool readOnly = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      readOnly: readOnly,
      keyboardType: keyboard,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        prefixIcon: Icon(icon, color: const Color(0xFF43CEA2), size: 22),
        suffixIcon: suffixIcon,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      ),
    );
  }

  Widget _buildSuccessState() {
    final credentials = "Email: ${_emailController.text}\nPassword: ${_passwordController.text}";

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF43CEA2).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF43CEA2), size: 80),
              ),
              const SizedBox(height: 32),
              const Text(
                "Driver Account Created!",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                "The driver can now log in using these credentials on the main login screen.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              
              const SizedBox(height: 40),
              
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF43CEA2).withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    _credentialRow("Login Email", _emailController.text),
                    const Divider(height: 24),
                    _credentialRow("Password", _passwordController.text),
                  ],
                ),
              ),
              
              const SizedBox(height: 30),
              
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _copyToClipboard(credentials),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text("Copy"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF185A9D),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Placeholder for WhatsApp share
                      },
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text("WhatsApp"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Color(0xFF185A9D)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text("Done & Finish", style: TextStyle(color: Color(0xFF185A9D))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _credentialRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5)),
      ],
    );
  }
}
