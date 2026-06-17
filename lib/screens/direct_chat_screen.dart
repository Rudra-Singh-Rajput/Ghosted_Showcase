import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as ep;
import 'package:flutter/foundation.dart' as foundation;
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../utils/design_system.dart';
import '../services/limit_service.dart';
import '../services/cloudinary_service.dart';
import 'package:image_picker/image_picker.dart';

class DirectChatScreen extends StatefulWidget {
  final String chatId;
  final UserModel otherUser;

  const DirectChatScreen({super.key, required this.chatId, required this.otherUser});

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isDowntime = false;
  int _minutesUntilMidnight = 0;
  Timer? _downtimeTimer; 
  bool _showEmoji = false;
  Map<String, dynamic>? _replyingTo; // {id, text, senderId}
  bool _isSendingMedia = false;

  @override
  void initState() {
    super.initState();
    _startDowntimeClock();
  }



  @override
  void dispose() {
    _downtimeTimer?.cancel();
    super.dispose();
  }

  void _startDowntimeClock() {
    _checkDowntime();
    // Check every minute
    _downtimeTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) _checkDowntime();
    });
  }

  void _checkDowntime() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final diff = tomorrow.difference(now);
    final minutesRemaining = diff.inMinutes;

    // Show warning banner in the final 10 minutes of the day
    if (minutesRemaining < 10 && minutesRemaining >= 0 && now.hour == 23) {
      if (!_isDowntime || _minutesUntilMidnight != minutesRemaining + 1) {
        setState(() {
          _isDowntime = true;
          _minutesUntilMidnight = minutesRemaining + 1;
        });
      }
    } else if (_isDowntime) {
      setState(() => _isDowntime = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AuthService.getDisplayName(
            viewerEmail: FirebaseAuth.instance.currentUser?.email, 
            authorRealName: widget.otherUser.realName, 
            authorAlias: widget.otherUser.name, 
            context: 'seance'
          ),
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.trash2, color: Colors.redAccent, size: 18),
            onPressed: () => _banishConversation(),
            tooltip: "BANISH CONVERSATION",
          ),
          PopupMenuButton<String>(
            icon: const Icon(LucideIcons.moreVertical, color: Colors.white),
            onSelected: (val) {
              if (val == 'block') {
                _blockUser();
              } else if (val == 'report') {
                _reportAndBlockUser();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'block', child: Text("Block Account", style: TextStyle(color: Colors.redAccent))),
              const PopupMenuItem(value: 'report', child: Text("Report & Block", style: TextStyle(color: Colors.redAccent))),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background Glow
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0xFFFF8700).withOpacity(0.05), Colors.transparent],
                ),
              ),
            ),
          ),
          
          Column(
            children: [

              
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('chats')
                      .doc(widget.chatId)
                      .collection('messages')
                      .orderBy('timestamp', descending: true)
                      .limit(100)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFFFF8700)));
                    
                    final messages = snapshot.data!.docs;
                    
                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.all(20),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        if (index >= messages.length) return const SizedBox.shrink();
                        final isMe = messages[index]['senderId'] == FirebaseAuth.instance.currentUser?.uid;
                        return _buildMessageBubble(messages[index], isMe, index);
                      },
                    );
                  },
                ),
              ),
              
              // Input Area
              Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  top: 12,
                  left: 20,
                  right: 20,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F0F),
                  border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(LucideIcons.image, color: _isSendingMedia ? const Color(0xFFFF8700) : Colors.white24),
                      onPressed: _isSendingMedia ? null : _pickMedia,
                    ),
                    const SizedBox(width: 4),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        if (!_showEmoji) {
                          FocusScope.of(context).unfocus();
                        }
                        setState(() => _showEmoji = !_showEmoji);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _showEmoji ? Color(0xFFFF8700).withOpacity(0.2) : Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: _showEmoji ? const Color(0xFFFF8700) : Colors.white24),
                        ),
                        child: Icon(
                          _showEmoji ? LucideIcons.keyboard : LucideIcons.smile,
                          color: _showEmoji ? const Color(0xFFFF8700) : Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_replyingTo != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border(left: BorderSide(color: const Color(0xFFFF8700), width: 4)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Replying to",
                                          style: GoogleFonts.inter(color: const Color(0xFFFF8700), fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          _replyingTo!['text'],
                                          style: GoogleFonts.inter(color: Colors.white60, fontSize: 12),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(LucideIcons.x, color: Colors.white24, size: 14),
                                    onPressed: () => setState(() => _replyingTo = null),
                                    constraints: const BoxConstraints(),
                                    padding: EdgeInsets.zero,
                                  ),
                                ],
                              ),
                            ),
                          TextField(
                            controller: _msgController,
                            onSubmitted: (_) => _sendMessage(),
                            textInputAction: TextInputAction.send,
                            style: GoogleFonts.inter(color: Colors.white),
                            onTap: () {
                              if (_showEmoji) setState(() => _showEmoji = false);
                            },
                            decoration: InputDecoration(
                              hintText: 'Whisper something...',
                              hintStyle: GoogleFonts.inter(color: Colors.white60, fontSize: 14),
                              fillColor: Colors.white.withOpacity(0.05),
                              filled: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Color(0xFFFF8700).withOpacity(0.3))),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _sendMessage,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF8700),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(LucideIcons.send, color: Colors.black, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              if (_showEmoji)
                SizedBox(
                  height: 250,
                  child: ep.EmojiPicker(
                    onEmojiSelected: (category, emoji) {
                      _msgController.text = _msgController.text + emoji.emoji;
                    },
                    config: ep.Config(
                      columns: 7,
                      emojiSizeMax: 32 * (foundation.defaultTargetPlatform == TargetPlatform.iOS ? 1.30 : 1.0),
                      verticalSpacing: 0,
                      horizontalSpacing: 0,
                      gridPadding: EdgeInsets.zero,
                      initCategory: ep.Category.RECENT,
                      bgColor: const Color(0xFF0F0F0F),
                      indicatorColor: const Color(0xFFFF8700),
                      iconColor: Colors.grey,
                      iconColorSelected: const Color(0xFFFF8700),
                      backspaceColor: const Color(0xFFFF8700),
                      skinToneIndicatorColor: Colors.grey,
                      enableSkinTones: true,
                      recentTabBehavior: ep.RecentTabBehavior.RECENT,
                      recentsLimit: 28,
                      noRecents: const Text(
                        'No Recents',
                        style: TextStyle(fontSize: 20, color: Colors.black26),
                        textAlign: TextAlign.center,
                      ),
                      loadingIndicator: const SizedBox.shrink(),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(DocumentSnapshot doc, bool isMe, int index) {
    final data = doc.data() as Map<String, dynamic>;
    final deletedBy = (data['deletedBy'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    if (deletedBy.contains(FirebaseAuth.instance.currentUser?.uid)) {
      return const SizedBox.shrink();
    }
    
    final text = data['text'] ?? "";
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    
    // --- VAPOR BUBBLE LOGIC ---
    // Messages vanish after 24 hours. They blur and fade as they age.
    final age = DateTime.now().difference(timestamp).inHours;
    final bool isOracleChat = false;
    
    // Smooth decay over 24 hours
    final opacity = isOracleChat ? 1.0 : (1.0 - (age / 24)).clamp(0.05, 1.0);
    final blur = (!isOracleChat && age > 12) ? (age - 12) * 0.8 : 0.0;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageOptions(context, doc.id, isMe, text, data['senderId']),
        onSecondaryTap: () => _showMessageOptions(context, doc.id, isMe, text, data['senderId']),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe)
              const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (data['replyToText'] != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 2, left: 12, right: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        data['replyToText'],
                        style: GoogleFonts.inter(color: Colors.white24, fontSize: 11, fontStyle: FontStyle.italic),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (data['type'] == 'image' && data['mediaUrl'] != null)
                    Builder(
                      builder: (context) {
                        final bool oneTime = data['oneTimeView'] == true;
                        final bool isOpened = data['isOpened'] == true;
                        
                        if (oneTime && isOpened) {
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(16)),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.eyeOff, color: Colors.white24, size: 16),
                                SizedBox(width: 8),
                                Text("Opened Disappearing Image", style: TextStyle(color: Colors.white24, fontSize: 12)),
                              ],
                            ),
                          );
                        }

                        return GestureDetector(
                          onTap: () => _viewMedia(context, data['mediaUrl'], doc.id, oneTime, isMe),
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            constraints: const BoxConstraints(maxWidth: 200, maxHeight: 200),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white10),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              children: [
                                Image.network(
                                  data['mediaUrl'],
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) return child;
                                    return Container(
                                      width: 200,
                                      height: 200,
                                      color: Colors.white.withOpacity(0.02),
                                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF8700))),
                                    );
                                  },
                                ),
                                if (oneTime)
                                  Positioned.fill(
                                    child: Container(
                                      color: Colors.black54,
                                      child: const Center(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(LucideIcons.eye, color: Colors.white70, size: 16),
                                            SizedBox(width: 6),
                                            Text("One-time View", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }
                    ),
                  if (text.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isMe ? DesignSystem.ghostOrange.withOpacity(0.15) : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20).copyWith(
                          bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
                          bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
                        ),
                        border: Border.all(color: isMe ? DesignSystem.ghostOrange.withOpacity(0.3) : Colors.white10),
                      ),
                      child: Text(
                        text,
                        style: GoogleFonts.inter(color: Colors.white.withOpacity(0.95), fontSize: 14, height: 1.4),
                      ),
                    ),
                  Text(
                    "${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}",
                    style: GoogleFonts.inconsolata(color: Colors.white10, fontSize: 8),
                  ),
                ],
              ),
            ),
            if (isMe)
              const SizedBox(width: 8),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: isMe ? 0.05 : -0.05, end: 0, curve: Curves.easeOutCubic);
  }

  Future<void> _showMessageOptions(BuildContext context, String messageId, bool isMe, String text, String senderId) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F0F0F),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(LucideIcons.reply, color: Color(0xFFFF8700)),
            title: Text("REPLY", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.pop(context);
              setState(() {
                _replyingTo = {
                  'id': messageId,
                  'text': text,
                  'senderId': senderId,
                };
              });
            },
          ),
          ListTile(
            leading: const Icon(LucideIcons.eyeOff, color: Colors.grey),
            title: Text("DELETE FOR ME", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
            onTap: () async {
              Navigator.pop(context);
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid != null) {
                try {
                  await FirebaseFirestore.instance
                      .collection('chats')
                      .doc(widget.chatId)
                      .collection('messages')
                      .doc(messageId)
                      .set({
                          'deletedBy': FieldValue.arrayUnion([uid])
                      }, SetOptions(merge: true));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Message deleted for you.")),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Failed to delete message for you."), backgroundColor: Colors.redAccent),
                    );
                  }
                }
              }
            },
          ),
          if (isMe)
            ListTile(
              leading: const Icon(LucideIcons.trash2, color: Colors.redAccent),
              title: Text("DELETE FOR EVERYONE", style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF0F0F0F),
                    title: Text("DELETE FOR EVERYONE?", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900)),
                    content: const Text("Permanently erase this whisper from the void for both of you?", style: TextStyle(color: Colors.white70)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("KEEP")),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true), 
                        child: const Text("DELETE", style: TextStyle(color: Colors.redAccent))
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  try {
                    await FirebaseFirestore.instance
                        .collection('chats')
                        .doc(widget.chatId)
                        .collection('messages')
                        .doc(messageId)
                        .delete();
                        
                    // Update lastMessage in parent chat
                    final latestMsgs = await FirebaseFirestore.instance
                        .collection('chats')
                        .doc(widget.chatId)
                        .collection('messages')
                        .orderBy('timestamp', descending: true)
                        .limit(2)
                        .get();
                    
                    if (latestMsgs.docs.isNotEmpty) {
                      // Filter out the deleted message ID manually to be safe
                      final remaining = latestMsgs.docs.where((d) => d.id != messageId).toList();
                      if (remaining.isNotEmpty) {
                        final latestData = remaining.first.data();
                        await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
                          'lastMessage': latestData['text'] ?? 'Whisper vanished...',
                          'lastMessageAt': latestData['timestamp'] ?? FieldValue.serverTimestamp(),
                        });
                      } else {
                        // Truly empty now
                        await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
                          'lastMessage': 'The void is silent...',
                          'lastMessageAt': FieldValue.serverTimestamp(),
                        });
                      }
                    } else {
                      await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
                        'lastMessage': 'The void is silent...',
                        'lastMessageAt': FieldValue.serverTimestamp(),
                      });
                    }
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Message deleted for everyone.")),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("VOICE LOST: Failed to delete for everyone."), backgroundColor: Colors.redAccent),
                      );
                    }
                  }
                }
              },
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Future<void> _banishConversation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F0F0F),
        title: Text("BANISH DIALOGUE?", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900)),
        content: const Text("This will permanently sever this connection for everyone. The dialogue will vanish from the void.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("KEEP")),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("BANISH", style: TextStyle(color: Colors.redAccent))
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Delete all messages
        final msgs = await FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId)
            .collection('messages')
            .get();
        
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in msgs.docs) {
          batch.delete(doc.reference);
        }
        // Delete chat doc
        batch.delete(FirebaseFirestore.instance.collection('chats').doc(widget.chatId));
        
        final parts = widget.chatId.split('_');
        if (parts.length == 2) {
          batch.update(FirebaseFirestore.instance.collection('users').doc(parts[0]), {
            'friends': FieldValue.arrayRemove([parts[1]])
          });
          batch.update(FirebaseFirestore.instance.collection('users').doc(parts[1]), {
            'friends': FieldValue.arrayRemove([parts[0]])
          });
        }
        
        await batch.commit();
        
        if (mounted) {
          Navigator.pop(context); // Close chat
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("The connection has been severed.")));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("BANISHMENT FAILED: $e"), backgroundColor: Colors.redAccent));
        }
      }
    }
  }


  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    
    // System Pressure Check
    final canSend = await LimitService.canSendMessage();
    if (!canSend) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF0F0F0F),
            title: Text("VOID CONGESTED", style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.w900)),
            content: const Text("The spectral density is too high today. Your whispers have been auto-restricted to preserve the Void.", style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("I UNDERSTAND")),
            ],
          ),
        );
      }
      return;
    }

    _msgController.clear();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    
    // Log message for limiting
    await LimitService.incrementMessageCount();
    
    final Map<String, dynamic>? replyData = _replyingTo;
    setState(() {
      _replyingTo = null;
      _showEmoji = false;
    });

    try {
      final batch = FirebaseFirestore.instance.batch();
      final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
      final msgRef = chatRef.collection('messages').doc();

      final msgPayload = {
        'text': text,
        'senderId': uid,
        'timestamp': FieldValue.serverTimestamp(),
      };

      if (replyData != null) {
        msgPayload['replyToId'] = replyData['id'];
        msgPayload['replyToText'] = replyData['text'];
        msgPayload['replyToSenderId'] = replyData['senderId'];
      }

      batch.set(msgRef, msgPayload);

      batch.set(chatRef, {
        'participants': [uid, widget.otherUser.uid],
        'lastMessage': text,
        'lastMessageAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("VOICE LOST: Failed to send whisper."), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _pickMedia() async {
    final canSend = await LimitService.canSendMedia();
    if (!canSend) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF0F0F0F),
            title: Text("MEDIA LIMIT REACHED", style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.w900)),
            content: const Text("You can only share 10 media whispers per week to preserve the Void's memory.", style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("I UNDERSTAND")),
            ],
          ),
        );
      }
      return;
    }

    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    
    if (file != null && mounted) {
      // Prompt for one-time view vs regular
      final bool? isOneTime = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: const Color(0xFF0F0F0F),
          title: Text("SEND OPTION", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900)),
          content: const Text("Would you like to send this as a disappearing One-time View image?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("REGULAR")),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("ONE-TIME VIEW", style: TextStyle(color: Color(0xFFFF8700)))),
          ],
        ),
      );

      if (isOneTime == null) return;

      setState(() => _isSendingMedia = true);
      try {
        final bytes = await file.readAsBytes();
        final url = await CloudinaryService.uploadMedia(bytes, 'chat_media');
        
        final uid = FirebaseAuth.instance.currentUser?.uid;
        await LimitService.incrementMediaCount();

        final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
        final msgRef = chatRef.collection('messages').doc();

        await msgRef.set({
          'text': '',
          'type': 'image',
          'mediaUrl': url,
          'senderId': uid,
          'oneTimeView': isOneTime,
          'isOpened': false,
          'timestamp': FieldValue.serverTimestamp(),
        });

        await chatRef.set({
          'lastMessage': isOneTime ? '📷 Disappearing Image' : '📷 Image',
          'lastMessageAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Media upload failed: $e"), backgroundColor: Colors.redAccent));
        }
      } finally {
        if (mounted) setState(() => _isSendingMedia = false);
      }
    }
  }

  void _viewMedia(BuildContext context, String url, String messageId, bool oneTime, bool isMe) {
    if (oneTime && !isMe) {
      FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .doc(messageId)
          .update({'isOpened': true});
    }

    showDialog(
      context: context,
      builder: (context) => Scaffold(
        backgroundColor: Colors.black.withOpacity(0.9),
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: Center(
          child: Hero(
            tag: url,
            child: InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _blockUser() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;
    
    await FirebaseFirestore.instance.collection('blocked').doc("${myUid}_${widget.otherUser.uid}").set({
      'blockedBy': myUid,
      'blockedUser': widget.otherUser.uid,
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Spirit blocked.")));
      Navigator.pop(context); // Exit chat
    }
  }

  Future<void> _reportAndBlockUser() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    await FirebaseFirestore.instance.collection('reports').add({
      'reportedBy': myUid,
      'reportedUser': widget.otherUser.uid,
      'timestamp': FieldValue.serverTimestamp(),
      'chatId': widget.chatId,
    });

    await _blockUser();
  }
}

