import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import './cloudinary_service.dart';

class UserDeletionService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Completely wipes all user data and deletes the Auth account.
  static Future<void> nukeUser() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final String uid = user.uid;

    print("!!! INITIATING TOTAL DATA PURGE FOR USER: $uid !!!");

    try {
      // 1. Delete user's Wisprs (Threads/Posts)
      final wisprs = await _db.collection('wisprs').where('authorId', isEqualTo: uid).get();
      for (var doc in wisprs.docs) {
        final data = doc.data();
        if (data['mediaUrl'] != null) {
          await _deleteMedia(data['mediaUrl']);
        }
        await doc.reference.delete();
      }
      print("Purged ${wisprs.docs.length} wisprs.");

      // 2. Delete user's messages and cleanup chats
      final chatGroups = await _db.collection('chats').where('participants', arrayContains: uid).get();
      for (var chat in chatGroups.docs) {
        final messages = await chat.reference.collection('messages').where('senderId', isEqualTo: uid).get();
        for (var msg in messages.docs) {
          await msg.reference.delete();
        }
        
        // If it's a private chat, we just delete the whole thing for privacy
        // Or remove the participant if it's a group (this app uses private mostly)
        await chat.reference.delete();
      }
      print("Purged ${chatGroups.docs.length} chats and related messages.");

      // 3. Delete user's profile from 'users' collection
      final userDoc = await _db.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null && userData['photoUrl'] != null) {
          await _deleteMedia(userData['photoUrl']);
        }
        await userDoc.reference.delete();
      }
      print("Purged user document.");

      // 4. Delete Auth Account
      // Note: This requires a recent login. If it fails, the UI will handle re-auth.
      await user.delete();
      print("Auth account deleted successfully.");

    } catch (e) {
      print("ERROR DURING TOTAL DATA PURGE: $e");
      rethrow;
    }
  }

  static Future<void> _deleteMedia(String url) async {
    try {
      if (url.contains('firebasestorage')) {
        final ref = _storage.refFromURL(url);
        await ref.delete();
      } else if (url.contains('cloudinary')) {
        await CloudinaryService.deleteMedia(url);
      }
    } catch (e) {
      print("Failed to delete media during purge: $e");
    }
  }
}
