import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';

class AuthServiceProvider {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<UserCredential> registerUser({
    required String email,
    required String password,
    required String name,
    required String department,
    required int age,
    required String resetKey,
    required bool agreedToTerms,
    String semester = '',
    String gender = 'Prefer not to say',
  }) async {
    // Blacklist Check
    final isBlacklisted = await FirebaseFirestore.instance.collection('blacklist').doc(email.trim().toLowerCase()).get().then((doc) => doc.exists);
    if (isBlacklisted) {
      throw Exception("PROTOCOL ERROR: This identity has been permanently expunged from the Void.");
    }

    if (!agreedToTerms) {
      throw Exception("PROTOCOL ERROR: Agreement required for manifestation.");
    }

    // Attempt creation
    final UserCredential cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (cred.user != null) {
      final bool isAdmin = false;
      final bool isSubMod = false;
      String finalName = name;

      // PROMOTING SEEDED IDENTITY: Check if an account was already seeded
      final existingSnap = await _db.collection('users').where('email', isEqualTo: email.toLowerCase()).limit(1).get();
      
      Map<String, dynamic> userData = {
        'uid': cred.user!.uid,
        'email': email,
        'name': finalName,
        'realName': name, // PRESERVE FULL NAME
        'department': department,
        'age': age,
        'semester': semester,
        'gender': gender,
        'resetKey': resetKey.toLowerCase(),
        'agreedToTerms': true,
        'termsTimestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'isFirstLogin': true,
        'joinedArchives': (isAdmin || isSubMod),
        'viewCount': 0,
        'isBanned': false,
        'isAdmin': isAdmin,
        'role': isSubMod ? 'sub-mod' : 'ghost',
        'swipeCount': 0,
        'soulCount': 0,
        'photoUrl': '',
        'bio': '',
        'hobbies': [],
      };

      if (existingSnap.docs.isNotEmpty) {
        final oldDoc = existingSnap.docs.first;
        final existingData = oldDoc.data();
        // Merge existing data (respecting the new Auth ID context)
        userData.addAll(existingData);
        userData['uid'] = cred.user!.uid;
        
        // Delete original seeded document
        if (oldDoc.id != cred.user!.uid) {
          try {
            await _db.collection('users').doc(oldDoc.id).delete();
            print("REGISTER_MIGRATION: Expunged seeded document ${oldDoc.id}");
          } catch (e) {
            // EXPECTED: Normal users don't have permission to delete other records.
            // Orphaned documents will be cleaned up by Oracles during mass resets.
            print("REGISTER_MIGRATION: Sparing seeded document ${oldDoc.id} due to permissions: $e");
          }
        }
      }

      await _db.collection('users').doc(cred.user!.uid).set(userData);
    }

    return cred;
  }
}
