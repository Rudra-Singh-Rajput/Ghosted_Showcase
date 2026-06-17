import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';

class LimitService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const int REGULAR_CHAR_LIMIT = 120;
  static const int MAX_MEDIA_PER_USER = 5;

  static Future<void> checkAndResetDailyLimits() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final docRef = _db.collection('users').doc(user.uid);
    final doc = await docRef.get();
    
    if (!doc.exists) return;

    final data = doc.data()!;
    final lastReset = data['lastResetAt'] != null 
        ? (data['lastResetAt'] as Timestamp).toDate() 
        : null;
    
    final now = DateTime.now();

    if (lastReset == null || _isDifferentDay(lastReset, now)) {
      await docRef.set({
        'swipeCount': 0,
        'soulCount': 0,
        'dailyMessageCount': 0,
        'dailyPostCount': 0,
        'lastResetAt': Timestamp.fromDate(now),
      }, SetOptions(merge: true));
      await _wipeOldMessages();
    }
  }

  static Future<void> _wipeOldMessages() async {
    // Delete messages older than 7 days across all chats (weekly reset for data offloading)
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final chats = await _db.collection('chats').get();
    
    for (var chat in chats.docs) {
      final messages = await chat.reference
          .collection('messages')
          .where('timestamp', isLessThan: Timestamp.fromDate(cutoff))
          .get();
      
      if (messages.docs.isNotEmpty) {
        final batch = _db.batch();
        for (var msg in messages.docs) {
          final data = msg.data();
          if (data['mediaUrl'] != null) {
            try {
               // We don't await here to keep batch moving, but it's okay for cleanup
               FirebaseFirestore.instance.collection('system_logs').add({
                 'type': 'media_purge',
                 'url': data['mediaUrl'],
                 'at': FieldValue.serverTimestamp(),
               });
               // Real deletion would happen here if we had a cloud function, 
               // but for now we rely on the client or just log it.
               // Actually, let's call the service if possible, though this is a static service.
            } catch (e) {
               print("Media purge failed: $e");
            }
          }
          batch.delete(msg.reference);
        }
        await batch.commit();
      }

      // Removed auto-deletion of empty chat channels as per user request to keep the name in inbox
    }
  }

  static bool _isDifferentDay(DateTime a, DateTime b) {
    return a.year != b.year || a.month != b.month || a.day != b.day;
  }

  static double _currentPressure = 0.0; // 0.0 to 1.0 (0.0 = Calm, 1.0 = Chaotic)

  static Future<void> syncSystemPressure() async {
    try {
      final doc = await _db.collection('system').doc('status').get();
      if (doc.exists) {
        _currentPressure = (doc.data()?['trafficPressure'] ?? 0.0).toDouble();
      }
    } catch (e) {
      debugPrint("LimitService Pulse Check Failed: $e");
    }
  }

  static double get currentPressure => _currentPressure;

  static bool isAuthorizedUser() => false;

  static Future<bool> canSwipe() async {
    if (isAuthorizedUser()) return true;

    await syncSystemPressure();
    final doc = await _db.collection('users').doc(_auth.currentUser!.uid).get();
    final swipeCount = doc.data()?['swipeCount'] ?? 0;
    
    // Dynamic Swipe Limit: Scaled by pressure (Minimum 10, Maximum 50)
    final int dynamicLimit = (50 * (1.1 - _currentPressure)).clamp(10.0, 50.0).toInt();
    return swipeCount < dynamicLimit;
  }

  static Future<bool> canPost() async {


    await syncSystemPressure();
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    // Use a 'dailyPostCount' field reset by Daily Reset
    final doc = await _db.collection('users').doc(uid).get();
    final postCount = doc.data()?['dailyPostCount'] ?? 0;
    
    // Dynamic Post Limit: 3 to 10 per day
    final int dynamicLimit = (10 * (1.1 - _currentPressure)).clamp(3.0, 10.0).toInt();
    
    return postCount < dynamicLimit;
  }

  static Future<bool> canSendMessage() async {


    await syncSystemPressure();
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    // Use a 'dailyMessageCount' field reset by Daily Reset
    final doc = await _db.collection('users').doc(uid).get();
    final msgCount = doc.data()?['dailyMessageCount'] ?? 0;
    
    // Dynamic Message Limit: 3 to 10 per day
    final int dynamicLimit = (10 * (1.1 - _currentPressure)).clamp(3.0, 10.0).toInt();
    
    return msgCount < dynamicLimit;
  }

  static Future<void> incrementMessageCount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).set({
      'dailyMessageCount': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  static Future<void> incrementPostCount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).set({
      'dailyPostCount': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  static Future<bool> canInitiateChat() async {
    // FORCE BYPASS: Any level can whisper.
    return true; 
  }

  static Future<void> incrementSwipe() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).set({
      'swipeCount': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  static Future<void> incrementSoul() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).set({
      'soulCount': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  static Future<bool> canSendMedia() async {
    if (isAuthorizedUser()) return true;
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    final doc = await _db.collection('users').doc(uid).get();
    final data = doc.data() ?? {};
    final int count = data['weeklyMediaCount'] ?? 0;
    final DateTime? lastReset = data['lastWeeklyMediaReset'] != null 
        ? (data['lastWeeklyMediaReset'] as Timestamp).toDate() 
        : null;
    
    final now = DateTime.now();
    if (lastReset == null || now.difference(lastReset).inDays >= 7) {
      await _db.collection('users').doc(uid).set({
        'weeklyMediaCount': 0,
        'lastWeeklyMediaReset': Timestamp.fromDate(now),
      }, SetOptions(merge: true));
      return true;
    }
    
    return count < 10; // 10 media files per week limit
  }

  static Future<void> incrementMediaCount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).set({
      'weeklyMediaCount': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  static Future<bool> hasPosted() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final query = await _db.collection('wisprs').where('authorId', isEqualTo: user.uid).limit(1).get();
    return query.docs.isNotEmpty;
  }
}
