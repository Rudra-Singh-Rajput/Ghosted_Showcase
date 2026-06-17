import 'package:cloud_firestore/cloud_firestore.dart';

class SeanceChat {
  final String id;
  final List<String> users;
  final List<Message> messages;
  final Map<String, bool> isRevealed;

  SeanceChat({
    required this.id,
    required this.users,
    this.messages = const [],
    this.isRevealed = const {},
  });

  factory SeanceChat.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final messagesList = data['messages'] as List<dynamic>? ?? [];
    return SeanceChat(
      id: doc.id,
      users: List<String>.from(data['users'] ?? []),
      messages: messagesList.map((m) => Message.fromMap(m)).toList(),
      isRevealed: Map<String, bool>.from(data['isRevealed'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'users': users,
      'messages': messages.map((m) => m.toMap()).toList(),
      'isRevealed': isRevealed,
    };
  }
}

class Message {
  final String senderId;
  final String text;
  final DateTime timestamp;

  Message({
    required this.senderId,
    required this.text,
    required this.timestamp,
  });

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
