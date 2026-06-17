
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:ui';
import '../utils/design_system.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/thread_card.dart';
import '../models/wispr_model.dart';
import '../widgets/void_empty_state.dart';
import '../widgets/ghost_animation.dart';
import '../services/limit_service.dart';
import '../services/voice_service.dart';
import '../widgets/ghost_theme.dart';
import '../services/resonance_service.dart';
import '../services/daily_ritual_service.dart';
import '../services/compression_service.dart';
import '../services/cloudinary_service.dart';
import 'chat_inbox_screen.dart';
import 'activity_screen.dart';
import '../services/auth_service.dart';
import '../services/daily_ritual_service.dart';
import '../widgets/ghoul_icon.dart';

class GhostBoardScreen extends StatefulWidget {
  const GhostBoardScreen({super.key});

  @override
  State<GhostBoardScreen> createState() => _GhostBoardScreenState();
}

class _GhostBoardScreenState extends State<GhostBoardScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchMode = false;
  String _searchQuery = "";
  String _currentFilter = 'NEW';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = GhostTheme.of(context)?.themeMode ?? AppThemeMode.ghosted;
    final isComic = mode == AppThemeMode.comic;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('wisprs')
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        var docsList = snapshot.data?.docs.toList() ?? [];
        
        // Local Filter for Search
        if (_searchQuery.isNotEmpty) {
          docsList = docsList.where((d) {
            final text = (d.data() as Map<String, dynamic>)['text']?.toString().toLowerCase() ?? "";
            return text.contains(_searchQuery.toLowerCase());
          }).toList();
        }

        if (_currentFilter == 'TRENDING') {
           docsList.sort((a, b) {
             final aData = a.data() as Map<String, dynamic>;
             final bData = b.data() as Map<String, dynamic>;
             final aScore = (aData['resonance'] ?? 0) + (aData['replyCount'] ?? 0) * 5;
             final bScore = (bData['resonance'] ?? 0) + (bData['replyCount'] ?? 0) * 5;
             return bScore.compareTo(aScore);
           });
        } else if (_currentFilter == 'TOP') {
           docsList.sort((a, b) {
             final aData = a.data() as Map<String, dynamic>;
             final bData = b.data() as Map<String, dynamic>;
             final aRes = aData['resonance'] ?? 0;
             final bRes = bData['resonance'] ?? 0;
             return bRes.compareTo(aRes);
           });
        } else {
           // NEW (DEFAULT)
           docsList.sort((a, b) {
             final aData = a.data() as Map<String, dynamic>;
             final bData = b.data() as Map<String, dynamic>;
             final aPinned = aData['isPinned'] ?? false ? 1 : 0;
             final bPinned = bData['isPinned'] ?? false ? 1 : 0;
             if (aPinned != bPinned) return bPinned.compareTo(aPinned);
             final aTime = (aData['createdAt'] as Timestamp?)?.seconds ?? 0;
             final bTime = (bData['createdAt'] as Timestamp?)?.seconds ?? 0;
             return bTime.compareTo(aTime);
           });
        }

        final bool isEmpty = docsList.isEmpty && snapshot.connectionState != ConnectionState.waiting;

        final bool isBarrelRoll = _searchQuery.toLowerCase() == 'do a barrel roll';
        final bool isMatrixMode = _searchQuery.toLowerCase() == 'follow the white rabbit';

        Widget bodyContent = Stack(
            children: [
              if (isEmpty)
                Positioned.fill(
                  child: VoidEmptyState(message: _searchQuery.isEmpty ? "THE VOID IS SILENT... BE THE FIRST TO WHISPER" : "NO WHISPERS MATCH YOUR QUERY"),
                ),
              
              CustomScrollView(
                slivers: [
                  SliverAppBar(
                    backgroundColor: isComic ? DesignSystem.comicPaper : Colors.black.withOpacity(0.8),
                    elevation: 0,
                    floating: true,
                    snap: true,
                    expandedHeight: 80,
                    leading: _isSearchMode 
                      ? IconButton(
                          icon: Icon(LucideIcons.x, color: isComic ? DesignSystem.comicInk : Colors.white24, size: 20),
                          onPressed: () => setState(() {
                            _isSearchMode = false;
                            _searchQuery = "";
                            _searchController.clear();
                          }),
                        )
                      : IconButton(
                          icon: Icon(LucideIcons.menu, color: isComic ? DesignSystem.comicInk : Colors.white, size: 20),
                          onPressed: () => Scaffold.of(context).openDrawer(),
                        ),
                    title: _isSearchMode 
                      ? TextField(
                          controller: _searchController,
                          autofocus: true,
                          style: GoogleFonts.inter(color: isComic ? DesignSystem.comicInk : Colors.white, fontSize: 16),
                          textInputAction: TextInputAction.search,
                          onChanged: (val) => setState(() => _searchQuery = val),
                          onSubmitted: (val) => setState(() => _searchQuery = val),
                          decoration: InputDecoration(
                            hintText: "SEARCH THE VOID...",
                            hintStyle: GoogleFonts.inter(color: isComic ? Colors.black45 : Colors.white24, fontSize: 14),
                            border: InputBorder.none,
                          ),
                        )
                        : Row(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 2.0),
                                      child: DesignSystem.logo(context: context, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'THE VOID',
                                      style: isComic 
                                          ? GoogleFonts.bangers(fontSize: 26, color: DesignSystem.comicInk, letterSpacing: 2)
                                          : DesignSystem.heading(context: context, color: Colors.white, size: 18, letterSpacing: 4),
                                    ),
                                  ],
                                ),
                    actions: [
                      if (!_isSearchMode) ...[
                        _buildHeaderAction(LucideIcons.heart, isComic ? DesignSystem.comicInk : DesignSystem.voidMagenta, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ActivityScreen()))),
                        _buildHeaderAction(LucideIcons.wind, isComic ? DesignSystem.comicInk : DesignSystem.ghostOrange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatInboxScreen()))),
                      ],
                      IconButton(
                        icon: Icon(
                          _isSearchMode ? LucideIcons.x : LucideIcons.search, 
                          color: _isSearchMode ? DesignSystem.ghostOrange : (isComic ? DesignSystem.comicInk : Colors.white), 
                          size: 20
                        ),
                        onPressed: () {
                          setState(() {
                            if (_isSearchMode) {
                              _searchQuery = "";
                              _searchController.clear();
                            }
                            _isSearchMode = !_isSearchMode;
                          });
                        },
                      ),
                    ],
                  ),


                  if (snapshot.hasError)
                    SliverFillRemaining(
                      child: Center(
                        child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)),
                      ),
                    )
                  else if (snapshot.connectionState == ConnectionState.waiting)
                    const SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(color: Color(0xFFFF8700)),
                      ),
                    )
                  else if (docsList.isNotEmpty) ...[
                    SliverToBoxAdapter(child: _buildDailyRitual()),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            _buildFilterChip('NEW'),
                            const SizedBox(width: 8),
                            _buildFilterChip('TRENDING'),
                            const SizedBox(width: 8),
                            _buildFilterChip('TOP'),
                          ],
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    SliverPadding(
                      padding: const EdgeInsets.only(top: 10, bottom: 140),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final wispr = Wispr.fromDocument(docsList[index]);
                            final bool isExpired = wispr.expiresAt.isBefore(DateTime.now());
                            if (wispr.currentOpacity <= 0 || isExpired) return const SizedBox.shrink(); 
                            return ThreadCard(wispr: wispr);
                          },
                          childCount: docsList.length,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          );

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: DesignSystem.responsiveWidth(
            child: isBarrelRoll
                ? bodyContent.animate(onPlay: (c) => c.repeat()).rotate(duration: 2.seconds, curve: Curves.easeInOut)
                : isMatrixMode
                    ? bodyContent.animate(onPlay: (c) => c.repeat())
                        .shimmer(duration: 1.seconds, color: Colors.greenAccent.withOpacity(0.1))
                        .tint(color: Colors.greenAccent.withOpacity(0.2))
                    : bodyContent,
          ),
        );
      },
    );
  }

  Widget _buildHeaderAction(IconData icon, Color color, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, color: color, size: 20),
      onPressed: onTap,
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _currentFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _currentFilter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF8700) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.white.withOpacity(0.3) : Colors.transparent),
          boxShadow: isSelected ? [
            BoxShadow(color: const Color(0xFFFF8700).withOpacity(0.3), blurRadius: 10)
          ] : [],
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            color: isSelected ? Colors.black : Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildDailyRitual() {
    return StreamBuilder<DocumentSnapshot>(
      stream: DailyRitualService.getTodayRitual(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final actions = Map<String, int>.from(data['actions'] ?? {});
        final completed = data['completed'] ?? false;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: DesignSystem.glass(context: context, opacity: 0.1, radius: 20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: completed ? DesignSystem.spectralGreen.withOpacity(0.2) : DesignSystem.ghostOrange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  completed ? LucideIcons.checkCircle : LucideIcons.flame,
                  color: completed ? DesignSystem.spectralGreen : DesignSystem.ghostOrange,
                  size: 20,
                ),
              ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 3.seconds),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      completed ? "RITUAL SUSTAINED" : "DAILY RITUAL",
                      style: DesignSystem.sub(color: Colors.white, size: 10),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      completed ? "Your spirit is strong today." : "Whisper once or manifest 3 echoes to sustain your spirit.",
                      style: DesignSystem.body(context: context, color: Colors.white60, size: 11),
                    ),
                  ],
                ),
              ),
              if (!completed)
                Text(
                  "${actions['post'] ?? 0}/1",
                  style: DesignSystem.heading(context: context, color: DesignSystem.ghostOrange, size: 14),
                ),
            ],
          ),
        ).animate().fadeIn().slideX(begin: -0.1, end: 0);
      },
    );
  }



  void _showCreatePostSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateWisprSheet(),
    );
  }
}

class CreateWisprSheet extends StatefulWidget {
  CreateWisprSheet({super.key});

  @override
  State<CreateWisprSheet> createState() => _CreateWisprSheetState();
}

class _CreateWisprSheetState extends State<CreateWisprSheet> {
  final _titleController = TextEditingController();
  final _controller = TextEditingController();
  bool _isPoll = false;
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  bool _isLoading = false;
  bool _isRecording = false;
  String? _selectedMedia;
  WisprType _selectedType = WisprType.text;
  String? _mediaMimeType;
  bool _allowMultipleVotes = false;
  double _uploadProgress = 0.0;
  Uint8List? _localPreviewBytes; // FOR IMMEDIATE FEEDBACK
  bool _showTimerOptions = false;

  // Oracle Super-Powers removed
  final bool _isPinned = false;
  final List<String> _stickers = [
    'ðŸ”¥', 'ðŸ‘»', 'ðŸ’€', 'ðŸ‘½', 'ðŸ’«', 'âš¡', 'ðŸŒŒ', 'ðŸ§¬', 'ðŸ–¤', 'ðŸ‘ï¸', 
    'ðŸ§¿', 'ðŸ”®', 'ðŸ•¸ï¸', 'ðŸ¥€', 'ðŸ¦´', 'ðŸ—¡ï¸', 'â›“ï¸', 'ðŸ©¸', 'ðŸ’Š', 'ðŸ·',
    'ðŸ§›', 'ðŸ¦‡', 'ðŸ•·ï¸', 'ðŸ•¯ï¸', 'ðŸ—ï¸', 'ðŸ“œ', 'ðŸ—ºï¸', 'ðŸ“»', 'ðŸ“½ï¸', 'ðŸ“º', 
    'ðŸ“¼', 'ðŸ’¿', 'ðŸ’»', 'ðŸ›¸', 'ðŸ‘¾', 'ðŸ¤–', 'ðŸ›°ï¸', 'ðŸ§ª', 'ðŸ§¬', 'ðŸ§¨',
    'ðŸŽ­', 'ðŸŽ¡', 'ðŸŽ°', 'ðŸ§¤', 'ðŸ”­', 'ðŸ§ª', 'ðŸŒªï¸', 'ðŸŒ‘', 'ðŸ•¯ï¸', 'ðŸ¹'
  ];
  final List<String> _curatedGifs = [
    'https://media.giphy.com/media/iWl8DC1VSKLbGE0SL6/giphy.gif', // Glitch Ghost
    'https://media.giphy.com/media/CNYthy0xyjXDW/giphy.gif', // Static Ghost
    'https://media.giphy.com/media/l0MYSgw9ol1zwkuQM/giphy.gif', // Glitch Screen
    'https://media.giphy.com/media/XhT868oxljs88/giphy.gif', // Static Noise
    'https://media.giphy.com/media/znFOMXuHVkV36qzdbJ/giphy.gif', // Matrix Code
    'https://media.giphy.com/media/CW16nFVXLSQxSMUEMd/giphy.gif', // Vaporwave
    'https://media.giphy.com/media/3oKIPc8HP4TjyykkKc/giphy.gif', // Neon Glitch
    'https://media.giphy.com/media/ToMjGpxnvD5VZPPFamY/giphy.gif', // Spooky Ghost
    'https://media.giphy.com/media/hkqefnFjn2MWVl6xvq/giphy.gif', // Cyber Glitch
    'https://media.giphy.com/media/7V8fLwptAT3iBFlEX5/giphy.gif', // Abstract Glitch
    'https://media.giphy.com/media/IMOTcqOtaEkXiBonLU/giphy.gif', // Cyberpunk
    'https://media.giphy.com/media/9zExs2Q2h1EHfE4P6G/giphy.gif', // Digital Rain
    'https://media.giphy.com/media/XbV2mrHs6ureBPUEuJ/giphy.gif', // Vapor Wave
    'https://media.giphy.com/media/hhbsgAvBkZqkKx2ys7/giphy.gif', // TV Static
    'https://media.giphy.com/media/10zxDv7Hv5RF9C/giphy.gif', // Matrix Green
    'https://media.giphy.com/media/wwg1suUiTbCY8H8vIA/giphy.gif', // Code Stream
    'https://media.giphy.com/media/ZnYDpTpDKrhf4RwQ7R/giphy.gif', // Neon Pulse
    'https://media.giphy.com/media/h1Ush3EUn6uJq/giphy.gif', // Glitch Heart
    'https://media.giphy.com/media/kMWgszjTkGoNfnP8IQ/giphy.gif', // Ghostly
    'https://media.giphy.com/media/go3pCPP4899Jd3xb4p/giphy.gif', // Specter
    'https://media.giphy.com/media/j3mdQpQ9SKxFOWs9gy/giphy.gif', // Glitch City
    'https://media.giphy.com/media/3oKIPlCroSFHV8uoko/giphy.gif', // Data Mesh
    'https://media.giphy.com/media/QTxF50wnvVaXDU3IJQ/giphy.gif', // Circuit Pulse
    'https://media.giphy.com/media/YRcXl6VfNhCorklI0R/giphy.gif', // Noise Static
    'https://media.giphy.com/media/5ECm9620VUe0Uoq57j/giphy.gif', // TV Snow
    'https://media.giphy.com/media/A06UFEx8jxEwU/giphy.gif', // Falling Code
    'https://media.giphy.com/media/fS9PCxQYG0ULu/giphy.gif', // Digit Stream
    'https://media.giphy.com/media/gY8Bs8qvD1EukQBj5V/giphy.gif', // Aesthetic Glitch
    'https://media.giphy.com/media/xT0xenzeRNx6MpGmmk/giphy.gif', // Retro Glitch
    'https://media.giphy.com/media/dsQtBSAeCsHsACriCs/giphy.gif', // Lo-fi Glitch
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _controller.dispose();
    for (var c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_optionControllers.length < 4) {
      setState(() => _optionControllers.add(TextEditingController()));
    }
  }

  Widget _buildActionButton(IconData icon, String label, bool isSelected, {bool isDanger = false}) {
    final mode = GhostTheme.of(context)?.themeMode ?? AppThemeMode.ghosted;
    final themeColor = DesignSystem.getThemeColor(mode);
    final activeColor = isDanger ? Colors.redAccent : themeColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? activeColor.withOpacity(0.1) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? activeColor.withOpacity(0.3) : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isSelected ? activeColor : Colors.white24),
          const SizedBox(width: 8),
          Text(
            label, 
            style: GoogleFonts.outfit(
              color: isSelected ? Colors.white : Colors.white24,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            )
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F).withOpacity(0.95),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(40),
          topRight: Radius.circular(40),
        ),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40, offset: const Offset(0, -10)),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(40), topRight: Radius.circular(40)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: _buildSheetContent(context),
        ),
      ),
    );
  }

  Widget _buildSheetContent(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'WISPR TO THE VOID',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 1.5,
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, color: Colors.white24, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              maxLength: 60,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: "Headline (Optional)",
                hintStyle: GoogleFonts.outfit(color: Colors.white24),
                border: InputBorder.none,
                counterStyle: const TextStyle(height: 0, color: Colors.transparent), // Hide counter
              ),
            ),
            Divider(color: Colors.white.withOpacity(0.05)),
            TextField(
              controller: _controller,
              maxLength: LimitService.REGULAR_CHAR_LIMIT,
              maxLines: 4,
              autofocus: true,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 16, height: 1.5),
              decoration: InputDecoration(
                hintText: _isPoll ? "What is your question?" : "What's on your mind?",
                hintStyle: GoogleFonts.inter(color: Colors.white12),
                border: InputBorder.none,
                counterStyle: const TextStyle(color: Colors.white24, fontSize: 10),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _isPoll = !_isPoll),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isPoll ? Color(0xFFFF8700).withOpacity(0.1) : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isPoll ? Color(0xFFFF8700).withOpacity(0.3) : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.barChart2, 
                          size: 14, 
                          color: _isPoll ? const Color(0xFFFF8700) : Colors.white38
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "POLL", 
                          style: GoogleFonts.outfit(
                            color: _isPoll ? const Color(0xFFFF8700) : Colors.white38,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          )
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_isPoll)
                  GestureDetector(
                    onTap: () => setState(() => _allowMultipleVotes = !_allowMultipleVotes),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _allowMultipleVotes ? Color(0xFF00FF88).withOpacity(0.1) : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _allowMultipleVotes ? Color(0xFF00FF88).withOpacity(0.3) : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.checkSquare, 
                            size: 14, 
                            color: _allowMultipleVotes ? const Color(0xFF00FF88) : Colors.white12
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "MULTI", 
                            style: GoogleFonts.outfit(
                              color: _allowMultipleVotes ? const Color(0xFF00FF88) : Colors.white38,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            )
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _pickMedia(false), // Photo
                  child: _buildActionButton(
                    LucideIcons.image, 
                    "PHOTO", 
                    (_selectedType == WisprType.image || _selectedType == WisprType.gif)
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _pickMedia(true), // Video
                  child: _buildActionButton(
                    LucideIcons.video, 
                    "CLIP", 
                    (_selectedType == WisprType.reel)
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    if (_isRecording) {
                      _stopRecording();
                    } else {
                      _showVoiceSourceOptions(context);
                    }
                  },
                  child: _buildActionButton(
                    LucideIcons.mic, 
                    _isRecording ? "HOLDING..." : "VOICE", 
                    _isRecording,
                    isDanger: _isRecording
                  ),
                ),

              ],
            ),

            if (_selectedMedia != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: 100,
                        width: 100,
                        color: Colors.white.withOpacity(0.05),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            _selectedType == WisprType.voice
                              ? const Icon(LucideIcons.mic, color: Colors.redAccent, size: 32)
                              : _selectedType == WisprType.reel
                                ? const Icon(LucideIcons.video, color: Color(0xFFFF00FF), size: 32)
                                : _selectedMedia != null
                                  ? Image.network(
                                      _selectedMedia!, 
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => const Icon(LucideIcons.alertTriangle, color: Colors.redAccent, size: 24),
                                    )
                                  : _localPreviewBytes != null
                                    ? Image.memory(_localPreviewBytes!, fit: BoxFit.cover)
                                    : const Icon(LucideIcons.image, color: Colors.white10),
                            if (_isLoading)
                              Container(
                                color: Colors.black45,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(
                                        value: _uploadProgress > 0 ? _uploadProgress : null,
                                        color: const Color(0xFFFF8700),
                                        strokeWidth: 2,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _uploadProgress > 0 ? "${(_uploadProgress * 100).toInt()}%" : "BINDING...",
                                        style: GoogleFonts.outfit(color: const Color(0xFFFF8700), fontSize: 8, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _selectedMedia = null;
                          _mediaMimeType = null;
                          _localPreviewBytes = null;
                          _selectedType = WisprType.text;
                        }),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(LucideIcons.x, color: Colors.white, size: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_isPoll) ...[
              const SizedBox(height: 24),
              ..._optionControllers.asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: entry.value,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: "Option ${entry.key + 1}",
                      hintStyle: GoogleFonts.inter(color: Colors.white12),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.02),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                );
              }),
              if (_optionControllers.length < 4)
                TextButton.icon(
                  onPressed: _addOption,
                  icon: const Icon(LucideIcons.plus, size: 14, color: Color(0xFFFF8700)),
                  label: Text("ADD OPTION", style: GoogleFonts.outfit(color: const Color(0xFFFF8700), fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
            const SizedBox(height: 32),
            GestureDetector(
              onTap: _isLoading ? null : _handlePublish,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF8700), Color(0xFFFF4E00)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFFFF8700).withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                alignment: Alignment.center,
                child: _isLoading 
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 200,
                          child: LinearProgressIndicator(
                            value: _uploadProgress > 0 ? _uploadProgress : null,
                            backgroundColor: Colors.black26,
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _uploadProgress > 0 
                            ? "${(_uploadProgress * 100).toInt()}% MANIFESTING..." 
                            : "WELCOME BACK, SPIRIT",
                          style: GoogleFonts.outfit(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    )
                  : Text(
                      'PUBLISH WISPR',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: 1),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _pickMedia(bool isVideo) async {
    final picker = ImagePicker();
    XFile? file;
    
    if (isVideo) {
      file = await picker.pickVideo(
        source: ImageSource.gallery, 
        maxDuration: const Duration(seconds: 10),
      );
    } else {
      file = await picker.pickImage(
        source: ImageSource.gallery, 
        imageQuality: 40, // Aggressive compression for speed
        maxWidth: 1080,
        maxHeight: 1080,
      );
    }
    
    if (file != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("SPIRIT CAPTURED. GHOST LOGIN..."), 
            backgroundColor: Colors.white12, 
            duration: Duration(seconds: 1)
          ),
        );
      }
      
      try {
        final String name = file.name.toLowerCase();
        final String ext = name.split('.').last;
        final String mime;
        if (isVideo) {
          mime = 'video/mp4';
        } else if (ext == 'gif') {
          mime = 'image/gif';
        } else if (ext == 'png') {
          mime = 'image/png';
        } else {
          mime = 'image/jpeg';
        }
        
        // IMMEDIATE LOCAL PREVIEW
        final lb = await file.readAsBytes();
        if (mounted) {
          setState(() {
            _isLoading = true;
            _localPreviewBytes = lb;
            _selectedType = isVideo ? WisprType.reel : WisprType.image;
            _uploadProgress = 0.0;
          });
        }

        // IMMUTABLE CLOUD UPLOAD
        print("GhostBoard: Starting Cloudinary upload...");
        final String folder = isVideo ? 'wispr_reels' : 'wispr_images';
        
        final oldMediaUrl = _selectedMedia;

        final url = await CloudinaryService.uploadMedia(lb, folder, isVideo: isVideo).timeout(
          const Duration(seconds: 120),
          onTimeout: () => throw Exception("THE VOID IS CONGESTED (120s Timeout)"),
        );

        // Cleanup old media if replaced before publishing
        if (oldMediaUrl != null && oldMediaUrl.isNotEmpty) {
          CloudinaryService.deleteMedia(oldMediaUrl);
        }

        print("GhostBoard: Upload success. URL: $url");
        
        if (mounted) {
          setState(() {
            _selectedMedia = url;
            _selectedType = isVideo ? WisprType.reel : WisprType.image;
            _mediaMimeType = mime;
            _uploadProgress = 1.0;
          });
        }
      } catch (e) {
        print("UPLOAD ERROR in GhostBoard: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("THE VOID REJECTED YOUR MEDIA: $e"), backgroundColor: Colors.redAccent, duration: const Duration(seconds: 5)),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _startRecording() async {
    try {
      print("GhostBoard: Attempting to start recording...");
      await VoiceService.startRecording();
      if (mounted) setState(() => _isRecording = true);
    } catch (e) {
      print("GhostBoard Recording ERROR: $e");
      if (mounted) {
        setState(() => _isRecording = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("VOICE RITUAL FAILED: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _stopRecording() async {
    if (!_isRecording) return;
    
    setState(() {
      _isRecording = false;
      _isLoading = true;
      _uploadProgress = 0.0;
      _selectedType = WisprType.voice; // Instant feedback: Show Mic icon
    });
    
    try {
      final url = await VoiceService.stopAndUpload(
        onProgress: (p) {
          if (mounted) setState(() => _uploadProgress = p);
        },
      );
      if (url != null && mounted) {
        setState(() {
          _selectedMedia = url;
          _selectedType = WisprType.voice;
          _mediaMimeType = 'audio/mp4'; // Use consistent mp4 mime for m4a
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("VOICE RITUAL SILENCED: The upload failed to return a URL."), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Voice upload failed: $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showVoiceSourceOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("SPIRITUAL VOICE", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(LucideIcons.mic, color: Color(0xFFFF8700)),
              title: Text("START RECORDING", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
              onTap: () { Navigator.pop(c); _startRecording(); },
            ),
            ListTile(
              leading: const Icon(LucideIcons.upload, color: Color(0xFFFF8700)),
              title: Text("UPLOAD VOICE FILE", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
              onTap: () { Navigator.pop(c); _pickVoiceFile(); },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickVoiceFile() async {
    try {
      print("GhostBoard: Opening FilePicker for Audio...");
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'wav', 'ogg', 'aac', 'flac'],
        allowMultiple: false,
        withData: true, // Required for Web
      );

      if (result != null && result.files.isNotEmpty) {
        final platformFile = result.files.single;
        Uint8List? bytes = platformFile.bytes;
        
        // Web-optimized: Bytes are already provided by FilePicker result with withData: true
        if (bytes == null) {
          throw Exception("Could not retrieve file bytes. Ensure you have selected a valid file.");
        }

        if (bytes == null || bytes.isEmpty) {
          throw Exception("The picked file is empty or inaccessible.");
        }

        print("GhostBoard: Captured ${bytes.length} bytes for audio upload.");
        
        setState(() {
          _isLoading = true;
          _uploadProgress = 0.1; // Start progress
          _selectedType = WisprType.voice;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("VOICE SECURED. BINDING TO THE VOID..."), backgroundColor: Colors.white12)
          );
        }

        final url = await CloudinaryService.uploadMedia(bytes, 'wispr_voice').timeout(
          const Duration(seconds: 120),
          onTimeout: () => throw Exception("THE VOID IS CONGESTED (120s Timeout)"),
        );

        if (mounted) {
          setState(() {
            _selectedMedia = url;
            _selectedType = WisprType.voice;
            _mediaMimeType = 'audio/mpeg'; 
            _uploadProgress = 1.0;
          });
          print("GhostBoard: Audio upload successful: $url");
        }
      } else {
        print("GhostBoard: File picker cancelled or returned no result.");
      }
    } catch (e) {
      print("AUDIO PICK/UPLOAD ERROR: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("THE VOID REJECTED YOUR VOICE FILE: $e"), 
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMediaPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context2) => Container(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () { Navigator.pop(context2); _pickMedia(false); },
                    icon: const Icon(LucideIcons.image, size: 14, color: Color(0xFFFF00FF)),
                    label: Text("PHOTO", style: GoogleFonts.outfit(color: const Color(0xFFFF00FF), fontWeight: FontWeight.bold, fontSize: 10)),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () { Navigator.pop(context2); _pickMedia(true); },
                    icon: const Icon(LucideIcons.video, size: 14, color: Color(0xFFFF00FF)),
                    label: Text("10s REEL", style: GoogleFonts.outfit(color: const Color(0xFFFF00FF), fontWeight: FontWeight.bold, fontSize: 10)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text("OR PICK A MEME", style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 16),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _curatedGifs.length,
                  itemBuilder: (context, index) => GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedMedia = _curatedGifs[index];
                        _selectedType = WisprType.image;
                      });
                      Navigator.pop(context2);
                    },
                    child: Container(
                      width: 120,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Image.network(
                        _curatedGifs[index],
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) {
                          print("GIF PREVIEW ERROR: $e");
                          return const Center(child: Icon(LucideIcons.imageOff, color: Colors.white24));
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text("QUICK STICKERS", style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 16),
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _stickers.length,
                  itemBuilder: (context, index) => GestureDetector(
                    onTap: () {
                      _controller.text += _stickers[index];
                      Navigator.pop(context2);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      child: Text(_stickers[index], style: const TextStyle(fontSize: 24, fontStyle: FontStyle.normal)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handlePublish() async {
    if (_isLoading) return;
    String text = _controller.text.trim();
    if (text.isEmpty) return;

    String? element;
    if (text.toLowerCase().contains('/fire')) {
      element = 'fire';
      text = text.replaceAll(RegExp(r'/fire', caseSensitive: false), '').trim();
    } else if (text.toLowerCase().contains('/water')) {
      element = 'water';
      text = text.replaceAll(RegExp(r'/water', caseSensitive: false), '').trim();
    }

    if (_isPoll) {
      final validOptions = _optionControllers.where((c) => c.text.trim().isNotEmpty).toList();
      if (validOptions.length < 2) return;
    }

    setState(() => _isLoading = true);
    final now = DateTime.now();
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("YOU ARE A SHADOW... LOGIN TO WHISPER"), backgroundColor: Colors.redAccent)
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    // Archive Gating Snackbars Removed per User Request (Access is now open)


    try {
      // Dynamic Post Limit Check
      final canPostResult = await LimitService.canPost();
      if (!canPostResult) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("VOICE OVERLOAD: THE VOID IS CONGESTED. LIMIT REACHED."), 
              backgroundColor: Colors.redAccent,
              duration: Duration(seconds: 4),
            )
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final Map<String, int>? pollOptions = _isPoll 
        ? { for (var c in _optionControllers.where((c) => c.text.trim().isNotEmpty)) c.text.trim() : 0 }
        : null;

      int durationHours = 4;
      if (_selectedType == WisprType.reel || _selectedType == WisprType.voice) {
        durationHours = 1;
      } else if (_selectedType == WisprType.image) {
        durationHours = 2;
      }

      final wispr = Wispr(
        id: '',
        title: _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : null,
        text: text,
        createdAt: now,
        expiresAt: now.add(Duration(hours: durationHours)),
        replyCount: 0,
        isPoll: _isPoll,
        pollOptions: pollOptions,
        authorId: uid,
        mediaUrl: _selectedMedia,
        mediaType: _mediaMimeType,
        type: _selectedMedia != null ? _selectedType : WisprType.text,
        allowMultipleVotes: _isPoll ? _allowMultipleVotes : false,
        votedBy: {},
        element: element,
        isPinned: _isPinned,
      );

      final data = wispr.toMap();



      print("PUBLISHING WISPR: $data");
      await FirebaseFirestore.instance.collection('wisprs').add(data);
      print("PUBLISH SUCCESS");
      
      // Increment daily post count for limit tracking
      await LimitService.incrementPostCount();
      


      // TRACK ACTION & REWARDS
      DailyRitualService.trackAction('post');
      ResonanceService.gainResonance(ResonanceService.XP_PER_POST);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      print("PUBLISH ERROR: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("THE VOID REJECTED YOUR WHISPER: $e"), backgroundColor: Colors.redAccent)
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

}

