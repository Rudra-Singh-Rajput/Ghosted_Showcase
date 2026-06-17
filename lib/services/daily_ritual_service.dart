import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DailyRitualService {
  static const String COLLECTION = 'daily_rituals';

  static Future<void> trackAction(String actionType) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final today = DateTime.now().toIso8601String().split('T')[0];
    final ritualRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection(COLLECTION)
        .doc(today);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(ritualRef);
      if (!snapshot.exists) {
        transaction.set(ritualRef, {
          'date': today,
          'actions': {actionType: 1},
          'completed': false,
        });
      } else {
        final data = snapshot.data()!;
        final actions = Map<String, int>.from(data['actions'] ?? {});
        actions[actionType] = (actions[actionType] ?? 0) + 1;
        
        bool allDone = _checkCompletion(actions);
        transaction.update(ritualRef, {
          'actions': actions,
          'completed': allDone,
        });
      }
    });
  }

  static bool _checkCompletion(Map<String, int> actions) {
    // Basic daily goal: 1 post or 3 likes
    final posts = actions['post'] ?? 0;
    final likes = actions['like'] ?? 0;
    return posts >= 1 || likes >= 3;
  }

  static Stream<DocumentSnapshot> getTodayRitual() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();
    final today = DateTime.now().toIso8601String().split('T')[0];
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection(COLLECTION)
        .doc(today)
        .snapshots();
  }
}
