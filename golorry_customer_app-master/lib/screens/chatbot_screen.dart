import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:golorry_customer_app/utils/app_colors.dart';
import 'package:lottie/lottie.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> with TickerProviderStateMixin {
  final List<Map<String, dynamic>> _messages = [
    {
      'role': 'assistant',
      'content': 'Hello! I am your GoLorry AI assistant. How can I help you streamline your logistics today?',
      'time': '1:15 PM',
      'options': ['Book a Truck', 'Track My Load', 'Check Pricing', 'Other / Type Problem'],
    }
  ];

  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late AnimationController _orbController;

  // Voice State
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _lastWords = '';

  // ── GEMINI AI CONFIG ───────────────────────────
  // TODO: Replace with your actual API Key from https://aistudio.google.com/
  static const _apiKey = 'AIzaSyChcZi_oo6iKpg_I34UuGd1zSSzqeFEdc4';
  late GenerativeModel _model;
  late ChatSession _chat;
  bool _isAITyping = false;

  // ── AI BACKEND CONFIG ──────────────────────────
  // Using 10.0.2.2 for Android Emulator, localhost for iOS/Web/Desktop
  final String _backendUrl = 'http://10.0.2.2:8000/chat'; 
  String? _userId;

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _initSpeech();
    _initAI();
    _loadUser();
  }

  void _initSpeech() async {
    _speech = stt.SpeechToText();
  }

  void _toggleListening() async {
    if (!_isListening) {
      var status = await Permission.microphone.request();
      if (status.isDenied) return;

      bool available = await _speech.initialize(
        onStatus: (val) => print('onStatus: $val'),
        onError: (val) => print('onError: $val'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            _lastWords = val.recognizedWords;
            if (val.hasConfidenceRating && val.confidence > 0) {
              _controller.text = _lastWords;
            }
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() {
        _messages.add({
          'role': 'user',
          'content': 'Shared an image',
          'imagePath': image.path,
          'time': 'Just now',
        });
      });
      _scrollToBottom();
      
      // Simulate AI response to image
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          _addBotMessage("I've received your image! I'm analyzing the details of your shipment documents now...");
        }
      });
    }
  }

  void _addBotMessage(String text) {
    setState(() {
      _messages.add({
        'role': 'assistant',
        'content': text,
        'time': 'Just now',
      });
    });
    _scrollToBottom();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('chatbot_user_id');
    if (_userId == null) {
      _userId = 'user_${Random().nextInt(10000)}';
      await prefs.setString('chatbot_user_id', _userId!);
    }
  }

  void _initAI() {
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: _apiKey,
      systemInstruction: Content.system(
        'You are GoLorry Assistant, a premium AI logistics expert for the GoLorry Customer App in India. '
        'Your goal is to help users book trucks, track shipments, and understand freight pricing. '
        'Be professional, helpful, and tech-savvy. '
        'Pricing: Local trips start at ₹500. Long distance depends on mileage. '
        'Services: We offer "Regular" (dedicated lorry) and "Pooling" (shared cost). '
        'Booking: Users can book in the Home tab by entering pickup/drop points. '
        'Tracking: Active loads are visible in the Orders tab. '
        'If the user has a problem, offer to raise a support ticket.'
      ),
    );
    _chat = _model.startChat();
  }

  @override
  void dispose() {
    _orbController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_controller.text.isEmpty) return;
    final msg = _controller.text;
    setState(() {
      _messages.add({
        'role': 'user',
        'content': msg,
        'time': '1:16 PM',
      });
      _controller.clear();
    });
    _scrollToBottom();

    // Simulate AI thinking
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _handleAIResponse(msg);
      }
    });
  }

  void _handleAIResponse(String input) async {
    setState(() => _isAITyping = true);
    _scrollToBottom();

    try {
      // 1. TRY THE ML BACKEND (FastAPI)
      final response = await http.post(
        Uri.parse(_backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': input,
          'user_id': _userId ?? 'default_user',
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['response'];
        final intent = data['intent'];

        setState(() {
          _isAITyping = false;
          _messages.add({
            'role': 'assistant',
            'content': text,
            'time': TimeOfDay.now().format(context),
            'options': _suggestOptions(intent, text),
          });
        });
        _scrollToBottom();
        return;
      }
    } catch (e) {
      print("Local backend error, falling back to Gemini: $e");
    }

    // 2. FALLBACK TO GEMINI
    if (_apiKey != 'REPLACE_WITH_YOUR_GEMINI_API_KEY') {
      try {
        final response = await _chat.sendMessage(Content.text(input));
        final text = response.text ?? "I'm sorry, I couldn't process that.";
        
        setState(() {
          _isAITyping = false;
          _messages.add({
            'role': 'assistant',
            'content': text,
            'time': TimeOfDay.now().format(context),
            'options': _suggestOptions('unknown', text),
          });
        });
      } catch (e) {
        setState(() => _isAITyping = false);
        _handleMockResponse(input);
      }
    } else {
      setState(() => _isAITyping = false);
      _handleMockResponse(input);
    }
    _scrollToBottom();
  }

  // Fallback / Mock logic if API key is missing
  void _handleMockResponse(String input) {
    String response = '';
    List<String>? nextOptions;

    final lower = input.toLowerCase();
    if (lower.contains('book')) {
      response = 'To book a truck, head to the Home tab, enter your locations, and select "Proceed".';
      nextOptions = ['Check Pricing', 'Service Tiers'];
    } else if (lower.contains('track')) {
      response = 'You can track all active shipments in the "Orders" tab. Live location is available once assigned.';
      nextOptions = ['Talk to Support', 'Book a Truck'];
    } else {
      response = 'I have analyzed your concern: "$input". I have raised a priority support ticket for you. An expert will contact you within 15 minutes.';
      nextOptions = ['Talk to Support', 'Main Menu'];
    }

    setState(() {
      _messages.add({
        'role': 'assistant',
        'content': response,
        'time': TimeOfDay.now().format(context),
        'options': nextOptions,
      });
    });
    _scrollToBottom();
  }

  List<String> _suggestOptions(String intent, String response) {
    if (intent == 'book_truck') return ['Change Destination', 'View Rates'];
    if (intent == 'track_order') return ['Live Location', 'Order Details'];
    if (intent == 'pricing') return ['Get Quote', 'View Tiers'];
    
    final lower = response.toLowerCase();
    if (lower.contains('book')) return ['Book a Truck', 'Check Pricing'];
    if (lower.contains('track')) return ['Track My Load', 'Talk to Support'];
    return ['Book a Truck', 'Check Pricing', 'Other Support'];
  }

  void _onOptionSelected(String option) {
    setState(() {
      _messages.add({
        'role': 'user',
        'content': option,
        'time': '1:18 PM',
      });
    });
    Future.delayed(const Duration(milliseconds: 800), () => _handleAIResponse(option));
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Premium Dark Navy + Teal Theme
    final bgColor = const Color(0xFF0F172A); // Dark Navy
    final tealGlow = const Color(0xFF2DD4BF); // Teal
    
    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // ── BACKGROUND GLOWS ───────────────────────
          Positioned(
            top: -100,
            right: -50,
            child: _GlowCircle(color: tealGlow.withValues(alpha: 0.15), size: 300),
          ),
          Positioned(
            bottom: 100,
            left: -100,
            child: _GlowCircle(color: const Color(0xFF3B82F6).withValues(alpha: 0.1), size: 400),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── TOP HEADER ────────────────────────
                _buildHeader(tealGlow),

                // ── CHAT AREA ─────────────────────────
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 140),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) => _buildMessage(_messages[index], tealGlow),
                  ),
                ),
              ],
            ),
          ),

          // ── FLOATING INPUT BAR ─────────────────────
          _buildInputBar(tealGlow),
        ],
      ),
    );
  }

  Widget _buildHeader(Color teal) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 28),
                    const SizedBox(width: 10),
                    Text(
                      'GoLorry AI',
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Your Smart Logistics Assistant',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          // AI ORB AVATAR
          Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _orbController,
                builder: (context, child) {
                  return Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: teal.withValues(alpha: 0.4 * _orbController.value),
                          blurRadius: 15 + (10 * _orbController.value),
                          spreadRadius: 2 + (5 * _orbController.value),
                        )
                      ],
                      gradient: RadialGradient(
                        colors: [teal, teal.withValues(alpha: 0.2)],
                      ),
                    ),
                  );
                },
              ),
              const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 24),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildMessage(Map<String, dynamic> msg, Color teal) {
    final isUser = msg['role'] == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [teal, teal.withValues(alpha: 0.6)]),
              ),
              child: const Icon(Icons.smart_toy_rounded, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 12),
          ],
                      Flexible(
                        child: Column(
                          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Container(
                                decoration: BoxDecoration(
                                  color: isUser ? teal.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(20),
                                    topRight: const Radius.circular(20),
                                    bottomLeft: Radius.circular(isUser ? 20 : 4),
                                    bottomRight: Radius.circular(isUser ? 4 : 20),
                                  ),
                                  border: Border.all(
                                    color: isUser ? teal.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.1),
                                    width: 1,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Column(
                                    crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        msg['content'],
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: Colors.white,
                                          height: 1.4,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      if (msg['imagePath'] != null)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: Image.file(
                                              File(msg['imagePath']),
                                              height: 150,
                                              width: 200,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 4),
                                      Text(
                                        msg['time'],
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          color: Colors.white.withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (!isUser && msg['options'] != null) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: (msg['options'] as List<String>).map((opt) {
                                  return GestureDetector(
                                    onTap: () => _onOptionSelected(opt),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: teal.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: teal.withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        opt,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: teal,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
          if (isUser) const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildInputBar(Color teal) {
    return Positioned(
      bottom: 110, // Increased to sit above the main Dashboard navigation dock
      left: 20,
      right: 20,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 25, offset: const Offset(0, 12))
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.add_circle_outline_rounded, 
                    color: Colors.white.withValues(alpha: 0.6)),
                  onPressed: _pickImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: _isListening ? 'Listening...' : 'Ask anything about your shipment...',
                      hintStyle: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: Icon(_isListening ? Icons.mic_rounded : Icons.mic_none_rounded, 
                    color: _isListening ? teal : Colors.white.withValues(alpha: 0.6)),
                  onPressed: _toggleListening,
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: teal,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: teal.withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 2)
                      ],
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color teal;

  const _QuickActionCard({required this.icon, required this.label, required this.teal});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: teal, size: 20),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final Color teal;

  const _SuggestionChip({required this.label, required this.teal});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: teal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: teal.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(color: teal, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowCircle({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: size / 2,
            spreadRadius: size / 4,
          )
        ],
      ),
    );
  }
}
