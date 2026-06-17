import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/seance_model.dart';
import '../utils/design_system.dart';
import '../widgets/ghost_theme.dart';

class SeanceChatScreen extends StatefulWidget {
  final String peerBio;
  const SeanceChatScreen({super.key, required this.peerBio});

  @override
  State<SeanceChatScreen> createState() => _SeanceChatScreenState();
}

class _SeanceChatScreenState extends State<SeanceChatScreen> {
  final List<Message> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final int maxMessages = 7;
  bool _isLocked = false;
  bool _hasRevealed = false;

  void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;
    if (_messages.length < maxMessages) {
      setState(() {
        _messages.add(Message(senderId: 'me', text: _controller.text, timestamp: DateTime.now()));
        _controller.clear();
        if (_messages.length >= maxMessages) _isLocked = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = GhostTheme.of(context)?.themeMode ?? AppThemeMode.ghosted;
    final themeColor = DesignSystem.getThemeColor(mode);
    final count = _messages.length;

    return Scaffold(
      backgroundColor: mode == AppThemeMode.comic ? DesignSystem.comicPaper : Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.chevronLeft, color: mode == AppThemeMode.comic ? DesignSystem.comicInk : Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(widget.peerBio.toUpperCase(), 
              style: DesignSystem.heading(context: context, size: 14, color: mode == AppThemeMode.comic ? DesignSystem.comicInk : themeColor)),
            Text("${maxMessages - count} WHISPERS REMAINING", 
              style: GoogleFonts.inconsolata(fontSize: 10, color: mode == AppThemeMode.comic ? DesignSystem.comicInk.withOpacity(0.5) : Colors.white38, letterSpacing: 2)),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // PROGRESS RITUAL
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: count / maxMessages,
                  minHeight: 6,
                  backgroundColor: mode == AppThemeMode.comic ? DesignSystem.comicInk.withOpacity(0.1) : Colors.white10,
                  valueColor: AlwaysStoppedAnimation<Color>(mode == AppThemeMode.comic ? DesignSystem.comicInk : themeColor),
                ),
              ),
            ),
          ),
          
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              itemCount: _messages.length,
              reverse: false,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg.senderId == 'me';
                return _buildMessageBubble(msg, isMe, mode, themeColor);
              },
            ),
          ),
          
          if (_isLocked && !_hasRevealed)
            _buildRevealButton(mode, themeColor)
          else if (!_isLocked)
            _buildChatInput(mode, themeColor),
          
          const SafeArea(top: false, child: SizedBox(height: 8)),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message msg, bool isMe, AppThemeMode mode, Color themeColor) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: mode == AppThemeMode.comic
          ? BoxDecoration(
              color: isMe ? DesignSystem.comicYellow : Colors.white,
              border: Border.all(color: DesignSystem.comicInk, width: 3),
              boxShadow: [BoxShadow(color: DesignSystem.comicInk, offset: Offset(isMe ? 4 : -4, 4))],
            )
          : BoxDecoration(
              color: isMe ? themeColor.withOpacity(0.2) : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isMe ? 20 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 20),
              ),
              border: Border.all(color: isMe ? themeColor.withOpacity(0.5) : Colors.white10),
            ),
        child: Text(msg.text, 
          style: GoogleFonts.inconsolata(
            color: mode == AppThemeMode.comic ? DesignSystem.comicInk : Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          )),
      ).animate().fadeIn(duration: 400.ms).slideX(begin: isMe ? 0.1 : -0.1, end: 0),
    );
  }

  Widget _buildChatInput(AppThemeMode mode, Color themeColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        decoration: mode == AppThemeMode.comic
          ? BoxDecoration(
              color: Colors.white,
              border: Border.all(color: DesignSystem.comicInk, width: 3),
              boxShadow: const [BoxShadow(color: DesignSystem.comicInk, offset: Offset(6, 6))],
            )
          : BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: themeColor.withOpacity(0.3)),
            ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                style: GoogleFonts.inconsolata(color: mode == AppThemeMode.comic ? DesignSystem.comicInk : Colors.white),
                decoration: InputDecoration(
                  hintText: "Summon words...",
                  hintStyle: GoogleFonts.inconsolata(color: mode == AppThemeMode.comic ? DesignSystem.comicInk.withOpacity(0.4) : Colors.white24),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            IconButton(
              icon: Icon(LucideIcons.send, color: mode == AppThemeMode.comic ? DesignSystem.comicInk : themeColor),
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevealButton(AppThemeMode mode, Color themeColor) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: InkWell(
        onTap: () => setState(() => _hasRevealed = true),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: mode == AppThemeMode.comic
            ? BoxDecoration(
                color: DesignSystem.comicYellow,
                border: Border.all(color: DesignSystem.comicInk, width: 3),
                borderRadius: BorderRadius.circular(4),
                boxShadow: const [BoxShadow(color: DesignSystem.comicInk, offset: Offset(4, 4))],
              )
            : BoxDecoration(
                gradient: LinearGradient(colors: [themeColor, themeColor.withOpacity(0.5)]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: themeColor.withOpacity(0.4), blurRadius: 20)],
              ),
          child: Center(
            child: Text("REVEAL TRUE IDENTITY", 
              style: mode == AppThemeMode.comic 
                ? GoogleFonts.bangers(color: DesignSystem.comicInk, fontSize: 20, letterSpacing: 1.5)
                : GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.black)),
          ),
        ),
      ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(duration: 2.seconds),
    );
  }
}

