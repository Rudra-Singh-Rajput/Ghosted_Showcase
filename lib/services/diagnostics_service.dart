import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'cloudinary_service.dart';

class DiagnosticResult {
  final String name;
  final bool success;
  final String message;

  DiagnosticResult(this.name, this.success, this.message);
}

class DiagnosticsService {
  static Future<List<DiagnosticResult>> runAllTests() async {
    List<DiagnosticResult> results = [];

    // 1. Firebase Auth Check
    final user = FirebaseAuth.instance.currentUser;
    results.add(DiagnosticResult(
      "Auth Identity", 
      user != null, 
      user != null ? "Logged in as ${user.email}" : "No user detected"
    ));

    // 2. Cloudinary Connectivity
    try {
      final usage = await CloudinaryService.getUsageData();
      results.add(DiagnosticResult(
        "Cloudinary Engine", 
        true, 
        "Connected: ${usage['storage_used'] ?? 'OK'}"
      ));
    } catch (e) {
      results.add(DiagnosticResult("Cloudinary Engine", false, "Connection Failed: $e"));
    }

    // 3. Firestore Latency & Write
    try {
      final start = DateTime.now();
      await FirebaseFirestore.instance.collection('system_check').doc('heartbeat').set({
        'lastCheck': FieldValue.serverTimestamp(),
        'by': user?.email ?? 'anonymous',
      });
      final duration = DateTime.now().difference(start).inMilliseconds;
      results.add(DiagnosticResult("Firestore Pulse", true, "Latency: ${duration}ms"));
    } catch (e) {
      results.add(DiagnosticResult("Firestore Pulse", false, "Write Failed: $e"));
    }

    // 4. Persistence Tier Check
    try {
       final doc = await FirebaseFirestore.instance.collection('users').doc(user?.uid ?? 'none').get();
       results.add(DiagnosticResult(
         "Clearance Tier", 
         doc.exists, 
         doc.exists ? "User Record Found" : "No User Record (Seed Required)"
       ));
    } catch (e) {
       results.add(DiagnosticResult("Clearance Tier", false, "Read Failed: $e"));
    }

    return results;
  }
}
