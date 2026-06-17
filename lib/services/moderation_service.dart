import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/cloudinary_service.dart';

class ModerationService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<void> blacklistEmail(String email) async {
    await _db.collection('blacklist').doc(email.trim().toLowerCase()).set({
      'email': email.trim().toLowerCase(),
      'blacklistedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<bool> isEmailBlacklisted(String email) async {
    final doc = await _db.collection('blacklist').doc(email.trim().toLowerCase()).get();
    return doc.exists;
  }

  static Future<void> removeUserCompletely(String uid, String email) async {
    // 1. Blacklist email first to prevent re-registration during deletion
    await blacklistEmail(email);

    // 2. Fetch user data for cleanup
    final userDoc = await _db.collection('users').doc(uid).get();
    final userData = userDoc.data();

    // 3. Delete user document
    await _db.collection('users').doc(uid).delete();

    // 4. Purge profile photo
    if (userData != null && userData['photoUrl'] != null && (userData['photoUrl'] as String).isNotEmpty) {
      await CloudinaryService.deleteMedia(userData['photoUrl']);
    }

    // 5. Banish user's Wisprs and their media
    final wisprs = await _db.collection('wisprs').where('authorId', isEqualTo: uid).get();
    for (var doc in wisprs.docs) {
      final data = doc.data();
      if (data['mediaUrl'] != null && (data['mediaUrl'] as String).isNotEmpty) {
        await CloudinaryService.deleteMedia(data['mediaUrl']);
      }
      await doc.reference.delete();
    }

    // 6. Delete swipes
    final swipes = await _db.collection('swipes').where('ownerId', isEqualTo: uid).get();
    for (var doc in swipes.docs) {
      await doc.reference.delete();
    }
  }
}
