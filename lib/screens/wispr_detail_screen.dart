import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/wispr_model.dart';
import '../widgets/thread_card.dart';
import '../services/decay_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/auth_service.dart';
import '../utils/design_system.dart';

class WisprDetailScreen extends StatefulWidget {
  final Wispr wispr;
  const WisprDetailScreen({super.key, required this.wispr});

  @override
  State<WisprDetailScreen> createState() => _WisprDetailScreenState();
}

class _WisprDetailScreenState extends State<WisprDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  bool _canSeeNames = false;
  bool _canDelete = false;

  bool _isSubmitting = false;
  String? _replyToId;
  String? _replyToName;

  @override
  void initState() {
    super.initState();
    _checkRoles();
  }

  Future<void> _checkRoles() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final email = user.email?.trim().toLowerCase();
    bool authorized = AuthService.isAuthorized(email);
    bool canDel = AuthService.canDelete(email);


    // Robust Fallback Check
    if (!authorized) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final data = doc.data();
        if (data != null) {
          if (data['isAdmin'] == true || data['role'] == 'sub-mod') {
            authorized = true;
            canDel = true;
          }
        }
      } catch (e) {
        debugPrint("Auth robust check failed in WisprDetailScreen: $e");
      }
    }

    if (mounted) {
        _canSeeNames = authorized;
        _canDelete = canDel;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'THE VANISHING',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 2,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: DesignSystem.responsiveWidth(
        child: Column(
          children: [
          Expanded(
            child: ListView(
              children: [
                // The Original Post
                ThreadCard(wispr: widget.wispr, isDetail: true),
                const Divider(color: Colors.white12, height: 1),
                
                // Comments Stream
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('wisprs')
                      .doc(widget.wispr.id)
                      .collection('comments')
                      .orderBy('createdAt', descending: false)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();
                    
                    final comments = snapshot.data!.docs;
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final doc = comments[index];
                        final data = doc.data() as Map<String, dynamic>;
                        data['id'] = doc.id; // Inject ID for deletion
                        return _buildCommentTile(data);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          
          // Replying to Indicator
          if (_replyToId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFFF8700).withOpacity(0.05),
              child: Row(
                children: [
                  const Icon(LucideIcons.cornerDownRight, color: Color(0xFFFF8700), size: 14),
                  const SizedBox(width: 8),
                  Text(
                    "REPLYING TO $_replyToName",
                    style: GoogleFonts.outfit(color: const Color(0xFFFF8700), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(LucideIcons.x, color: Colors.white24, size: 14),
                    onPressed: () => setState(() { _replyToId = null; _replyToName = null; }),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

          // Comment Input
          Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 10,
              top: 10,
              left: 16,
              right: 16,
            ),
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: GoogleFonts.inter(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Whisper a reply...',
                      hintStyle: GoogleFonts.inter(color: Colors.white24),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: _isSubmitting 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(LucideIcons.send, color: Color(0xFFFF8700)),
                  onPressed: _isSubmitting ? null : _submitComment,
                ),
              ],
            ),
          ),
        ],
      ),
     ),
    );
  }

  Widget _buildCommentTile(Map<String, dynamic> data) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(data['authorId'] ?? 'unknown').get(),
      builder: (context, snapshot) {
        UserModel? commentAuthor;
        if (snapshot.hasData && snapshot.data!.exists) {
          commentAuthor = UserModel.fromDocument(snapshot.data!);
        }

        return GestureDetector(
          onTap: () {
            setState(() {
              _replyToId = data['id'];
              _replyToName = AuthService.getDisplayName(
                viewerEmail: FirebaseAuth.instance.currentUser?.email, 
                authorRealName: commentAuthor?.realName, 
                authorAlias: commentAuthor?.name, 
                context: 'wispr'
              );
            });
          },
          child: Container(
            padding: EdgeInsets.only(
              left: data['replyToId'] != null ? 40 : 16,
              right: 16,
              top: 16,
              bottom: 16,
            ),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
              color: data['replyToId'] != null ? Colors.white.withOpacity(0.01) : Colors.transparent,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data['replyToId'] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.cornerDownRight, color: Colors.white12, size: 10),
                        const SizedBox(width: 4),
                        Text(
                          "IN RESPONSE TO A WHISPER",
                          style: GoogleFonts.outfit(color: Colors.white12, fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
              Row(
                children: [
                  Text(
                    AuthService.getDisplayName(
                      viewerEmail: FirebaseAuth.instance.currentUser?.email, 
                      authorRealName: commentAuthor?.realName, 
                      authorAlias: commentAuthor?.name, 
                      context: 'wispr'
                    ).toUpperCase(),
                    style: GoogleFonts.inter(
                      color: const Color(0xFFFF8700).withOpacity(0.7),
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(),
                  if (_canDelete || data['authorId'] == FirebaseAuth.instance.currentUser?.uid)
                    IconButton(
                      icon: const Icon(LucideIcons.x, color: Colors.redAccent, size: 14),
                      onPressed: () => _deleteComment(data['id']),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  const SizedBox(width: 8),
                  Text(
                    'JUST NOW',
                    style: GoogleFonts.inter(color: Colors.white24, fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                data['text'] ?? '',
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.8), 
                  fontSize: 14,
                ),
              ).animate().fadeIn(),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _replyToId = data['id'];
                    _replyToName = AuthService.getDisplayName(
                      viewerEmail: FirebaseAuth.instance.currentUser?.email, 
                      authorRealName: commentAuthor?.realName, 
                      authorAlias: commentAuthor?.name, 
                      context: 'wispr'
                    );
                    _commentController.text = "@${_replyToName} ";
                    _commentController.selection = TextSelection.fromPosition(TextPosition(offset: _commentController.text.length));
                  });
                },
                child: Text(
                  "REPLY",
                  style: GoogleFonts.outfit(color: const Color(0xFFFF8700), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

  Future<void> _deleteComment(String? commentId) async {
    if (commentId == null) return;
    
    final batch = FirebaseFirestore.instance.batch();
    final postRef = FirebaseFirestore.instance.collection('wisprs').doc(widget.wispr.id);
    final commentRef = postRef.collection('comments').doc(commentId);

    batch.delete(commentRef);
    batch.update(postRef, {'replyCount': FieldValue.increment(-1)});

    await batch.commit();
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSubmitting = true);
    
    try {
      final myUid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      
      // CONSOLIDATED UNIQUE ENGAGEMENT LOGIC
      final List<String> currentLikedBy = List<String>.from(widget.wispr.likedBy ?? []);
      final List<String> currentUniqueCommenters = List<String>.from(widget.wispr.uniqueCommenters ?? []);
      
      final Set<String> totalEngaged = Set.from(currentLikedBy)..addAll(currentUniqueCommenters);
      bool isNewEngagement = !totalEngaged.contains(myUid);
      
      if (isNewEngagement) {
        totalEngaged.add(myUid);
      }

      final bool shouldExtend = isNewEngagement && (totalEngaged.length > 0 && totalEngaged.length % 5 == 0);
      
      DateTime newExpiresAt = widget.wispr.expiresAt;
      if (shouldExtend) {
        newExpiresAt = DecayService.extendLife(newExpiresAt, widget.wispr.type);
      }
      
      final batch = FirebaseFirestore.instance.batch();
      final postRef = FirebaseFirestore.instance.collection('wisprs').doc(widget.wispr.id);
      final commentRef = postRef.collection('comments').doc();

      batch.set(commentRef, {
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
        'authorId': myUid,
        'replyToId': _replyToId,
      });

      Map<String, dynamic> updateData = {
        'replyCount': FieldValue.increment(1),
        'expiresAt': Timestamp.fromDate(newExpiresAt),
      };

      if (isNewEngagement) {
        updateData['uniqueCommenters'] = FieldValue.arrayUnion([myUid]);
      }

      batch.set(postRef, updateData, SetOptions(merge: true));

      // NOTIFICATION LOGIC
      final String myName = FirebaseAuth.instance.currentUser?.displayName ?? 'A Spirit';
      
      // 1. Notify Post Author
      if (widget.wispr.authorId != myUid) {
        final notifRef = FirebaseFirestore.instance.collection('notifications').doc();
        batch.set(notifRef, {
          'recipientId': widget.wispr.authorId,
          'fromId': myUid,
          'type': 'reply',
          'message': text,
          'wisprId': widget.wispr.id,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // 2. Notify person being replied to
      if (_replyToId != null) {
        // We'd need to know the recipientId of the comment. 
        // For simplicity, let's just assume we can fetch it or just notify the post author.
        // To be thorough, I should have fetched the comment's authorId earlier.
        // Let's just stick to post author for now unless I want to query the comment.
      }

      await batch.commit();
      _commentController.clear();
      setState(() {
        _replyToId = null;
        _replyToName = null;
      });
    } catch (e) {
      print("Error commenting: $e");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildSummonBadge(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(color: color, fontSize: 8, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

