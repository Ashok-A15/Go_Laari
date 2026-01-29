import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dashboard_page.dart';

class PhoneLoginPage extends StatefulWidget {
  const PhoneLoginPage({super.key});

  @override
  State<PhoneLoginPage> createState() => _PhoneLoginPageState();
}

class _PhoneLoginPageState extends State<PhoneLoginPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isLampOn = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController otpController = TextEditingController();

  String verificationId = "";
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    phoneController.dispose();
    otpController.dispose();
    super.dispose();
  }

  void _toggleLamp() {
    setState(() {
      _isLampOn = !_isLampOn;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121921),
      body: Stack(
        children: [
          // Animated background
          AnimatedContainer(
            duration: const Duration(seconds: 1),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: _isLampOn
                    ? [const Color(0xFF2A2D3A), const Color(0xFF121921)]
                    : [const Color(0xFF121921), const Color(0xFF0A0A0A)],
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Lamp Widget
                  GestureDetector(
                    onTap: _toggleLamp,
                    child: AnimatedBuilder(
                      animation: _animation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _isLampOn ? _animation.value : 1.0,
                          child: LampWidget(isOn: _isLampOn),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 40),

                  const Text(
                    "Phone Login",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 30),

                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: "Phone Number",
                      labelStyle: TextStyle(color: Colors.white70),
                      prefixIcon: Icon(Icons.phone, color: Colors.white70),
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white70),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isLoading
                          ? null
                          : () async {
                              setState(() => _isLoading = true);
                              await _auth.verifyPhoneNumber(
                                phoneNumber: "+91${phoneController.text}",
                                verificationCompleted: (credential) async {
                                  await _auth.signInWithCredential(credential);
                                  if (!mounted) return;
                                  // ignore: use_build_context_synchronously
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const DashboardPage(),
                                    ),
                                  );
                                },
                                verificationFailed: (e) {
                                  if (mounted) {
                                    // ignore: use_build_context_synchronously
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(e.message ?? "Error")),
                                    );
                                  }
                                },
                                codeSent: (id, _) {
                                  verificationId = id;
                                  if (mounted) {
                                    // ignore: use_build_context_synchronously
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("OTP Sent")),
                                    );
                                  }
                                },
                                codeAutoRetrievalTimeout: (_) {},
                              );
                              setState(() => _isLoading = false);
                            },
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Send OTP"),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: "Enter OTP",
                      labelStyle: TextStyle(color: Colors.white70),
                      prefixIcon: Icon(Icons.lock, color: Colors.white70),
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white70),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        try {
                          PhoneAuthCredential cred = PhoneAuthProvider.credential(
                            verificationId: verificationId,
                            smsCode: otpController.text,
                          );

                          await _auth.signInWithCredential(cred);

                          if (!mounted) return;
                          // ignore: use_build_context_synchronously
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DashboardPage(),
                            ),
                          );
                        } catch (e) {
                          if (mounted) {
                            // ignore: use_build_context_synchronously
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Error: $e")),
                            );
                          }
                        }
                      },
                      child: const Text("Verify OTP"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LampWidget extends StatelessWidget {
  final bool isOn;

  const LampWidget({super.key, required this.isOn});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 300,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Lamp shade
          Positioned(
            top: 0,
            child: Container(
              width: 120,
              height: 80,
              decoration: BoxDecoration(
                color: isOn ? Colors.yellow.withOpacity(0.8) : Colors.grey,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(60),
                  bottomRight: Radius.circular(60),
                ),
              ),
            ),
          ),
          // Lamp base
          Positioned(
            bottom: 0,
            child: Container(
              width: 80,
              height: 40,
              decoration: BoxDecoration(
                color: isOn ? Colors.orange : Colors.grey[700],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
              ),
            ),
          ),
          // Lamp post
          Positioned(
            top: 80,
            bottom: 40,
            child: Container(
              width: 10,
              decoration: BoxDecoration(
                color: isOn ? Colors.brown[300] : Colors.grey[600],
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
          // Lamp light
          if (isOn)
            Positioned(
              top: 80,
              left: 40,
              right: 40,
              bottom: 40,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.yellow.withOpacity(0.6),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          // Eyes and mouth
          Positioned(
            top: 20,
            left: 50,
            right: 50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 40,
            left: 60,
            right: 60,
            child: Container(
              height: 10,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
          // Cord
          Positioned(
            top: 0,
            left: 95,
            child: Container(
              width: 10,
              height: 50,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
