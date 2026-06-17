import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/user_model.dart';
import '../utils/design_system.dart';
import '../widgets/ghost_theme.dart';
import '../widgets/void_empty_state.dart';
import '../layout/app_layout.dart';

class HauwaConfessionScreen extends StatefulWidget {
  const HauwaConfessionScreen({super.key});

  @override
  State<HauwaConfessionScreen> createState() => _HauwaConfessionScreenState();
}

class _HauwaConfessionScreenState extends State<HauwaConfessionScreen> {
  final TextEditingController _confessionController = TextEditingController();
  bool _hasProfilePhoto = false;
  UserModel? _currentUser;
  bool _isEasterEggFound = false;

  @override
  void initState() {
    super.initState();
    _checkProfilePhoto();
  }

  Future<void> _checkProfilePhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (doc.exists) {
      final model = UserModel.fromDocument(doc);
      setState(() {
        _currentUser = model;
        // Require user to be logged in (removed strict photo+archive gate)
        _hasProfilePhoto = true;
      });
    }
  }

  Future<void> _postConfession() async {
    final text = _confessionController.text.trim();
    if (text.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _confessionController.clear();

    try {
      final confessionsRef = FirebaseFirestore.instance.collection('confessions');
      final authorsRef = FirebaseFirestore.instance.collection('confession_authors');
      
      // Get user's active confessions from the private confession_authors mapping
      final myConfessions = await authorsRef
          .where('authorId', isEqualTo: user.uid)
          .get();

      // Sort in memory to avoid needing a composite index
      final docsList = myConfessions.docs.toList();
      docsList.sort((a, b) {
        final aTime = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
        final bTime = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return aTime.compareTo(bTime);
      });

      // Deletion logic: if user has 5 or more active confessions, delete the oldest one
      if (docsList.length >= 5) {
        final oldestId = docsList.first.id;
        await confessionsRef.doc(oldestId).delete();
        await authorsRef.doc(oldestId).delete();
      }

      // Check settings for time-based configuration (default to permanent)
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final bool timeBased = userDoc.data()?['confessionTimeBased'] ?? false;

      // Add confession to public collection WITHOUT authorId to guarantee privacy
      final newDoc = await confessionsRef.add({
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'reactions': {},
        'timeBased': timeBased,
        'expiryTime': timeBased 
            ? Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24)))
            : null,
      });

      // Map author to this confession privately in confession_authors
      await authorsRef.doc(newDoc.id).set({
        'authorId': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Confession submitted to HAUWA.")),
        );
      }
    } catch (e) {
      print("Post Confession Error: $e");
    }
  }

  Future<void> _reactToConfession(String id, String emoji, Map reactions) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final updatedReactions = Map<String, dynamic>.from(reactions);
    final List usersReacted = updatedReactions[emoji] ?? [];

    if (usersReacted.contains(user.uid)) {
      usersReacted.remove(user.uid);
    } else {
      usersReacted.add(user.uid);
    }
    updatedReactions[emoji] = usersReacted;

    await FirebaseFirestore.instance.collection('confessions').doc(id).update({
      'reactions': updatedReactions,
    });
  }

  void _showReactionPicker(String id, Map reactions) {
    final List<String> availableEmojis = [
      "🔥", "💀", "❤️", "👻", "😱", "😂", "😢", "😮", "🤫", "🧠", "😈", "💯"
    ];
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F0F0F),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "ADD REACTION",
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 2),
              ),
              const SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.0,
                ),
                itemCount: availableEmojis.length,
                itemBuilder: (context, index) {
                  final emoji = availableEmojis[index];
                  final List usersReacted = reactions[emoji] ?? [];
                  final user = FirebaseAuth.instance.currentUser;
                  final bool hasReacted = user != null && usersReacted.contains(user.uid);
                  
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _reactToConfession(id, emoji, reactions);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: hasReacted ? const Color(0xFFFF8700).withOpacity(0.1) : Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: hasReacted ? const Color(0xFFFF8700) : Colors.white10),
                      ),
                      child: Center(
                        child: Text(emoji, style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showEasterEgg() {
    setState(() => _isEasterEggFound = true);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Color(0xFFFF00FF))),
        title: Text("👻 EASTER EGG FOUND!", style: GoogleFonts.outfit(color: const Color(0xFFFF00FF), fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.sparkles, color: Color(0xFFFF00FF), size: 48),
            const SizedBox(height: 16),
            Text(
              "Congratulations Phantom Spirit! You found the hidden portal of HAUWA.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Text(
              "Thank you for exploring the shadows of GHOSTED. Stay tuned for future secret manifestations!",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CLOSE", style: TextStyle(color: Color(0xFFFF00FF))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mode = GhostTheme.of(context)?.themeMode ?? AppThemeMode.ghosted;
    final themeColor = DesignSystem.getThemeColor(mode);
    final isComic = mode == AppThemeMode.comic;

    if (!_hasProfilePhoto) {
      return Scaffold(
        backgroundColor: isComic ? DesignSystem.comicPaper : Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: VoidEmptyState(
              message: "GATED PORTAL:\nYOU MUST SUBMIT A REAL PHOTO TO THE ARCHIVES TO ACCESS HAUWA.",
              actionLabel: "GO TO ARCHIVES",
              onAction: () {
                AppLayout.navigateTo(context, 1);
                Navigator.pop(context);
              },
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isComic ? DesignSystem.comicPaper : Colors.black,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: isComic ? DesignSystem.comicInk : Colors.white),
          onPressed: () => Navigator.pop(context),
          tooltip: "BACK",
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'HAUWA',
          style: isComic 
              ? GoogleFonts.bangers(fontWeight: FontWeight.w900, fontSize: 28, color: DesignSystem.comicInk, letterSpacing: 2)
              : GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 22, color: Colors.white, letterSpacing: 2),
        ),
        centerTitle: true,
        actions: [
          // Mysterious Easter Egg Spark (Small pixel in top right corner)
          GestureDetector(
            onTap: _showEasterEgg,
            child: Container(
              margin: const EdgeInsets.all(20),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _isEasterEggFound ? const Color(0xFFFF00FF) : Colors.white10,
                shape: BoxShape.circle,
                boxShadow: [
                  if (_isEasterEggFound)
                    const BoxShadow(color: Color(0xFFFF00FF), blurRadius: 10, spreadRadius: 2),
                ],
              ),
            ),
          ),
        ],
      ),
      body: DesignSystem.responsiveWidth(
        child: Column(
          children: [
            // Confession Input Box
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: DesignSystem.voidCard(context: context),
                child: Column(
                  children: [
                    TextField(
                      controller: _confessionController,
                      maxLines: 3,
                      maxLength: 300,
                      style: TextStyle(color: isComic ? DesignSystem.comicInk : Colors.white, fontWeight: isComic ? FontWeight.bold : FontWeight.normal),
                      decoration: InputDecoration(
                        hintText: "Whisper your deepest confession anonymously...",
                        hintStyle: TextStyle(color: isComic ? Colors.black38 : Colors.white38),
                        border: InputBorder.none,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Max 5 active confessions",
                          style: TextStyle(color: isComic ? Colors.black54 : Colors.white24, fontSize: 10),
                        ),
                        ElevatedButton.icon(
                          onPressed: _postConfession,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isComic ? DesignSystem.comicYellow : themeColor,
                            foregroundColor: isComic ? DesignSystem.comicInk : Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(isComic ? 4 : 12),
                              side: isComic ? const BorderSide(color: DesignSystem.comicInk, width: 2) : BorderSide.none,
                            ),
                            elevation: isComic ? 0 : null,
                          ),
                          icon: const Icon(LucideIcons.send, size: 14),
                          label: const Text("RELEASE"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Confessions Stream
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('confessions')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFFFF8700)));
                  }

                  final confessions = snapshot.data!.docs;

                  if (confessions.isEmpty) {
                    return Center(
                      child: Text(
                        "The sanctuary is quiet.\nRelease a confession to start HAUWA.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: isComic ? DesignSystem.comicInk.withOpacity(0.5) : Colors.white38),
                      ),
                    );
                  }

                  final currentUser = FirebaseAuth.instance.currentUser;
                  if (currentUser == null) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFFFF8700)));
                  }

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('confession_authors')
                        .where('authorId', isEqualTo: currentUser.uid)
                        .snapshots(),
                    builder: (context, authorSnapshot) {
                      final myConfessionIds = authorSnapshot.hasData
                          ? authorSnapshot.data!.docs.map((d) => d.id).toSet()
                          : <String>{};

                      return ListView.builder(
                        itemCount: confessions.length,
                        padding: const EdgeInsets.only(bottom: 120),
                        itemBuilder: (context, index) {
                          final doc = confessions[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final reactions = data['reactions'] as Map? ?? {};
                          
                          final activeReactions = reactions.entries.where((entry) {
                            final list = entry.value as List?;
                            return list != null && list.isNotEmpty;
                          }).toList();

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            padding: const EdgeInsets.all(20),
                            decoration: DesignSystem.voidCard(context: context),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(LucideIcons.ghost, size: 14, color: isComic ? DesignSystem.comicInk : const Color(0xFFFFB300)),
                                        const SizedBox(width: 8),
                                        Text(
                                          "SECRET GHOST",
                                          style: GoogleFonts.outfit(
                                            color: isComic ? DesignSystem.comicInk : const Color(0xFFFFB300),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                    // Show Delete Icon if current user is the author
                                    if (myConfessionIds.contains(doc.id))
                                      IconButton(
                                        icon: const Icon(LucideIcons.trash2, color: Colors.redAccent, size: 16),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () async {
                                          final confirmed = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              backgroundColor: const Color(0xFF0F0F0F),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(24),
                                                side: const BorderSide(color: Colors.white10),
                                              ),
                                              title: Text(
                                                "DELETE CONFESSION?",
                                                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900),
                                              ),
                                              content: const Text(
                                                "This confession will be permanently deleted from HAUWA.",
                                                style: TextStyle(color: Colors.white70),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context, false),
                                                  child: const Text("CANCEL"),
                                                ),
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context, true),
                                                  child: const Text("DELETE", style: TextStyle(color: Colors.redAccent)),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirmed == true) {
                                            await FirebaseFirestore.instance.collection('confessions').doc(doc.id).delete();
                                            await FirebaseFirestore.instance.collection('confession_authors').doc(doc.id).delete();
                                          }
                                        },
                                      ),
                                  ],
                                ),
                            const SizedBox(height: 12),
                            Text(
                              data['text'] ?? "",
                              style: DesignSystem.body(
                                context: context,
                                color: isComic ? DesignSystem.comicInk : Colors.white,
                                size: 13.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Active reactions wrap and picker button
                                Expanded(
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      ...activeReactions.map((entry) {
                                        final emoji = entry.key;
                                        final List usersReacted = entry.value;
                                        final user = FirebaseAuth.instance.currentUser;
                                        final bool hasReacted = user != null && usersReacted.contains(user.uid);
                                        
                                        return InkWell(
                                          onTap: () => _reactToConfession(doc.id, emoji, reactions),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: hasReacted 
                                                  ? (isComic ? DesignSystem.comicYellow.withOpacity(0.2) : const Color(0xFFFF8700).withOpacity(0.1)) 
                                                  : (isComic ? Colors.white : Colors.white.withOpacity(0.02)),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: hasReacted 
                                                    ? (isComic ? DesignSystem.comicInk : const Color(0xFFFF8700)) 
                                                    : (isComic ? DesignSystem.comicInk.withOpacity(0.2) : Colors.white10),
                                                width: isComic ? 1.5 : 1.0,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(emoji, style: const TextStyle(fontSize: 12)),
                                                const SizedBox(width: 4),
                                                Text(
                                                  usersReacted.length.toString(),
                                                  style: TextStyle(
                                                    color: isComic ? DesignSystem.comicInk : (hasReacted ? const Color(0xFFFF8700) : Colors.white60),
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }),
                                      
                                      // Add reaction button
                                      InkWell(
                                        onTap: () => _showReactionPicker(doc.id, reactions),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isComic ? Colors.white : Colors.white.withOpacity(0.04),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: isComic ? DesignSystem.comicInk.withOpacity(0.2) : Colors.white.withOpacity(0.1),
                                              width: isComic ? 1.5 : 1.0,
                                            ),
                                          ),
                                          child: Icon(
                                            LucideIcons.smile, 
                                            size: 12, 
                                            color: isComic ? DesignSystem.comicInk.withOpacity(0.6) : Colors.white54,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Reply button
                                InkWell(
                                  onTap: () => _openConfessionGroupChat(doc.id, data['text'] ?? ""),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isComic ? DesignSystem.comicYellow : const Color(0xFFFFB300).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isComic ? DesignSystem.comicInk : const Color(0xFFFFB300).withOpacity(0.2),
                                        width: isComic ? 1.5 : 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          LucideIcons.messageSquare, 
                                          size: 11, 
                                          color: isComic ? DesignSystem.comicInk : const Color(0xFFFFB300),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          "REPLY",
                                          style: GoogleFonts.outfit(
                                            color: isComic ? DesignSystem.comicInk : const Color(0xFFFFB300),
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openConfessionGroupChat(String id, String title) {
    final currentMode = GhostTheme.of(context)?.themeMode ?? AppThemeMode.ghosted;
    final isComic = currentMode == AppThemeMode.comic;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isComic ? DesignSystem.comicPaper : const Color(0xFF080808),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(isComic ? 16 : 32)),
      ),
      builder: (context) {
        final TextEditingController replyController = TextEditingController();
        final scrollController = ScrollController();
        final mode = GhostTheme.of(context)?.themeMode ?? AppThemeMode.ghosted;
        final tColor = DesignSystem.getThemeColor(mode);
        final comic = mode == AppThemeMode.comic;

        final textColor = comic ? DesignSystem.comicInk : Colors.white;
        final subtitleColor = comic ? DesignSystem.comicInk.withOpacity(0.6) : Colors.white38;
        final replyBgColor = comic ? Colors.white : const Color(0xFF121212);
        final replyTextColor = comic ? DesignSystem.comicInk : Colors.white70;
        final replyBorder = comic 
            ? Border.all(color: DesignSystem.comicInk, width: 2) 
            : Border.all(color: Colors.white.withOpacity(0.04));
        final replyBorderRadius = comic ? BorderRadius.circular(4) : BorderRadius.circular(20);
        final inputBgColor = comic ? Colors.white : Colors.white.withOpacity(0.03);
        final inputBorder = comic 
            ? Border.all(color: DesignSystem.comicInk, width: 2) 
            : Border.all(color: Colors.white.withOpacity(0.08));
        final inputBorderRadius = comic ? BorderRadius.circular(4) : BorderRadius.circular(16);

        return Container(
          height: (MediaQuery.of(context).size.height - MediaQuery.of(context).viewInsets.bottom) * 0.8,
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          decoration: comic ? const BoxDecoration(
            color: DesignSystem.comicPaper,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(
              top: BorderSide(color: DesignSystem.comicInk, width: 4),
            ),
          ) : null,
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Drag Handle
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: comic ? DesignSystem.comicInk.withOpacity(0.2) : Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: comic ? DesignSystem.comicYellow.withOpacity(0.2) : tColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: comic ? Border.all(color: DesignSystem.comicInk, width: 2) : null,
                      ),
                      child: Icon(
                        LucideIcons.messageSquare, 
                        color: comic ? DesignSystem.comicInk : tColor, 
                        size: 18
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "ANONYMOUS DISCUSSION",
                            style: comic 
                                ? GoogleFonts.bangers(color: DesignSystem.comicInk, fontSize: 18, letterSpacing: 1)
                                : GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 15, letterSpacing: 2),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(color: subtitleColor, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Divider(color: comic ? DesignSystem.comicInk.withOpacity(0.1) : Colors.white10, height: 1),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('confessions')
                      .doc(id)
                      .collection('replies')
                      .orderBy('timestamp', descending: false)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(child: CircularProgressIndicator(color: comic ? DesignSystem.comicInk : tColor));
                    }

                    final replies = snapshot.data!.docs;

                    if (replies.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.ghost, color: textColor.withOpacity(0.08), size: 48),
                            const SizedBox(height: 12),
                            Text(
                              "No thoughts echoed yet.\nBe the first to speak anonymously.",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(color: subtitleColor, fontSize: 12, height: 1.5),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: replies.length,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      itemBuilder: (context, index) {
                        final reply = replies[index].data() as Map<String, dynamic>;
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: replyBgColor,
                              borderRadius: replyBorderRadius,
                              border: replyBorder,
                              boxShadow: comic ? const [
                                BoxShadow(color: DesignSystem.comicInk, offset: Offset(3, 3))
                              ] : [],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(LucideIcons.ghost, size: 10, color: comic ? DesignSystem.comicInk : tColor),
                                    const SizedBox(width: 6),
                                    Text(
                                      "ANON GHOST #${index + 1}",
                                      style: comic 
                                          ? GoogleFonts.bangers(color: DesignSystem.comicInk, fontSize: 11, letterSpacing: 0.5)
                                          : GoogleFonts.outfit(color: tColor, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  reply['text'] ?? "", 
                                  style: GoogleFonts.inter(color: replyTextColor, fontSize: 13, height: 1.4, fontWeight: comic ? FontWeight.bold : FontWeight.normal)
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Divider(color: comic ? DesignSystem.comicInk.withOpacity(0.1) : Colors.white10, height: 1),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                color: comic ? DesignSystem.comicPaper : const Color(0xFF0A0A0A),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: inputBgColor,
                          borderRadius: inputBorderRadius,
                          border: inputBorder,
                        ),
                        child: TextField(
                          controller: replyController,
                          style: GoogleFonts.inter(color: textColor, fontSize: 13, fontWeight: comic ? FontWeight.bold : FontWeight.normal),
                          decoration: InputDecoration(
                            hintText: "Join the anon discussion...",
                            hintStyle: TextStyle(color: subtitleColor, fontSize: 12),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () async {
                        final text = replyController.text.trim();
                        if (text.isEmpty) return;
                        replyController.clear();

                        await FirebaseFirestore.instance
                            .collection('confessions')
                            .doc(id)
                            .collection('replies')
                            .add({
                          'text': text,
                          'timestamp': FieldValue.serverTimestamp(),
                        });
                        
                        // Scroll to bottom
                        if (scrollController.hasClients) {
                          scrollController.animateTo(
                            scrollController.position.maxScrollExtent + 100,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: comic ? DesignSystem.comicYellow : tColor,
                          shape: BoxShape.circle,
                          border: comic ? Border.all(color: DesignSystem.comicInk, width: 2) : null,
                        ),
                        child: Icon(
                          LucideIcons.send, 
                          color: comic ? DesignSystem.comicInk : Colors.black, 
                          size: 16
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
