import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ResonanceService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const int XP_PER_LIKE = 10;
  static const int XP_PER_COMMENT = 25;
  static const int XP_PER_WHISPER = 50;
  static const int XP_PER_POST = XP_PER_WHISPER;
  static const int XP_PER_MATCH = 100;
  static const int XP_PER_UPLOAD = 75;

  /// Gain Resonance points and update user level
  static Future<void> gainResonance(int amount) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final ref = _db.collection('users').doc(user.uid);
    
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      int resonance = (data['resonance'] ?? 0) + amount;
      int level = (resonance / 100).floor() + 1;
      
      transaction.update(ref, {
        'resonance': resonance,
        'level': level,
        'spectralTitle': _getTitleForLevel(level),
      });
    });
  }

  static String _getTitleForLevel(int level) {
    if (level >= 100) return "VOID SOVEREIGN";
    if (level >= 80) return "ETHEREAL SEER";
    if (level >= 60) return "SPIRIT LORD";
    if (level >= 50) return "VENERABLE SPECTER";
    if (level >= 40) return "NIGHTSTALKER";
    if (level >= 30) return "POLTERGEIST";
    if (level >= 20) return "APPARITION";
    if (level >= 10) return "WRAITH";
    if (level >= 5) return "SHADOW";
    return "PHANTOM";
  }

  static String getFlairForLevel(int level) {
    if (level >= 50) return "💠";
    if (level >= 40) return "🧿";
    if (level >= 30) return "🔮";
    if (level >= 20) return "💫";
    if (level >= 10) return "👁️";
    if (level >= 5) return "👻";
    return "🌑";
  }

  /// Update the user's daily streak and activity timestamp
  static Future<void> updateStreak() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final ref = _db.collection('users').doc(user.uid);
    final now = DateTime.now();

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final lastActiveTs = data['lastActive'] as Timestamp?;
      final lastActive = lastActiveTs?.toDate();
      int currentStreak = data['streak'] ?? 0;

      if (lastActive == null) {
        // First time activity
        transaction.update(ref, {
          'streak': 1,
          'lastActive': Timestamp.fromDate(now),
        });
        return;
      }

      final diff = now.difference(lastActive);
      
      // If last active was between 20 and 48 hours ago, increment streak
      // We use 20 hours to give some leeway for "daily" logins
      if (diff.inHours >= 20 && diff.inHours <= 48) {
        transaction.update(ref, {
          'streak': currentStreak + 1,
          'lastActive': Timestamp.fromDate(now),
        });
        // Bonus XP for maintaining streak
        gainResonance(50); 
      } else if (diff.inHours > 48) {
        // Streak broken
        transaction.update(ref, {
          'streak': 1,
          'lastActive': Timestamp.fromDate(now),
        });
      } else {
        // Logged in recently, just update timestamp if more than an hour
        if (diff.inMinutes > 60) {
          transaction.update(ref, {
            'lastActive': Timestamp.fromDate(now),
          });
        }
      }
    });
  }
}
