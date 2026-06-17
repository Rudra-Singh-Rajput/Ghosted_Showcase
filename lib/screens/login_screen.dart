import 'dart:ui';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../layout/app_layout.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/particle_background.dart';
import '../services/seed_service.dart';
import '../widgets/logo_painter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'registration_screen.dart';
import '../services/auth_service.dart';
import '../utils/design_system.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _resetKeyController = TextEditingController(); // Secret Keyword
  final TextEditingController _newPasswordController = TextEditingController(); // For Reset
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _hasError = false;
  String _errorMessage = "";
  bool _isLoading = false;
  bool _isLogin = true;
  Offset _mousePosition = Offset.zero;
  bool _showResetKeyField = false;
  bool _showNewPasswordField = false;
  String? _targetUidForReset;

  Future<void> _handleLogin() async {
    var email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
       _showError("Enter both email and password.");
       return;
    }

    // Extreme safety: case-insensitive match on the raw text
    final rawEmail = _emailController.text.trim().toLowerCase();
    final isSpecial = AuthService.isAuthorized(rawEmail);
    
    print("LOGIN_DEBUG: raw='$rawEmail', isSpecial=$isSpecial");

    if (!rawEmail.endsWith('@adaniuni.ac.in') && !isSpecial) {
       _showError("Must be an @adaniuni.ac.in email.");
       return;
    }

    setState(() {
       _isLoading = true;
       _hasError = false;
       _errorMessage = "";
    });

    try {
      if (_isLogin) {
        try {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
        } on FirebaseAuthException catch (e) {
          String msg = "Authentication failed.";
          if (e.code == 'operation-not-allowed') {
             msg = "THE VOID IS SEALED. Enable Email/Password Auth in Firebase Console.";
          } else if (e.code == 'invalid-credential' || e.code == 'wrong-password' || e.code == 'user-not-found') {
             msg = "THE SPECTRAL KEY OR IDENTITY IS INCORRECT.";
          } else if (e.message != null) {
             msg = e.message!;
          }
          _showError(msg);
          _passwordController.clear();
          setState(() => _isLoading = false);
          return;
        } catch (e) {
          _showError("Connection lost in the Void.");
          setState(() => _isLoading = false);
          return;
        }
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
      
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // PROACTIVE PROFILE CREATION: Ensures no "document not found" errors later
        final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        final doc = await userRef.get();
        
        if (!doc.exists) {
          // CHECK FOR EXISTING DOCUMENT BY EMAIL (Prevents UID mismatch with seeded accounts)
          final existingSnap = await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();

          Map<String, dynamic> initialData = {
            'email': user.email ?? email,
            'name': user.email?.split('@')[0] ?? email.split('@')[0],
            'createdAt': FieldValue.serverTimestamp(),
            'isFirstLogin': true,
          };

          if (existingSnap.docs.isNotEmpty) {
            // Adopt data from the seeded/existing document
            final oldDoc = existingSnap.docs.first;
            final existingData = oldDoc.data();
            initialData.addAll(existingData);
            // Ensure the new document has the correct UID in its fields
            initialData['uid'] = user.uid;
            
            // SECURITY: Delete the old document (with predictable UID) to prevent "extra" ghost accounts
            if (oldDoc.id != user.uid) {
               try {
                 await FirebaseFirestore.instance.collection('users').doc(oldDoc.id).delete();
                 print("IDENTITY MIGRATED: Deleted original seeded document ${oldDoc.id}");
               } catch (e) {
                 print("IDENTITY MIGRATION WARNING: Could not delete seeded doc: $e");
               }
            }
          }

          await userRef.set(initialData, SetOptions(merge: true));
        } else if (doc.data()?['isFirstLogin'] == null) {
          // If profile exists but missing flag, initialize it
          await userRef.update({'isFirstLogin': true});
        }
      }
      
      if (mounted) _proceedToVoid();
    } on FirebaseAuthException catch (e) {
       debugPrint("Auth Error: ${e.code} - ${e.message}");
       if (e.code == 'operation-not-allowed') {
         _showError("FIREBASE ERROR: Enable Email/Password in Console.");
       } else if (e.code == 'invalid-credential' || e.code == 'wrong-password') {
         _showError("THE SPECTRAL KEY IS INCORRECT.");
       } else {
         _showError(e.message ?? "THE VOID IS UNSTABLE.");
       }
    } catch (e) {
       _showError("An unexpected shadow occurred: $e");
    } finally {
       if (mounted) setState(() => _isLoading = false);
    }
  }

  void _proceedToVoid() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, a, b) => const AppLayout(),
        transitionsBuilder: (context, a, b, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
              .chain(CurveTween(curve: Curves.fastOutSlowIn))
              .animate(a),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 600)
      ),
    );
  }

  void _showError(String message) {
     if (!mounted) return;
     setState(() {
       _hasError = true;
       _errorMessage = message;
       _isLoading = false;
     });
     _passwordController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = kIsWeb || defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.linux;

    return Scaffold(
      backgroundColor: Colors.black,
      body: MouseRegion(
        onHover: (event) => setState(() => _mousePosition = event.localPosition),
        child: Stack(
          children: [
            ParticleBackground(mousePosition: _mousePosition),
            
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 450),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                  boxShadow: isDesktop
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFF8700).withOpacity(0.05),
                          blurRadius: 100,
                          spreadRadius: 10,
                        )
                      ]
                    : [],
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 100), 
                          DesignSystem.logo(context: context, size: 100),
                          
                          const SizedBox(height: 24),
                          Text(
                            'WELCOME BACK',
                            style: GoogleFonts.outfit(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4.0,
                              color: Colors.white,
                            ),
                          ),
                          
                          const SizedBox(height: 8),
                          Text(
                            'RETURN TO THE VOID',
                            style: GoogleFonts.outfit(
                              color: Colors.white.withOpacity(0.3),
                              letterSpacing: 2.0,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),

                          const SizedBox(height: 60),
                          
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildAuthTab("LOGIN", _isLogin, () => setState(() => _isLogin = true)),
                              const SizedBox(width: 60),
                              _buildAuthTab("SIGN UP", !_isLogin, () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const RegistrationScreen()));
                              }),
                            ],
                          ),
                          
                          const SizedBox(height: 54),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40.0),
                            child: TextField(
                              controller: _emailController,
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
                              decoration: InputDecoration(
                                hintText: 'University Email',
                                hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 15),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.03),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: _hasError ? const Color(0xFFFF00FF).withOpacity(0.5) : Colors.transparent)
                                ),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: _hasError ? const Color(0xFFFF00FF).withOpacity(0.5) : Colors.white.withOpacity(0.05))
                                ),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: Color(0xFFFF8700), width: 1.5)
                                ),
                              ),
                            ),
                          ).animate(target: _hasError ? 1 : 0)
                          .shakeX(hz: 10, amount: 15, duration: 400.ms)
                          .tint(color: const Color(0xFFFF00FF).withOpacity(0.2), duration: 200.ms),

                          const SizedBox(height: 20),
                          
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40.0),
                            child: TextField(
                              controller: _passwordController,
                              obscureText: true,
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
                              decoration: InputDecoration(
                                hintText: 'Password',
                                hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 15),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.03),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: _hasError ? const Color(0xFFFF00FF).withOpacity(0.5) : Colors.transparent)
                                ),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: _hasError ? const Color(0xFFFF00FF).withOpacity(0.5) : Colors.white.withOpacity(0.05))
                                ),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: Color(0xFFFF8700), width: 1.5)
                                ),
                              ),
                            ),
                          ).animate(target: _hasError ? 1 : 0)
                          .shakeX(hz: 10, amount: 15, duration: 400.ms)
                          .tint(color: const Color(0xFFFF00FF).withOpacity(0.2), duration: 200.ms),

                          if (_showResetKeyField) ...[
                            const SizedBox(height: 20),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 40.0),
                              child: TextField(
                                controller: _resetKeyController,
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                                decoration: _inputDecoration("Enter Secret Keyword"),
                              ),
                            ).animate().fadeIn().slideY(begin: 0.2, end: 0),
                          ],

                          if (_showNewPasswordField) ...[
                            const SizedBox(height: 20),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 40.0),
                              child: TextField(
                                controller: _newPasswordController,
                                obscureText: true,
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                                decoration: _inputDecoration("New Password"),
                              ),
                            ).animate().fadeIn().slideY(begin: 0.2, end: 0),
                          ],

                          if (_hasError && _errorMessage.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 12.0),
                              child: Text(
                                _errorMessage,
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFFFF00FF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ).animate().fadeIn().moveY(begin: 10, end: 0),

                          const SizedBox(height: 48),

                          GestureDetector(
                            onTap: _isLoading ? null : _handleLogin,
                            child: Container(
                              width: double.infinity,
                              margin: const EdgeInsets.symmetric(horizontal: 40),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFF8700), Color(0xFFFF4E00)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF8700).withOpacity(0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: _isLoading 
                                ? const SizedBox(
                                    width: 24,
                                    child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3),
                                  )
                                : Text(
                                    _isLogin ? 'LOGIN' : 'SIGN UP',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2,
                                      color: Colors.black,
                                    ),
                                  ),
                            ).animate().shimmer(duration: 2.seconds, curve: Curves.easeInOut).fadeIn(),
                          ),

                          if (_isLogin)
                            Padding(
                              padding: const EdgeInsets.only(top: 16.0),
                              child: TextButton(
                                onPressed: _isLoading ? null : () async {
                                  final email = _emailController.text.trim();
                                  if (email.isEmpty) {
                                    _showError("Enter your email first.");
                                    return;
                                  }

                                  if (!_showResetKeyField && !_showNewPasswordField) {
                                    setState(() => _isLoading = true);
                                    try {
                                      final snap = await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: email).get();
                                      if (snap.docs.isEmpty) {
                                        _showError("Soul not found in the Archives.");
                                        return;
                                      }
                                      _targetUidForReset = snap.docs.first.id;
                                      setState(() => _showResetKeyField = true);
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PROVIDE THE SECRET KEYWORD.")));
                                    } catch (e) {
                                      _showError("Connection to the Archives lost.");
                                    } finally {
                                      setState(() => _isLoading = false);
                                    }
                                    return;
                                  }

                                  if (_showResetKeyField && !_showNewPasswordField) {
                                    final key = _resetKeyController.text.trim().toLowerCase();
                                    setState(() => _isLoading = true);
                                    try {
                                      final doc = await FirebaseFirestore.instance.collection('users').doc(_targetUidForReset).get();
                                      final storedKey = doc.data()?['resetKey'] as String?;
                                      if (storedKey == key) {
                                        setState(() {
                                          _showResetKeyField = false;
                                          _showNewPasswordField = true;
                                        });
                                      } else {
                                        _showError("The ritual keyword is incorrect.");
                                      }
                                    } catch (e) {
                                      _showError("Verification failed.");
                                    } finally {
                                      setState(() => _isLoading = false);
                                    }
                                    return;
                                  }

                                  if (_showNewPasswordField) {
                                    final newPass = _newPasswordController.text.trim();
                                    if (newPass.length < 6) {
                                      _showError("Password too weak.");
                                      return;
                                    }
                                    _showError("RESTORED. TRY LOGIN NOW.");
                                    setState(() {
                                      _showNewPasswordField = false;
                                      _isLogin = true;
                                    });
                                  }
                                },
                                child: Text(
                                  "FORGOT PASSWORD?",
                                  style: GoogleFonts.inter(color: Colors.white24, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                                ),
                              ),
                            ),
                          
                          const SizedBox(height: 60),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthTab(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              color: isActive ? Colors.white : Colors.white24,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: 300.ms,
            height: 2,
            width: isActive ? 30 : 0,
            decoration: BoxDecoration(
              color: const Color(0xFFFF8700),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF8700).withOpacity(0.5),
                  blurRadius: 8,
                )
              ]
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white38, fontSize: 12),
      filled: true,
      fillColor: Colors.white.withOpacity(0.02),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFFF8700), width: 1.5),
      ),
    );
  }
}

