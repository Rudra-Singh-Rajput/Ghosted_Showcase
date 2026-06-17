import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import '../models/wispr_model.dart';
import '../screens/wispr_detail_screen.dart';
import '../screens/direct_chat_screen.dart';
import '../models/user_model.dart';
import '../services/limit_service.dart';
import 'reel_player.dart';
import 'voice_player.dart';
import '../services/decay_service.dart';
import '../services/cloudinary_service.dart';
import '../services/auth_service.dart';
import '../utils/design_system.dart';
import '../services/resonance_service.dart';
import '../services/daily_ritual_service.dart';
import 'ghost_theme.dart';

class ThreadCard extends StatefulWidget {
  final Wispr wispr;
  final bool isDetail;

  const ThreadCard({super.key, required this.wispr, this.isDetail = false});

  @override
  State<ThreadCard> createState() => _ThreadCardState();
}

class _ThreadCardState extends State<ThreadCard> with SingleTickerProviderStateMixin {
  late AnimationController _heartController;
  late final String _currentUserUid;
  UserModel? _author;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _currentUserUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _heartController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _checkAdminAndFetchAuthor();
    _startVanishingEffect();
  }

  Future<void> _checkAdminAndFetchAuthor() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final email = user.email?.trim().toLowerCase();
    final bool isAdmin = AuthService.isAuthorized(email);
    
    if (mounted) setState(() => _isAdmin = isAdmin);

    // Everyone fetches author data now, but visibility is gated by getDisplayName
    final doc = await FirebaseFirestore.instance.collection('users').doc(widget.wispr.authorId).get();
    if (doc.exists && mounted) {
      setState(() {
        _author = UserModel.fromDocument(doc);
      });
    }
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ThreadCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wispr.expiresAt != widget.wispr.expiresAt || 
        oldWidget.wispr.id != widget.wispr.id) {
      if (mounted) {
        setState(() {
          // Trigger repaint
        });
      }
    }
  }

  void _startVanishingEffect() {
    if (!mounted) return;
    
    if (mounted) {
      setState(() {
        // Trigger repaint
      });
    }

    // Refresh every 30 seconds for a smooth live fade
    Future.delayed(const Duration(seconds: 30), _startVanishingEffect);
  }

  @override
  Widget build(BuildContext context) {
    final isLiked = widget.wispr.likedBy.contains(_currentUserUid);
    final timeLived = DateTime.now().difference(widget.wispr.createdAt).inMinutes;
    final totalLife = widget.wispr.expiresAt.difference(widget.wispr.createdAt).inMinutes;
    final lifePercentage = (timeLived / totalLife).clamp(0.0, 1.0);
    final bool isDying = lifePercentage > 0.8;
    
    final bool isFire = widget.wispr.element == 'fire';
    final bool isExpired = widget.wispr.expiresAt.isBefore(DateTime.now());
    
    if (isExpired && !widget.isDetail) return const SizedBox.shrink();

    final bool isHot = (widget.wispr.uniqueCommenters.length) >= 5 || isFire;
    final remaining = widget.wispr.expiresAt.difference(DateTime.now());
    final bool isUrgent = remaining.inHours == 0 && remaining.inMinutes < 30;
    final mode = GhostTheme.of(context)?.themeMode ?? AppThemeMode.ghosted;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: DesignSystem.voidCard(context: context, radius: 28),
      child: Stack(
        children: [
          // Removed messy gradients for a sober look
          
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: InkWell(
          onTap: widget.isDetail ? null : () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => WisprDetailScreen(wispr: widget.wispr)),
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _buildHeatIndicator(isDying),
                        if (widget.wispr.isPinned) ...[
                          const SizedBox(width: 8),
                          _buildPinnedIndicator(),
                        ],
                      ],
                    ),
                    _buildTimeLeft(widget.wispr),
                  ],
                ),
                if (_author != null) ...[
                  const SizedBox(height: 8),
                  if (mode == AppThemeMode.comic)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: DesignSystem.comicYellow,
                        border: Border.all(color: DesignSystem.comicInk, width: 2),
                      ),
                      transform: Matrix4.rotationZ(-0.02),
                      child: Text(
                        "WHISPER BY: ${AuthService.getDisplayName(
                          viewerEmail: FirebaseAuth.instance.currentUser?.email,
                          authorRealName: _author!.realName,
                          authorAlias: _author!.name,
                          context: 'wispr'
                        ).toUpperCase()}",
                        style: GoogleFonts.bangers(color: DesignSystem.comicInk, fontSize: 12, letterSpacing: 1),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF8700).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFF8700).withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.eye, color: Color(0xFFFF8700), size: 12),
                          const SizedBox(width: 6),
                          Text(
                            "BY: ${AuthService.getDisplayName(
                              viewerEmail: FirebaseAuth.instance.currentUser?.email,
                              authorRealName: _author!.realName,
                              authorAlias: _author!.name,
                              context: 'wispr'
                            )} [${_author!.displayTitle}] ${ResonanceService.getFlairForLevel(_author!.level ?? 1)}",
                            style: DesignSystem.sub(color: DesignSystem.ghostOrange, size: 9),
                          ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 16),
                
                if (widget.wispr.title != null && widget.wispr.title!.isNotEmpty) ...[
                  Text(
                    widget.wispr.title!.toUpperCase(),
                    style: mode == AppThemeMode.comic 
                      ? GoogleFonts.bangers(color: DesignSystem.comicInk, fontSize: 28, letterSpacing: 1.5)
                      : GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                  ),
                  const SizedBox(height: 8),
                ],
                
                Text(
                  widget.wispr.text,
                  style: mode == AppThemeMode.comic
                    ? GoogleFonts.inter(color: DesignSystem.comicInk, fontSize: 16, height: 1.4, fontWeight: FontWeight.bold)
                    : GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 17,
                        height: 1.5,
                        fontWeight: FontWeight.w400,
                      ),
                ),
      
                if (widget.wispr.mediaUrl != null) ...[
                  const SizedBox(height: 20),
                  _buildMediaContent(),
                ],
                
                if (widget.wispr.isPoll) ...[
                  const SizedBox(height: 24),
                  _buildGradientPoll(widget.wispr.pollOptions!),
                ],
                
                const SizedBox(height: 24),
                Row(
                  children: [
                    _buildInteractionButton(
                      isLiked ? LucideIcons.heart : LucideIcons.heart,
                      isLiked ? (GhostTheme.of(context)?.themeMode == AppThemeMode.comic ? DesignSystem.candyPink : const Color(0xFFFF00FF)) 
                              : (GhostTheme.of(context)?.themeMode == AppThemeMode.comic ? Colors.black26 : Colors.white24),
                      _toggleLike,
                    ).animate(controller: _heartController, autoPlay: false)
                     .scale(begin: const Offset(1, 1), end: const Offset(1.5, 1.5), duration: 200.ms, curve: Curves.elasticOut)
                     .then().scale(begin: const Offset(1.5, 1.5), end: const Offset(1, 1), duration: 200.ms)
                     .shimmer(duration: 2.seconds, color: const Color(0xFFFF00FF).withOpacity(0.3)),
                    const SizedBox(width: 24),
                    
                    Row(
                      children: [
                        Icon(LucideIcons.messageSquare, 
                          color: GhostTheme.of(context)?.themeMode == AppThemeMode.comic ? Colors.black26 : Colors.white24, 
                          size: 16),
                        const SizedBox(width: 8),
                        AnimatedCounter(value: widget.wispr.replyCount),
                      ],
                    ),
                    const SizedBox(width: 24),
                    
                    if (isHot)
                      const Icon(LucideIcons.flame, color: Color(0xFFFF8700), size: 16)
                        .animate(onPlay: (c) => c.repeat())
                        .shimmer(duration: 1.2.seconds, color: Colors.white24)
                        .scale(begin: const Offset(1,1), end: const Offset(1.1, 1.1), duration: 600.ms),

                    const SizedBox(width: 24),
                    _buildInteractionButton(
                      LucideIcons.wind, 
                      DesignSystem.ghostOrange.withOpacity(0.7), 
                      () => _startWhisper(context)
                    ),

                    const Spacer(),
                    if (_isAdmin)
                      _buildInteractionButton(LucideIcons.trash2, Colors.redAccent.withOpacity(0.6), () => _deleteWispr(context))
                    else if (widget.wispr.authorId == _currentUserUid)
                      _buildInteractionButton(LucideIcons.trash2, Colors.white10, () => _deleteWispr(context)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // THE DECAY BAR (Flickering Progress)
                  Stack(
                    children: [
                      Container(
                        height: 2,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(seconds: 1),
                        height: 2,
                        width: MediaQuery.of(context).size.width * (1.0 - lifePercentage),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(1),
                          gradient: LinearGradient(
                            colors: [
                              GhostTheme.of(context)?.themeMode == AppThemeMode.comic ? DesignSystem.slimeGreen : DesignSystem.ghostOrange,
                              isUrgent 
                                ? (GhostTheme.of(context)?.themeMode == AppThemeMode.comic ? DesignSystem.bubblegumPink : const Color(0xFFFF00FF)) 
                                : (GhostTheme.of(context)?.themeMode == AppThemeMode.comic ? DesignSystem.slimeGreen.withOpacity(0.5) : DesignSystem.ghostOrange.withOpacity(0.5)),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isUrgent ? const Color(0xFFFF00FF) : DesignSystem.ghostOrange).withOpacity(0.3),
                              blurRadius: 4,
                            )
                          ],
                        ),
                      ).animate(
                        onPlay: (c) => c.repeat(),
                        // LIFE COUNTER FLICKER: 10-5 mins remaining
                        target: (remaining.inMinutes <= 10 && remaining.inMinutes >= 5) ? 1 : 0,
                      )
                       .custom(
                          duration: 2.seconds,
                          builder: (context, value, child) => Opacity(
                            opacity: (remaining.inMinutes <= 10 && remaining.inMinutes >= 5) 
                                ? (0.7 + (0.3 * sin(value * pi * 15))) // Rapid flicker
                                : 1.0, // Solid otherwise
                            child: child,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildHeatIndicator(bool isDying) {
    final int replyCount = widget.wispr.replyCount;
    if (!isDying && replyCount < 15) return const SizedBox.shrink(); // REMOVED STABLE

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.activity, color: replyCount >= 15 ? DesignSystem.ghostOrange : Colors.white24, size: 12),
          const SizedBox(width: 6),
          Text(
            isDying ? "FADING" : "INTENSE",
            style: GoogleFonts.outfit(
              color: replyCount >= 15 ? Colors.white : Colors.white24, 
              fontSize: 8, 
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaContent() {
    switch (widget.wispr.type) {
      case WisprType.reel:
        return Container(
          constraints: const BoxConstraints(maxHeight: 400),
          width: double.infinity,
          child: ReelPlayer(url: widget.wispr.mediaUrl!),
        );
      case WisprType.voice:
        return VoicePlayer(url: widget.wispr.mediaUrl!);
      case WisprType.image:
        return Container(
          constraints: const BoxConstraints(maxHeight: 350),
          width: double.infinity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
          child: ShaderMask(
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Colors.white.withOpacity(0.5), Colors.white],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(rect),
            blendMode: BlendMode.modulate,
            child: Image.network(
              widget.wispr.mediaUrl!,
              fit: BoxFit.contain, 
              loadingBuilder: (context, child, loadingProgress) {
                return loadingProgress == null 
                  ? child 
                  : Container(height: 200, color: Colors.white.withOpacity(0.01));
              },
            ),
          ),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _toggleLike() async {
    final uid = _currentUserUid;
    if (uid.isEmpty) return;

    try {
      final wisprRef = FirebaseFirestore.instance.collection('wisprs').doc(widget.wispr.id);
      final isLiked = widget.wispr.likedBy.contains(uid);
      
      if (isLiked) {
        await wisprRef.set({'likedBy': FieldValue.arrayRemove([uid])}, SetOptions(merge: true));
      } else {
        // BONUS TIME RITUAL
        // Only extend life on every 5th UNIQUE interaction (Like or Comment)
        final snap = await wisprRef.get();
        final data = snap.data();
        if (data != null && !widget.wispr.isPoll) {
          final List<String> likedBy = List<String>.from(data['likedBy'] ?? []);
          final List<String> uniqueCommenters = List<String>.from(data['uniqueCommenters'] ?? []);
          
          final Set<String> totalEngaged = Set.from(likedBy)..addAll(uniqueCommenters);
          final bool isNewEngagement = !totalEngaged.contains(uid);
          
          if (isNewEngagement) {
            // It's the Nth unique person to interact.
            final int newTotalCount = totalEngaged.length + 1;
            if (newTotalCount > 0 && newTotalCount % 5 == 0) {
              final newExpiresAt = DecayService.extendLife(widget.wispr.expiresAt, widget.wispr.type);
              await wisprRef.update({
                'likedBy': FieldValue.arrayUnion([uid]),
                'expiresAt': Timestamp.fromDate(newExpiresAt),
              });
            } else {
              await wisprRef.update({
                'likedBy': FieldValue.arrayUnion([uid]),
              });
            }
          } else {
             await wisprRef.update({
              'likedBy': FieldValue.arrayUnion([uid]),
            });
          }
        } else {
          await wisprRef.update({
            'likedBy': FieldValue.arrayUnion([uid]),
          });
        }
        _heartController.forward(from: 0);
        _showXPPulse(context, "+${ResonanceService.XP_PER_LIKE} XP", const Color(0xFFFF00FF));
        ResonanceService.gainResonance(ResonanceService.XP_PER_LIKE);
        DailyRitualService.trackAction('like');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("VOICE LOST: Failed to echo like."), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _deleteWispr(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F0F0F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Colors.white10)),
        title: Text("BANISH WISPR?", style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white)),
        content: Text("Are you sure you want to delete this wispr?", style: GoogleFonts.inter(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("CANCEL", style: GoogleFonts.outfit(color: Colors.white24))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text("BANISH", style: GoogleFonts.outfit(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        // Purge media if exists
        if (widget.wispr.mediaUrl != null && widget.wispr.mediaUrl!.isNotEmpty) {
          CloudinaryService.deleteMedia(widget.wispr.mediaUrl);
        }
        await FirebaseFirestore.instance.collection('wisprs').doc(widget.wispr.id).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Wispr banished from the void.")),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("VOICE LOST: Failed to banish wispr."), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }



  Future<void> _startWhisper(BuildContext context) async {
    final myUid = _currentUserUid;
    if (myUid.isEmpty) return;
    if (myUid == widget.wispr.authorId) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("YOU CANNOT WHISPER TO YOUR OWN SPIRIT.")));
       return;
    }

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("SPIRIT PROTOCOL: BYPASSING LEVEL CHECK..."),
            backgroundColor: Color(0xFF00FF88),
            duration: Duration(milliseconds: 500),
          ),
        );
      }
      final canChat = await LimitService.canInitiateChat();
      if (!canChat) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Soul limit reached!")));
        return;
      }

      // Use deterministic compareTo instead of hashCode for consistency
      final chatId = (myUid.compareTo(widget.wispr.authorId) < 0) 
          ? '${myUid}_${widget.wispr.authorId}' 
          : '${widget.wispr.authorId}_$myUid';
          
      final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
      final chatDoc = await chatRef.get();

      if (!chatDoc.exists) {
        await chatRef.set({
          'participants': [myUid, widget.wispr.authorId],
          'lastMessageAt': FieldValue.serverTimestamp(),
          'lastMessage': "A new spirit has surfaced...",
        });
        await LimitService.incrementSoul();
      }

      final otherUserDoc = await FirebaseFirestore.instance.collection('users').doc(widget.wispr.authorId).get();
      if (!otherUserDoc.exists) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("THE SPIRIT IS NO LONGER IN THE ARCHIVES.")));
        return;
      }
      final otherUser = UserModel.fromDocument(otherUserDoc);

      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => DirectChatScreen(chatId: chatId, otherUser: otherUser)));
      }
    } catch (e) {
      print("WIND ICON ERROR: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("THE VOID IS UNSTABLE: $e"), backgroundColor: Colors.redAccent)
        );
      }
    }
  }

  Widget _buildTimeLeft(Wispr w) {
    final remaining = w.expiresAt.difference(DateTime.now());
    if (remaining.isNegative) {
      return Text(
        "VANISHED", 
        style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)
      );
    }

    if (remaining.inDays > 30) {
      return Text(
        "ETERNAL", 
        style: GoogleFonts.outfit(color: const Color(0xFF00FF88), fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 2),
      ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 3.seconds, color: Colors.white10);
    }

    String timeText = "";
    if (remaining.inDays >= 365) {
      timeText = "${(remaining.inDays / 365).ceil()}Y";
    } else if (remaining.inDays >= 7) {
      timeText = "${remaining.inDays}D";
    } else if (remaining.inHours >= 24) {
      timeText = "${remaining.inDays}D ${remaining.inHours % 24}H";
    } else if (remaining.inHours > 0) {
      timeText = "${remaining.inHours}H ${remaining.inMinutes % 60}M";
    } else {
      timeText = "${remaining.inMinutes}M";
    }

    final bool isUrgent = remaining.inHours == 0 && remaining.inMinutes < 30;
    Color timeColor = isUrgent ? const Color(0xFFFF00FF) : const Color(0xFFFF8700);

    return Text(
      '$timeText LEFT',
      style: GoogleFonts.outfit(color: timeColor, fontWeight: FontWeight.w800, fontSize: 9, letterSpacing: 1),
    ).animate(target: isUrgent ? 1 : 0).shakeX(hz: 5).shimmer(duration: 2.seconds, color: Colors.white10);
  }

  Future<void> _votePoll(String option) async {
    final uid = _currentUserUid;
    if (uid.isEmpty) return;

    try {
      final ref = FirebaseFirestore.instance.collection('wisprs').doc(widget.wispr.id);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(ref);
        if (!snapshot.exists) return;
        
        final data = snapshot.data()!;
        final bool allowMulti = data['allowMultipleVotes'] ?? false;
        final Map<String, List<String>> votedBy = (data['votedBy'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, List<String>.from(v))) ?? {};
        final Map<String, int> pollOptions = Map<String, int>.from(data['pollOptions'] ?? {});
        
        List<String> myVotes = votedBy[uid] ?? [];

        if (myVotes.contains(option)) {
          // Unvote
          myVotes.remove(option);
          pollOptions[option] = (pollOptions[option] ?? 1) - 1;
        } else {
          // Vote
          if (!allowMulti && myVotes.isNotEmpty) {
            // If not multi, remove old vote first
            final oldOption = myVotes.first;
            pollOptions[oldOption] = (pollOptions[oldOption] ?? 1) - 1;
            myVotes = [option];
          } else {
            myVotes.add(option);
          }
          pollOptions[option] = (pollOptions[option] ?? 0) + 1;
        }

        final int oldUniqueVoters = votedBy.length;
        votedBy[uid] = myVotes;
        final int newUniqueVoters = votedBy.length;
        
        // TIME RITUAL selection
        final currentExpiresAt = (data['expiresAt'] as Timestamp).toDate();
        DateTime newExpiresAt = currentExpiresAt;
        bool bonusAwarded = false;
        
        if (widget.wispr.isPoll) {
          // 5 VOTE BONUS LOGIC (Exclusive for polls as per request)
          // Every 5 unique voters gain 15 mins
          if (newUniqueVoters > oldUniqueVoters && newUniqueVoters % 5 == 0) {
            newExpiresAt = newExpiresAt.add(DecayService.getPollBonus());
            bonusAwarded = true;
          }
        } else {
          // Default interaction extension for regular wisprs
          newExpiresAt = DecayService.extendLife(currentExpiresAt, widget.wispr.type);
        }
        
        transaction.update(ref, {
          'pollOptions': pollOptions,
          'votedBy': votedBy,
          'expiresAt': Timestamp.fromDate(newExpiresAt),
        });

        if (bonusAwarded && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "SOUL ECHO: Poll extended by 15 minutes!",
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              backgroundColor: const Color(0xFFFF8700),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("VOICE LOST: Failed to cast vote."),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildGradientPoll(Map<String, int> options) {
    final int totalVotes = options.values.fold(0, (sum, val) => sum + val);
    final List<String> myVotes = widget.wispr.votedBy[_currentUserUid] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: options.entries.map((entry) {
        final double percentage = totalVotes == 0 ? 0 : entry.value / totalVotes;
        final bool isMyChoice = myVotes.contains(entry.key);
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: GestureDetector(
            onTap: () => _votePoll(entry.key),
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        if (isMyChoice)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(LucideIcons.checkCircle2, color: const Color(0xFF00FF88), size: 14),
                          ),
                        Text(
                          entry.key, 
                          style: GoogleFonts.inter(
                            color: isMyChoice ? const Color(0xFF00FF88) : Colors.white, 
                            fontSize: 14, 
                            fontWeight: isMyChoice ? FontWeight.w900 : FontWeight.w500
                          )
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text("${entry.value} votes", style: GoogleFonts.outfit(color: Colors.white12, fontSize: 10)),
                        const SizedBox(width: 8),
                        Text("${(percentage * 100).toInt()}%", style: GoogleFonts.outfit(color: isMyChoice ? const Color(0xFF00FF88) : Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Stack(
                  children: [
                    Container(width: double.infinity, height: 6, decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(3))),
                    FractionallySizedBox(
                      widthFactor: percentage,
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          gradient: LinearGradient(
                            colors: isMyChoice 
                                ? [const Color(0xFF00FF88), const Color(0xFF00FFEE)] 
                                : [const Color(0xFFFF8700), const Color(0xFFFF00FF)]
                          ),
                          boxShadow: isMyChoice ? [
                            BoxShadow(color: Color(0xFF00FF88).withOpacity(0.3), blurRadius: 10)
                          ] : [],
                        ),
                      ),
                    ).animate().scaleX(begin: 0, end: 1, duration: 800.ms, alignment: Alignment.centerLeft),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPinnedIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFF8700).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFF8700).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.pin, color: Color(0xFFFF8700), size: 10),
          const SizedBox(width: 6),
          Text(
            "ANCHORED",
            style: GoogleFonts.outfit(
              color: const Color(0xFFFF8700), 
              fontSize: 8, 
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds, color: Colors.white10);
  }

  Widget _buildInteractionButton(IconData icon, Color color, VoidCallback onTap) {
    final mode = GhostTheme.of(context)?.themeMode ?? AppThemeMode.ghosted;
    
    if (mode == AppThemeMode.comic) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2))],
          ),
          child: Icon(icon, color: Colors.black, size: 18),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap, 
      behavior: HitTestBehavior.opaque, 
      child: Icon(icon, color: color, size: 20),
    );
  }

  void _showXPPulse(BuildContext context, String text, Color color) {
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        left: offset.dx + 20,
        top: offset.dy - 20,
        child: Material(
          color: Colors.transparent,
          child: Text(
            text,
            style: DesignSystem.heading(context: context, color: color, size: 14),
          ).animate().fadeIn().moveY(begin: 0, end: -50, duration: 800.ms, curve: Curves.easeOutCubic).fadeOut(delay: 500.ms),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 1), () => entry.remove());
  }
}

class AnimatedCounter extends StatelessWidget {
  final int value;
  const AnimatedCounter({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 1000),
      builder: (context, val, child) => Text(val.toInt().toString(), style: GoogleFonts.inter(color: Colors.white38, fontSize: 13)),
    );
  }
}


