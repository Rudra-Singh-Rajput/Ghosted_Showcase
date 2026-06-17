import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_model.dart';
import '../services/limit_service.dart';
import '../services/cloudinary_service.dart';
import '../utils/design_system.dart';
import '../widgets/youtube_player_widget.dart';

class GroupChatScreen extends StatefulWidget {
  final String chatId;
  final String groupName;

  const GroupChatScreen({super.key, required this.chatId, required this.groupName});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSendingMedia = false;
  List<String> _participants = [];

  @override
  void initState() {
    super.initState();
    _loadParticipants();
  }

  Future<void> _loadParticipants() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).get();
      final data = doc.data();
      if (data != null && data['participants'] is List) {
        setState(() {
          _participants = List<String>.from(data['participants']);
        });
      }
    } catch (e) {
      debugPrint("Load participants error: $e");
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    final canSend = await LimitService.canSendMessage();
    if (!canSend) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Weekly message limit reached.")),
        );
      }
      return;
    }

    _msgController.clear();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final email = FirebaseAuth.instance.currentUser?.email;
    final senderName = email?.split('@')[0] ?? "Ghost";

    await LimitService.incrementMessageCount();

    try {
      final batch = FirebaseFirestore.instance.batch();
      final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
      final msgRef = chatRef.collection('messages').doc();

      batch.set(msgRef, {
        'text': text,
        'senderId': uid,
        'senderName': senderName,
        'timestamp': FieldValue.serverTimestamp(),
        'deletedFor': [],
      });

      batch.set(chatRef, {
        'lastMessage': "$senderName: $text",
        'lastMessageAt': FieldValue.serverTimestamp(),
        'isGroup': true,
        'name': widget.groupName,
      }, SetOptions(merge: true));

      await batch.commit();
    } catch (e) {
      debugPrint("Send Group Message Error: $e");
    }
  }

  Future<void> _pickMedia() async {
    final canSend = await LimitService.canSendMedia();
    if (!canSend) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Weekly media limit of 10 reached.")),
        );
      }
      return;
    }

    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 40);

    if (file != null) {
      setState(() => _isSendingMedia = true);
      try {
        final bytes = await file.readAsBytes();
        final url = await CloudinaryService.uploadMedia(bytes, 'chat_media');
        
        final uid = FirebaseAuth.instance.currentUser?.uid;
        final email = FirebaseAuth.instance.currentUser?.email;
        final senderName = email?.split('@')[0] ?? "Ghost";
        final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
        
        await chatRef.collection('messages').add({
          'text': '',
          'mediaUrl': url,
          'type': 'image',
          'senderId': uid,
          'senderName': senderName,
          'timestamp': FieldValue.serverTimestamp(),
          'deletedFor': [],
        });

        await chatRef.set({
          'lastMessage': "$senderName sent an image",
          'lastMessageAt': FieldValue.serverTimestamp(),
          'isGroup': true,
          'name': widget.groupName,
        }, SetOptions(merge: true));

        await LimitService.incrementMediaCount();
      } catch (e) {
        debugPrint("Pick Media Error: $e");
      } finally {
        if (mounted) setState(() => _isSendingMedia = false);
      }
    }
  }

  void _showMessageOptions(BuildContext context, DocumentSnapshot msgDoc, bool isMe) {
    final data = msgDoc.data() as Map<String, dynamic>;
    final text = data['text'] ?? '';
    final uid = FirebaseAuth.instance.currentUser?.uid;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F0F0F),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          if (text.isNotEmpty) ListTile(
            leading: const Icon(LucideIcons.copy, color: Colors.white54),
            title: Text("COPY", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.pop(context);
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Copied to clipboard")),
              );
            },
          ),
          ListTile(
            leading: const Icon(LucideIcons.eyeOff, color: Colors.grey),
            title: Text("DELETE FOR ME", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
            onTap: () async {
              Navigator.pop(context);
              if (uid != null) {
                await msgDoc.reference.set({
                  'deletedFor': FieldValue.arrayUnion([uid]),
                }, SetOptions(merge: true));
              }
            },
          ),
          if (isMe) ListTile(
            leading: const Icon(LucideIcons.trash2, color: Colors.redAccent),
            title: Text("DELETE FOR EVERYONE", style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            onTap: () async {
              Navigator.pop(context);
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF0F0F0F),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Colors.white10)),
                  title: Text("DELETE FOR EVERYONE?", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900)),
                  content: const Text("This message will be permanently removed from the group.", style: TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL")),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text("DELETE", style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await msgDoc.reference.delete();
              }
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _leaveGroup() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F0F0F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Colors.white10)),
        title: Text("LEAVE GROUP?", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900)),
        content: Text(
          "You will no longer receive messages from \"${widget.groupName}\".",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("LEAVE", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
          'participants': FieldValue.arrayRemove([uid]),
        });

        // Post a system message
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId)
            .collection('messages')
            .add({
          'text': '👻 ${FirebaseAuth.instance.currentUser?.email?.split('@')[0] ?? "Ghost"} left the group.',
          'senderId': 'system',
          'senderName': 'System',
          'timestamp': FieldValue.serverTimestamp(),
          'deletedFor': [],
        });

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("You left the group.")),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to leave group: $e"), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.chatId == 'global_void_chat') {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text("GLOBAL CHAT", style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white)),
          centerTitle: true,
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "COMMUNICATION COMING SOON",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: const Color(0xFFFF8700),
                    shadows: [
                      Shadow(color: const Color(0xFFFF8700).withOpacity(0.5), blurRadius: 10),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Our ghost engineers are building the infrastructure. Hang tight!",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
                ),
                const SizedBox(height: 32),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: const AspectRatio(
                    aspectRatio: 16 / 9,
                    child: YoutubePlayerWidget(
                      videoId: 'J---aiyznGQ', // Funny developer coding / Keyboard Cat
                      isPlaying: true,
                      seekTime: 0,
                      enableNativeControls: true,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      );
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.groupName, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(
              "${_participants.length} members",
              style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFFFF8700), fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.logOut, color: Colors.redAccent, size: 20),
            onPressed: _leaveGroup,
            tooltip: "LEAVE GROUP",
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFFF8700)));
                }

                final messages = snapshot.data!.docs;

                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      "No messages yet.\nSend the first whisper!",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: Colors.white24, fontSize: 13),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final doc = messages[index];
                    final data = doc.data() as Map<String, dynamic>;
                    
                    // Filter messages deleted for this user
                    final deletedFor = (data['deletedFor'] as List<dynamic>?) ?? [];
                    if (uid != null && deletedFor.contains(uid)) {
                      return const SizedBox.shrink();
                    }

                    // Weekly Reset filtering
                    final Timestamp? ts = data['timestamp'] as Timestamp?;
                    if (ts != null && DateTime.now().difference(ts.toDate()).inDays >= 7) {
                      return const SizedBox.shrink();
                    }

                    final isMe = data['senderId'] == uid;
                    final isSystem = data['senderId'] == 'system';

                    if (isSystem) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              data['text'] ?? '',
                              style: GoogleFonts.inter(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
                            ),
                          ),
                        ),
                      );
                    }

                    return GestureDetector(
                      onLongPress: () => _showMessageOptions(context, doc, isMe),
                      child: Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(12),
                          constraints: const BoxConstraints(maxWidth: 280),
                          decoration: BoxDecoration(
                            color: isMe
                                ? const Color(0xFFFF8700).withOpacity(0.12)
                                : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16).copyWith(
                              bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                              bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                            ),
                            border: Border.all(
                              color: isMe
                                  ? const Color(0xFFFF8700).withOpacity(0.2)
                                  : Colors.white10,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              if (!isMe)
                                Text(
                                  data['senderName'] ?? "Ghost",
                                  style: TextStyle(
                                    color: const Color(0xFFFF8700).withOpacity(0.8),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              const SizedBox(height: 2),
                              if (data['type'] == 'image' && data['mediaUrl'] != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(data['mediaUrl'], height: 150, fit: BoxFit.cover),
                                )
                              else
                                Text(
                                  data['text'] ?? "",
                                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13, height: 1.4),
                                ),
                              const SizedBox(height: 4),
                              if (ts != null)
                                Text(
                                  "${ts.toDate().hour}:${ts.toDate().minute.toString().padLeft(2, '0')}",
                                  style: GoogleFonts.inconsolata(color: Colors.white24, fontSize: 9),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F0F),
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    LucideIcons.image,
                    color: _isSendingMedia ? const Color(0xFFFF8700) : Colors.white38,
                  ),
                  onPressed: _isSendingMedia ? null : _pickMedia,
                ),
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                    onSubmitted: (_) => _sendMessage(),
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(
                      hintText: "Send group message...",
                      hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 13),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.04),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: Color(0xFFFF8700), width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF8700),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.send, color: Colors.black, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
