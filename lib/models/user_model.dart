import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String bio;
  final List<String> hobbies;
  final String photoUrl;
  final int viewCount;
  final bool isBanned;
  final bool isAdmin;
  final int swipeCount;
  final int soulCount;
  final DateTime? lastResetAt;
  final bool isFirstLogin;
  final String? realName;
  final String? department;
  final int? age;
  final String? resetKey;
  final bool joinedArchives;
  final bool isEssenceSolidified;
  final int? resonance;
  final int? level;
  final String? spectralTitle;
  final int streak;
  final DateTime? lastActive;
  
  // New redesign fields
  final String? semester;
  final String? gender;
  final List<String> tags;
  final List<String> profilePhotos; // 4 additional posts
  final int weeklyMediaCount;
  final DateTime? lastWeeklyMediaReset;
  final List<String> friends;


  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.bio,
    required this.hobbies,
    required this.photoUrl,
    this.viewCount = 0,
    this.isBanned = false,
    this.isAdmin = false,
    this.swipeCount = 0,
    this.soulCount = 0,
    this.lastResetAt,
    this.isFirstLogin = true,
    this.realName,
    this.department,
    this.age,
    this.resetKey,
    this.joinedArchives = false,
    this.isEssenceSolidified = false,
    this.resonance = 0,
    this.level = 1,
    this.spectralTitle = "GHOST",
    this.streak = 0,
    this.lastActive,
    this.semester,
    this.gender,
    this.tags = const [],
    this.profilePhotos = const [],
    this.weeklyMediaCount = 0,
    this.lastWeeklyMediaReset,
    this.friends = const [],
  });

  factory UserModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {}; // Handle null data
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      name: (data['name'] != null && data['name'].toString().toLowerCase() != 'ghost') 
          ? data['name'] 
          : (data['email'] != null ? data['email'].split('@')[0] : 'Ghost'),
      bio: data['bio'] ?? '',
      hobbies: List<String>.from(data['hobbies'] ?? []),
      photoUrl: data['photoUrl'] ?? '',
      viewCount: data['viewCount'] ?? 0,
      isBanned: data['isBanned'] ?? false,
      isAdmin: data['isAdmin'] ?? false,
      swipeCount: data['swipeCount'] ?? 0,
      soulCount: data['soulCount'] ?? 0,
      lastResetAt: data['lastResetAt'] != null ? (data['lastResetAt'] as Timestamp).toDate() : null,
      isFirstLogin: data['isFirstLogin'] ?? true,
      realName: data['realName'],
      department: data['department'],
      age: data['age'],
      resetKey: data['resetKey'],
      joinedArchives: data['joinedArchives'] ?? false,
      isEssenceSolidified: data['isEssenceSolidified'] ?? false,
      resonance: data['resonance'] ?? 0,
      level: data['level'] ?? 1,
      spectralTitle: data['spectralTitle'] ?? "GHOST",
      streak: data['streak'] ?? 0,
      lastActive: data['lastActive'] != null ? (data['lastActive'] as Timestamp).toDate() : null,
      semester: data['semester'],
      gender: data['gender'],
      tags: List<String>.from(data['tags'] ?? []),
      profilePhotos: List<String>.from(data['profilePhotos'] ?? []),
      weeklyMediaCount: data['weeklyMediaCount'] ?? 0,
      lastWeeklyMediaReset: data['lastWeeklyMediaReset'] != null ? (data['lastWeeklyMediaReset'] as Timestamp).toDate() : null,
      friends: List<String>.from(data['friends'] ?? []),
    );
  }

  String get displayTitle {
    if (spectralTitle == null) return "GHOST";
    final t = spectralTitle!.toUpperCase();
    if (t.contains("BORN") || t.contains("ECHO") || t.contains("SOUL") || t.contains("SPIRIT")) {
       return "GHOST";
    }
    return t;
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'bio': bio,
      'hobbies': hobbies,
      'photoUrl': photoUrl,
      'viewCount': viewCount,
      'isBanned': isBanned,
      'isAdmin': isAdmin,
      'swipeCount': swipeCount,
      'soulCount': soulCount,
      'lastResetAt': lastResetAt != null ? Timestamp.fromDate(lastResetAt!) : null,
      'isFirstLogin': isFirstLogin,
      'realName': realName,
      'department': department,
      'age': age,
      'resetKey': resetKey,
      'joinedArchives': joinedArchives,
      'isEssenceSolidified': isEssenceSolidified,
      'resonance': resonance,
      'level': level,
      'spectralTitle': spectralTitle,
      'streak': streak,
      'lastActive': lastActive != null ? Timestamp.fromDate(lastActive!) : null,
      'semester': semester,
      'gender': gender,
      'tags': tags,
      'profilePhotos': profilePhotos,
      'weeklyMediaCount': weeklyMediaCount,
      'lastWeeklyMediaReset': lastWeeklyMediaReset != null ? Timestamp.fromDate(lastWeeklyMediaReset!) : null,
      'friends': friends,
    };
  }
}
