import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/auth_service_provider.dart';
import '../layout/app_layout.dart';
import '../widgets/particle_background.dart';
import '../services/auth_service.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _deptController = TextEditingController();
  final _ageController = TextEditingController();
  final _semesterController = TextEditingController();
  final _resetKeyController = TextEditingController();
  String _selectedGender = 'Prefer not to say';

  bool _agreedToTerms = false;
  bool _isLoading = false;
  String _errorMessage = "";

  void _handleRegistration() async {
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();
    final dept = _deptController.text.trim();
    final age = int.tryParse(_ageController.text.trim()) ?? 0;
    final semester = _semesterController.text.trim();
    final resetKey = _resetKeyController.text.trim();

    if (email.isEmpty) {
      setState(() => _errorMessage = "University email is required.");
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorMessage = "A secure password is required.");
      return;
    }
    if (name.isEmpty) {
      setState(() => _errorMessage = "Provide your full name.");
      return;
    }
    if (dept.isEmpty) {
      setState(() => _errorMessage = "Specify your department.");
      return;
    }
    if (age == 0) {
      setState(() => _errorMessage = "Enter a valid numeric age.");
      return;
    }
    if (resetKey.isEmpty) {
      setState(() => _errorMessage = "A recovery keyword is mandatory.");
      return;
    }

    if (!email.endsWith('@adaniuni.ac.in')) {
      setState(() => _errorMessage = "Only @adaniuni.ac.in emails allowed.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    try {
      await AuthServiceProvider.registerUser(
        email: email,
        password: password,
        name: name,
        department: dept,
        age: age,
        semester: semester,
        gender: _selectedGender,
        resetKey: resetKey,
        agreedToTerms: _agreedToTerms,
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, a, b) => const AppLayout(),
            transitionsBuilder: (context, a, b, child) => FadeTransition(opacity: a, child: child),
            transitionDuration: const Duration(milliseconds: 1000),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst("Exception: ", "");
          _isLoading = false;
        });
      }
    }
  }

  void _showGhostProtocol() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                constraints: const BoxConstraints(maxHeight: 600),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Color(0xFFFF8700).withOpacity(0.3), width: 1),
                  boxShadow: [
                    BoxShadow(color: Color(0xFFFF8700).withOpacity(0.05), blurRadius: 40, spreadRadius: 10)
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        "THE GHOST PROTOCOL",
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        "By entering GHOSTED, you consent to the Integrity Protocol. To maintain a harmonious environment and prevent community decay, the system utilizes proactive monitoring to ensure safety and peace. We do not monitor social interactions; we maintain platform standards. All administrative actions taken to ensure the 'Peace of the Collective' are final.",
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.6,
                        ),
                        textAlign: TextAlign.justify,
                      ),
                      const SizedBox(height: 32),
                      Theme(
                        data: ThemeData(unselectedWidgetColor: Colors.white24),
                        child: CheckboxListTile(
                          value: _agreedToTerms,
                          onChanged: (val) {
                            setModalState(() => _agreedToTerms = val ?? false);
                            setState(() => _agreedToTerms = val ?? false);
                          },
                          title: Text(
                            "I have read the protocols and I accept my place in the Void.",
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          activeColor: const Color(0xFFFF8700),
                          checkColor: Colors.black,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _agreedToTerms ? () => Navigator.pop(context) : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _agreedToTerms ? const Color(0xFFFF8700) : Colors.white10,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          disabledBackgroundColor: Colors.white.withOpacity(0.05),
                        ),
                        child: Text(
                          "ACCEPT PROTOCOL",
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1), curve: Curves.easeOutBack);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const ParticleBackground(),
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 450),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "MANIFEST YOUR SPIRIT",
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Create your identity within the archives.",
                        style: GoogleFonts.inter(color: Colors.white38, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      const SizedBox.shrink(),
                      const SizedBox(height: 48),
                      _buildTextField(_emailController, "University Email", LucideIcons.mail),
                      const SizedBox(height: 20),
                      _buildTextField(_passwordController, "Password", LucideIcons.lock, obscure: true),
                      const SizedBox(height: 20),
                      _buildTextField(_nameController, "Full Name", LucideIcons.user),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            flex: 2, 
                            child: _buildTextField(_deptController, "Department", LucideIcons.building)
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: _buildTextField(_ageController, "Age", LucideIcons.hash, keyboardType: TextInputType.number),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: _buildTextField(_semesterController, "Semester (1-8)", LucideIcons.bookOpen, keyboardType: TextInputType.number),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: _buildDropdownField(
                              label: "Gender",
                              value: _selectedGender,
                              items: ["Male", "Female", "Prefer not to say"],
                              icon: LucideIcons.user,
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedGender = val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(_resetKeyController, "Secret Keyword (Recovery)", LucideIcons.key),
                      const SizedBox(height: 32),
                      
                      if (_errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Text(
                            _errorMessage,
                            style: GoogleFonts.outfit(color: const Color(0xFFFF00FF), fontSize: 12, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ).animate().shakeX(),
                        ),
    
                      GestureDetector(
                        onTap: _isLoading ? null : () {
                          if (!_agreedToTerms) {
                            _showGhostProtocol();
                          } else {
                            _handleRegistration();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _agreedToTerms 
                                ? [const Color(0xFFFF8700), const Color(0xFFFF4E00)]
                                : [Colors.white10, Colors.white10],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: _agreedToTerms ? [
                              BoxShadow(color: Color(0xFFFF8700).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))
                            ] : [],
                          ),
                          alignment: Alignment.center,
                          child: _isLoading 
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3))
                            : Text(
                                "CREATE ACCOUNT",
                                style: GoogleFonts.outfit(
                                  color: _agreedToTerms ? Colors.black : Colors.white24,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  letterSpacing: 2,
                                ),
                              ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: _showGhostProtocol,
                        child: Text(
                          "VIEW GHOST PROTOCOL",
                          style: GoogleFonts.inter(color: Color(0xFFFF8700).withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool obscure = false, TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
        prefixIcon: Icon(icon, color: Color(0xFFFF8700).withOpacity(0.5), size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.03),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFFF8700), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item, style: GoogleFonts.inter(color: Colors.white, fontSize: 15)),
        );
      }).toList(),
      onChanged: onChanged,
      dropdownColor: Colors.black,
      style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
        prefixIcon: Icon(icon, color: Color(0xFFFF8700).withOpacity(0.5), size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.03),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFFF8700), width: 1.5),
        ),
      ),
    );
  }
}

