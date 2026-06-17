import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import 'direct_chat_screen.dart';
import 'group_chat_screen.dart';
import '../utils/design_system.dart';
import '../layout/app_layout.dart';
import 'settings_screen.dart';
import '../widgets/ghost_theme.dart';

class ChatInboxScreen extends StatefulWidget {
  const ChatInboxScreen({super.key});

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen> {
  List<String> _blockedUsers = [];

  @override
  void initState() {
    super.initState();
    _loadBlockList();
  }

  Future<void> _loadBlockList() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Load blocked list
    final snap = await FirebaseFirestore.instance
        .collection('blocked')
        .where('blockedBy', isEqualTo: user.uid)
        .get();

    final blocked = snap.docs.map((doc) => doc.data()['blockedUser'] as String).toList();
    if (mounted) {
      setState(() => _blockedUsers = blocked);
    }
  }

  void _createNewGroup() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final groupNameController = TextEditingController();
    List<String> selectedMembers = [user.uid];

    // Show list of matching chat participants to invite
    final chatsSnap = await FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: user.uid)
        .get();

    List<UserModel> availableFriends = [];
    for (var doc in chatsSnap.docs) {
      final data = doc.data();
      if (data['isGroup'] == true) continue;
      final participants = data['participants'] as List;
      final otherId = participants.firstWhere((id) => id != user.uid, orElse: () => null);
      if (otherId != null) {
        final uDoc = await FirebaseFirestore.instance.collection('users').doc(otherId).get();
        if (uDoc.exists) {
          availableFriends.add(UserModel.fromDocument(uDoc));
        }
      }
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F0F0F),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Colors.white10)),
              title: Text(
                "CREATE GHOST GROUP",
                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 300,
                child: Column(
                  children: [
                    TextField(
                      controller: groupNameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: "Group Name",
                        labelStyle: TextStyle(color: Colors.white38),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF8700))),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: availableFriends.isEmpty
                          ? const Center(child: Text("No matched friends available to add.", style: TextStyle(color: Colors.white24)))
                          : ListView.builder(
                              itemCount: availableFriends.length,
                              itemBuilder: (context, idx) {
                                final friend = availableFriends[idx];
                                final isSelected = selectedMembers.contains(friend.uid);
                                return CheckboxListTile(
                                  title: Text(friend.name, style: const TextStyle(color: Colors.white)),
                                  value: isSelected,
                                  activeColor: const Color(0xFFFF8700),
                                  onChanged: (val) {
                                    setModalState(() {
                                      if (val == true) {
                                        selectedMembers.add(friend.uid);
                                      } else {
                                        selectedMembers.remove(friend.uid);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("CANCEL", style: TextStyle(color: Colors.white38)),
                ),
                TextButton(
                  onPressed: () async {
                    final name = groupNameController.text.trim();
                    if (name.isEmpty) return;
                    Navigator.pop(context);

                    await FirebaseFirestore.instance.collection('chats').add({
                      'isGroup': true,
                      'name': name,
                      'participants': selectedMembers,
                      'createdAt': FieldValue.serverTimestamp(),
                      'lastMessageAt': FieldValue.serverTimestamp(),
                      'lastMessage': "Group chat formed.",
                    });
                  },
                  child: const Text("CREATE", style: TextStyle(color: Color(0xFFFF8700))),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mode = GhostTheme.of(context)?.themeMode ?? AppThemeMode.ghosted;
    final isComic = mode == AppThemeMode.comic;
    final currentUser = FirebaseAuth.instance.currentUser;
    final query = FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: currentUser?.uid)
        .orderBy('lastMessageAt', descending: true);

    return Scaffold(
      backgroundColor: isComic ? DesignSystem.comicPaper : Colors.black,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(LucideIcons.menu, color: isComic ? DesignSystem.comicInk : Colors.white),
          onPressed: () => AppLayout.openDrawer(context),
          tooltip: "OPEN MENU",
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'WHISPER INBOX',
          style: isComic 
              ? GoogleFonts.bangers(fontSize: 26, color: DesignSystem.comicInk, letterSpacing: 2)
              : GoogleFonts.outfit(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: 2,
                  color: Colors.white,
                ),
        ),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.users, color: isComic ? DesignSystem.comicInk : const Color(0xFFFF8700)),
            onPressed: _createNewGroup,
            tooltip: "CREATE GROUP",
          ),
          IconButton(
            icon: Icon(LucideIcons.settings, color: isComic ? DesignSystem.comicInk : Colors.white70),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
            tooltip: "SETTINGS",
          ),
        ],
      ),
      body: DesignSystem.responsiveWidth(
        child: StreamBuilder<QuerySnapshot>(
          stream: query.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text("ERROR: ${snapshot.error}", style: const TextStyle(color: Colors.white24)));
            }
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFFFF8700)));
            return _buildChatList(context, snapshot.data!.docs);
          },
        ),
      ),
    );
  }

  Widget _buildChatList(BuildContext context, List<QueryDocumentSnapshot> chatDocs) {
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
    
    // Filter out chats hidden by current user
    final visibleChats = chatDocs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final hiddenFor = (data['hiddenFor'] as List<dynamic>?) ?? [];
      return currentUserUid == null || !hiddenFor.contains(currentUserUid);
    }).toList();
    
    final mode = GhostTheme.of(context)?.themeMode ?? AppThemeMode.ghosted;
    final isComic = mode == AppThemeMode.comic;

    if (visibleChats.isEmpty) {
      return Center(
        child: Text(
          "Your inbox is a ghost town.\nStart a Whisper from the Void!",
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: isComic ? DesignSystem.comicInk.withOpacity(0.6) : Colors.white24, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120),
      itemCount: visibleChats.length,
      itemBuilder: (context, index) {
        final chatData = visibleChats[index].data() as Map<String, dynamic>;
        final String chatId = visibleChats[index].id;
        final bool isGroup = chatData['isGroup'] == true;

        if (isGroup) {
          return _buildGroupTile(context, chatId, chatData);
        }

        final List participants = chatData['participants'] as List;
        final otherUserId = participants.firstWhere((id) => id != currentUserUid, orElse: () => null);

        if (otherUserId == null) return const SizedBox.shrink();
        
        // Filter out DMs with blocked users
        if (_blockedUsers.contains(otherUserId)) return const SizedBox.shrink();

        return _buildChatTile(context, chatId, otherUserId, chatData);
      },
    );
  }


  Widget _buildGroupTile(BuildContext context, String chatId, Map<String, dynamic> chatData) {
    final Timestamp? lastAt = chatData['lastMessageAt'] as Timestamp?;
    final bool isExpired = lastAt != null && DateTime.now().difference(lastAt.toDate()).inDays >= 7;
    final String displayMessage = isExpired ? "The void is silent..." : (chatData['lastMessage'] ?? "Click to whisper...");

    final mode = GhostTheme.of(context)?.themeMode ?? AppThemeMode.ghosted;
    final isComic = mode == AppThemeMode.comic;

    return ListTile(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupChatScreen(chatId: chatId, groupName: chatData['name'] ?? "Ghost Group"))),
      leading: CircleAvatar(
        backgroundColor: isComic ? Colors.white : Colors.white10,
        child: Icon(LucideIcons.users, color: isComic ? DesignSystem.comicInk : const Color(0xFFFF8700)),
      ),
      title: Text(
        chatData['name'] ?? "Ghost Group",
        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: isComic ? DesignSystem.comicInk : Colors.white),
      ),
      subtitle: Text(
        displayMessage,
        style: GoogleFonts.inter(color: isComic ? DesignSystem.comicInk.withOpacity(0.6) : Colors.white38, fontSize: 13),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(LucideIcons.chevronRight, color: isComic ? DesignSystem.comicInk.withOpacity(0.4) : Colors.white12, size: 16),
    );
  }

  Widget _buildChatTile(BuildContext context, String chatId, String otherUserId, Map<String, dynamic> chatData) {
    final Timestamp? lastAt = chatData['lastMessageAt'] as Timestamp?;
    final bool isExpired = lastAt != null && DateTime.now().difference(lastAt.toDate()).inDays >= 7;
    final String displayMessage = isExpired ? "The void is silent..." : (chatData['lastMessage'] ?? "Click to whisper...");

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
        final otherUser = UserModel.fromDocument(snapshot.data!);

        final mode = GhostTheme.of(context)?.themeMode ?? AppThemeMode.ghosted;
        final isComic = mode == AppThemeMode.comic;

        return ListTile(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DirectChatScreen(chatId: chatId, otherUser: otherUser))),
          onLongPress: () => _confirmDeleteChat(context, chatId),
          leading: CircleAvatar(
            backgroundColor: isComic ? Colors.white : Colors.white10,
            backgroundImage: otherUser.photoUrl.isNotEmpty ? NetworkImage(otherUser.photoUrl) : null,
            child: otherUser.photoUrl.isEmpty ? Icon(LucideIcons.user, color: isComic ? DesignSystem.comicInk.withOpacity(0.4) : Colors.white24) : null,
          ),
          title: Text(
            otherUser.name,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: isComic ? DesignSystem.comicInk : Colors.white),
          ),
          subtitle: Text(
            displayMessage,
            style: GoogleFonts.inter(color: isComic ? DesignSystem.comicInk.withOpacity(0.6) : Colors.white38, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (lastAt != null && !isExpired)
                Text(
                  _formatTimestamp(lastAt),
                  style: GoogleFonts.inter(color: isComic ? DesignSystem.comicInk.withOpacity(0.5) : Colors.white12, fontSize: 9),
                ),
              Icon(LucideIcons.chevronRight, color: isComic ? DesignSystem.comicInk.withOpacity(0.4) : Colors.white12, size: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteChat(BuildContext context, String chatId) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F0F0F),
        title: Text("DELETE THIS CHAT?", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900)),
        content: const Text("This will hide this conversation from your inbox. The other person can still see it.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL")),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("DELETE", style: TextStyle(color: Colors.redAccent))
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        // Hide for current user only (don't delete for other person)
        await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
          'hiddenFor': FieldValue.arrayUnion([uid]),
        }, SetOptions(merge: true));
      }
    }
  }

  String _formatTimestamp(Timestamp ts) {
    final now = DateTime.now();
    final date = ts.toDate();
    final diff = now.difference(date);
    
    if (diff.inDays > 0) return "${diff.inDays}d ago";
    if (diff.inHours > 0) return "${diff.inHours}h ago";
    if (diff.inMinutes > 0) return "${diff.inMinutes}m ago";
    return "just now";
  }
}

