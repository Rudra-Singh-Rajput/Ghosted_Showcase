import 'package:cloud_firestore/cloud_firestore.dart';

enum WisprType { text, image, reel, voice, gif }

class Wispr {
  final String id;
  final String? title; // Added title field
  final String text;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int replyCount;
  final bool isPoll;
  final Map<String, int>? pollOptions;
  final int? voteGoal;
  final String? payoff;
  final String? mediaUrl;
  final String? mediaType; // mimetype
  final WisprType type;
  final String authorId;
  final List<String> likedBy;
  final bool allowMultipleVotes;
  final Map<String, List<String>> votedBy; // uid: [list of options]
  final String? element; // 'fire' or 'water'
  final List<String> uniqueCommenters;
  final bool isPinned;

  Wispr({
    required this.id,
    this.title,
    required this.text,
    required this.createdAt,
    required this.expiresAt,
    this.replyCount = 0,
    this.isPoll = false,
    this.pollOptions,
    this.voteGoal,
    this.payoff,
    this.mediaUrl,
    this.mediaType,
    this.type = WisprType.text,
    required this.authorId,
    this.likedBy = const [],
    this.allowMultipleVotes = false,
    this.votedBy = const {},
    this.element,
    this.uniqueCommenters = const [],
    this.isPinned = false,
  });

  factory Wispr.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Wispr(
      id: doc.id,
      title: data['title'],
      text: data['text'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(hours: 4)),
      replyCount: data['replyCount'] ?? 0,
      isPoll: data['isPoll'] ?? false,
      pollOptions: data['pollOptions'] != null 
          ? Map<String, int>.from(data['pollOptions']) 
          : null,
      voteGoal: data['voteGoal'],
      payoff: data['payoff'],
      mediaUrl: data['mediaUrl'],
      mediaType: data['mediaType'],
      type: WisprType.values.firstWhere(
        (e) => e.name == (data['type'] ?? 'text'), 
        orElse: () => WisprType.text
      ),
      authorId: data['authorId'] ?? 'anonymous',
      likedBy: List<String>.from(data['likedBy'] ?? []),
      allowMultipleVotes: data['allowMultipleVotes'] ?? false,
      votedBy: data['votedBy'] != null
          ? (data['votedBy'] as Map<String, dynamic>).map((k, v) => MapEntry(k, List<String>.from(v)))
          : {},
      element: data['element'],
      uniqueCommenters: List<String>.from(data['uniqueCommenters'] ?? []),
      isPinned: data['isPinned'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (title != null) 'title': title,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'replyCount': replyCount,
      'isPoll': isPoll,
      'type': type.name,
      'allowMultipleVotes': allowMultipleVotes,
      'votedBy': votedBy,
      if (pollOptions != null) 'pollOptions': pollOptions,
      if (voteGoal != null) 'voteGoal': voteGoal,
      if (payoff != null) 'payoff': payoff,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
      if (mediaType != null) 'mediaType': mediaType,
      'authorId': authorId,
      'likedBy': likedBy,
      'element': element,
      'uniqueCommenters': uniqueCommenters,
      'isPinned': isPinned,
    };
  }

  /// Calculates the current opacity based on the decay rule.
  /// Opacity = (RemainingSeconds / 3600).clamp(0, 1)
  double get currentOpacity {
    final now = DateTime.now();
    if (now.isAfter(expiresAt)) return 0.0;
    
    final totalLife = expiresAt.difference(createdAt).inSeconds;
    final remainingLife = expiresAt.difference(now).inSeconds;
    
    // Start linear fade when less than 75% of life remains
    if (remainingLife > (totalLife * 0.75)) return 1.0;
    
    return (remainingLife / (totalLife * 0.75)).clamp(0.0, 1.0);
  }

  double get currentBlur {
    final now = DateTime.now();
    if (now.isAfter(expiresAt)) return 10.0;
    
    final opacity = currentOpacity;
    // As opacity drops from 1 to 0, blur goes from 0 to 5
    return (1.0 - opacity) * 5.0;
  }

  /// Calculates the glow intensity based on reply count.
  double get glowIntensity {
    return (replyCount / 50).clamp(0.0, 1.0);
  }
}
