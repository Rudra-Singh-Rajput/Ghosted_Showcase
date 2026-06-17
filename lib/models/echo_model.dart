import 'package:cloud_firestore/cloud_firestore.dart';

class Echo {
  final String id;
  final String authorId;
  final String authorName;
  final String mediaUrl;
  final String type; // 'image' or 'video'
  final DateTime createdAt;
  final DateTime expiresAt;

  Echo({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.mediaUrl,
    required this.type,
    required this.createdAt,
    required this.expiresAt,
  });

  factory Echo.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Echo(
      id: doc.id,
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? 'Unknown Ghost',
      mediaUrl: data['mediaUrl'] ?? '',
      type: data['type'] ?? 'image',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'mediaUrl': mediaUrl,
      'type': type,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
    };
  }
}
