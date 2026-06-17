import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './cloudinary_service.dart';

class CleanupService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static const String _lastRunKey = 'last_cleanup_timestamp';
  static const String _lastChatRunKey = 'last_chat_cleanup_date'; // Track by date (YYYY-MM-DD)

  /// Deletes all expired wisprs and their associated media files.
  /// Throttled to run at most once per 5 minutes to keep things lean.
  static Future<void> pruneExpiredContent() async {
    final prefs = await SharedPreferences.getInstance();
    final lastRun = prefs.getInt(_lastRunKey) ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // Run every 5 minutes (300000 ms)
    if (nowMs - lastRun < 300000) {
      print("Cleanup: Throttled (last run was < 5min ago)");
      return;
    }

    await prefs.setInt(_lastRunKey, nowMs);
    
    final firestoreNow = Timestamp.now();
    final expiredQuery = await _db
        .collection('wisprs')
        .where('expiresAt', isLessThan: firestoreNow)
        .get();

    if (expiredQuery.docs.isEmpty) {
      print("Cleanup: No expired wisprs found.");
      return;
    }

    final batch = _db.batch();
    for (var doc in expiredQuery.docs) {
      final data = doc.data();
      
      // Delete media from storage if exists
      if (data['mediaUrl'] != null) {
        try {
          final url = data['mediaUrl'] as String;
          if (url.contains('firebasestorage')) {
             final ref = _storage.refFromURL(url);
             await ref.delete();
             print("Cleanup: Deleted media from storage: $url");
          } else if (url.contains('cloudinary')) {
             await CloudinaryService.deleteMedia(url);
             print("Cleanup: Cloudinary asset purged: $url");
          }
        } catch (e) {
          print("Cleanup: Failed to delete media for ${doc.id}: $e");
        }
      }
      batch.delete(doc.reference);
    }

    await batch.commit();
    print("Cleanup: Pruned ${expiredQuery.docs.length} expired wisprs.");
    await pruneExpiredNotes(); // Integrated Semester Decay
    await _pruneExpiredChats();
  }

  /// SEMESTER DECAY: Prunes University Notes older than 6 months (180 days).
  static Future<void> pruneExpiredNotes() async {
    print("Cleanup: Initiating Semester Decay (Note Pruning)...");
    final sixMonthsAgo = DateTime.now().subtract(const Duration(days: 180));
    
    try {
      final oldNotes = await _db
          .collection('notes')
          .where('createdAt', isLessThan: Timestamp.fromDate(sixMonthsAgo))
          .get();

      if (oldNotes.docs.isEmpty) {
        print("Cleanup: No knowledge found to be decaying.");
        return;
      }

      final batch = _db.batch();
      int deletedCount = 0;

      for (var doc in oldNotes.docs) {
        final data = doc.data();
        
        // 1. Delete the PDF/Media from Cloudinary/Storage
        if (data['fileUrl'] != null) {
          try {
             final url = data['fileUrl'] as String;
             if (url.contains('cloudinary')) {
               await CloudinaryService.deleteMedia(url);
             } else if (url.contains('firebasestorage')) {
               await _storage.refFromURL(url).delete();
             }
          } catch (e) {
            print("Cleanup: Failed to purge file for note ${doc.id}: $e");
          }
        }

        // 2. Queue document for deletion
        batch.delete(doc.reference);
        deletedCount++;
      }

      await batch.commit();
      print("Cleanup: Semester Decay complete. $deletedCount knowledge nodes faded.");
    } catch (e) {
      print("Cleanup: Error during Semester Decay: $e");
    }
  }

  static Future<void> _pruneExpiredChats() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month}-${now.day}";
    final lastChatRun = prefs.getString(_lastChatRunKey) ?? "";

    // Ritual happens once per day (checking by date YYYY-MM-DD)
    if (lastChatRun == todayStr) {
      print("Cleanup: Chat ritual already performed for today ($todayStr).");
      return;
    }

    print("!!! MIDNIGHT CHAT RITUAL STARTING !!!");
    await prefs.setString(_lastChatRunKey, todayStr);

    try {
      // Prune only messages older than 24 hours
      final cutoff = DateTime.now().subtract(const Duration(hours: 24));
      final chatGroups = await _db.collection('chats').get();

      for (var chat in chatGroups.docs) {
        final oldMessages = await chat.reference
            .collection('messages')
            .where('timestamp', isLessThan: Timestamp.fromDate(cutoff))
            .get();

        if (oldMessages.docs.isNotEmpty) {
          final chunks = _chunkList(oldMessages.docs, 400);
          for (var chunk in chunks) {
            final batch = _db.batch();
            for (var msg in chunk) {
              batch.delete(msg.reference);
            }
            await batch.commit();
          }
          await chat.reference.update({
            'lastMessage': "Whispers faded into the void.",
            'lastMessageAt': FieldValue.serverTimestamp(),
          });
          print("Cleanup: Pruned ${oldMessages.docs.length} old messages for chat ${chat.id}");
        }
      }
    } catch (e) {
      print("Cleanup: ERROR DURING MIDNIGHT RITUAL: $e");
    }
  }

  /// Helper to split large lists for batching
  static List<List<T>> _chunkList<T>(List<T> list, int size) {
    if (list.isEmpty) return [];
    List<List<T>> chunks = [];
    for (var i = 0; i < list.length; i += size) {
      chunks.add(list.sublist(i, i + size > list.length ? list.length : i + size));
    }
    return chunks;
  }

  /// System-wide reset: Wipes all dynamic data and storage to reset the free tier limits.
  static Future<void> systemReset() async {
    print("!!! SYSTEM RESET STARTING !!!");
    
    // 1. Wipe Storage Folders (Iterative deletion as Client SDK lacks recursive delete)
    final folders = ['wispr_media', 'wispr_voice', 'profile_photos'];
    for (var folder in folders) {
      try {
        final ListResult result = await _storage.ref().child(folder).listAll();
        for (var item in result.items) {
          await item.delete();
        }
        print("Cleanup: Emptied storage folder '$folder'");
      } catch (e) {
        print("Cleanup: Error emptying folder '$folder': $e");
      }
    }

    // 2. Wipe Firestore (Reuse SeedService.nukeAllData)
    // Note: Calling SeedService here would create a circular dependency.
    // We'll perform Firestore nuke directly or ensure SeedService is called.
  }

  static Future<void> resetSeanceDaily() async {
    print("CleanupService: Initiating Séance Daily Reset Ritual...");
    
    // 1. Wipe Swipes Collection
    final swipes = await _db.collection('swipes').get();
    if (swipes.docs.isNotEmpty) {
      final batch = _db.batch();
      for (var doc in swipes.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      print("CleanupService: Banishment of ${swipes.docs.length} swipes complete.");
    }
    
    // 2. Reset Swipe Counts for all users
    final users = await _db.collection('users').where('swipeCount', isGreaterThan: 0).get();
    if (users.docs.isNotEmpty) {
      final batch = _db.batch();
      for (var doc in users.docs) {
        batch.update(doc.reference, {'swipeCount': 0});
      }
      await batch.commit();
      print("CleanupService: Reset swipe counts for ${users.docs.length} spirits.");
    }
    
    print("CleanupService: Séance Reset Ritual Concluded.");
  }
}
