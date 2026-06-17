import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/limit_service.dart';
import '../widgets/void_empty_state.dart';
import 'direct_chat_screen.dart';
import '../services/auth_service.dart';
import '../utils/design_system.dart';
import '../widgets/ghost_theme.dart';
import '../widgets/ghoul_icon.dart';
import '../layout/app_layout.dart';
import 'settings_screen.dart';

class SwipeDeckScreen extends StatefulWidget {
  const SwipeDeckScreen({super.key});

  @override
  State<SwipeDeckScreen> createState() => _SwipeDeckScreenState();
}

class _SwipeDeckScreenState extends State<SwipeDeckScreen> {
  final CardSwiperController controller = CardSwiperController();
  List<QueryDocumentSnapshot> _users = [];
  bool _isLoadingUsers = true;
  int _deckIndex = 0;
  UserModel? _currentUser;

  // List of 250+ categorized tags/interests
  final List<String> _availableTags = [
    // Tech & Coding
    "Coding", "Hackathons", "Web3", "AI & ML", "Data Science", "Cybersecurity",
    "Flutter", "React", "Python", "Rust", "C++", "Java", "Neovim", "Svelte", 
    "Next.js", "Docker", "Kubernetes", "TailwindCSS", "Leetcode Grind", 
    "Competitive Programming", "System Design", "Web Scraping", "API Development", 
    "TypeScript", "Go / Golang", "Kotlin", "Swift", "Machine Learning", 
    "Deep Learning", "Generative AI", "NLP", "Robotics", "IoT", "AR & VR",
    
    // Slang & Slang Culture
    "Rizz", "Skibidi", "No Cap", "Bussin", "Doomscrolling", "Glow Up", "Slay", 
    "Main Character Energy", "Simping", "Gatekeeping", "Vibe Check", "Era of Me",
    "Era of Peace", "Gamer Mode", "Maining", "Ghosting", "Spamming",
    
    // University Life & Pain Points
    "Proxy", "Mass Bunk", "Midnight Canteen", "Assignment Panic", "Backbenchers", 
    "CR Responsibilities", "Viva Horror", "Club Recruiting", "Internship Hunt", 
    "GPA Grind", "Coffee Addict", "All-Nighter", "Chai tapri", "Hostel Life", 
    "Exams Panic", "Library Naps", "Placement Stress", "Semester End",
    
    // Gaming & E-Sports
    "Gaming", "BGMI", "Valorant", "FIFA Pro", "CS2", "Cricket", "F1 Fantasy", 
    "Chess Speedruns", "Genshin Impact", "Minecraft", "E-Sports", "Steam Deck", 
    "Nintendo Switch", "League of Legends", "Dota 2", "Among Us", "Indie Games",
    
    // Sports & Fitness
    "Gym", "Powerlifting", "Calisthenics", "Football", "Basketball", "Tennis",
    "Pickleball", "Badminton", "Table Tennis", "Bouldering", "Running", "Swimming",
    "Cycling", "Yoga", "Pilates", "Marathons",
    
    // Music
    "Pop Music", "Rock", "Metal", "Hip Hop", "Lo-Fi", "Classical", "Jazz",
    "Desi Hip Hop", "Bollywood Retro", "Indie Rock", "Taylor Swift", "K-Pop", 
    "DJing", "Guitarist", "Drummer", "EDM", "Techno", "House Music", "R&B",
    
    // Pop Culture & Media
    "Anime", "Marvel", "DC Comics", "Sci-Fi", "Fantasy", "Movies", "TV Shows", 
    "K-Dramas", "Documentaries", "Horror Movies", "Comedy", "Standup Comedy", 
    "Manga", "Manhwa", "History", "Philosophy", "Psychology", "True Crime", 
    "Podcast Binging", "Netflix & Chill",
    
    // Food & Drinks
    "Cooking", "Baking", "Coffee Brewing", "Tea Tasting", "Wine Selection", "Foodie",
    "Boba Tea", "Biryani Lover", "Maggi", "Cold Brew", "Vegan", "Matcha Latte", 
    "Street Food", "Spicy Food", "Brunching", "Desserts",
    
    // Arts & Creative
    "Photography", "Videography", "Graphic Design", "UI/UX", "VFX", "Digital Art",
    "Doodling", "Sketching", "Cosplay Crafting", "Pottery", "Calligraphy", "UI Design",
    
    // Finance & Business
    "Stocks", "Crypto", "Startups", "E-commerce", "SaaS", "Real Estate", 
    "Investing", "Personal Finance", "Side Hustle", "Trading",
    
    // Travel & Outdoors
    "Traveling", "Backpacking", "Solo Trips", "Camping", "Hiking", "Mountain Climbing",
    "Road Trips", "Beach Lover", "Stargazing", "Wanderlust",
    
    // Science & Mind
    "Astronomy", "Physics", "Chemistry", "Biology", "Mathematics", "Quantum Physics",
    
    // Vibes & Personality
    "Chess", "Board Games", "D&D", "Magic: The Gathering", "Rubik's Cube", "Puzzles",
    "Mental Health", "Self Improvement", "Mindfulness", "Meditation", "Sleep Schedule",
    "Fashion", "Sneakers", "Streetwear", "Thrifting", "Vintage", "Cosplay",
    "Mercury Retrograde", "Manifesting", "Tarot Reading", "Spiritual Healing", 
    "Introvert Vibe", "Extrovert Vibe", "Ambivert", "INTJ", "ENFP", "INFJ", "ENTP"
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  List<DocumentSnapshot> _pendingRequests = []; // Users who swiped right on me
  int _pendingIndex = 0;
  bool _showingPending = false;


  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingUsers = true;
      _deckIndex = 0;
      _pendingIndex = 0;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 1. Get current user profile
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        _currentUser = UserModel.fromDocument(doc);
      }

      // 2. Fetch swiped users to exclude (users I already responded to)
      final swipedSnap = await FirebaseFirestore.instance
          .collection('swipes')
          .where('ownerId', isEqualTo: user.uid)
          .get();

      final swipedIds = swipedSnap.docs.map((d) => d.data()['targetId']?.toString()).whereType<String>().toSet();

      // 3. Fetch incoming right swipes (friend requests sent TO me that I haven't responded to)
      final incomingSwipesSnap = await FirebaseFirestore.instance
          .collection('swipes')
          .where('targetId', isEqualTo: user.uid)
          .where('type', isEqualTo: 'right')
          .get();

      final incomingFromIds = incomingSwipesSnap.docs
          .map((d) => d.data()['ownerId']?.toString())
          .whereType<String>()
          .where((id) => !swipedIds.contains(id) && id != user.uid) // Filter already responded
          .toList();

      // Fetch pending request user profiles
      final pendingDocs = <DocumentSnapshot>[];
      for (final id in incomingFromIds) {
        try {
          final uDoc = await FirebaseFirestore.instance.collection('users').doc(id).get();
          if (uDoc.exists) pendingDocs.add(uDoc);
        } catch (_) {}
      }

      // 4. Fetch potential new matches from archives
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('joinedArchives', isEqualTo: true)
          .limit(200)
          .get();

      _users = snap.docs.where((doc) {
        final uid = doc.id;
        if (uid == user.uid) return false;
        if (swipedIds.contains(uid)) return false;
        if (incomingFromIds.contains(uid)) return false; // Already in pending
        return true;
      }).toList();

      // 5. Sort suggestions based on tag matching count (overlap with current user's tags)
      if (_currentUser != null && _currentUser!.tags.isNotEmpty) {
        final myTags = _currentUser!.tags.toSet();
        final mySemester = _currentUser!.semester;
        
        _users.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTags = List<String>.from(aData['tags'] ?? []).toSet();
          final bTags = List<String>.from(bData['tags'] ?? []).toSet();

          final aOverlap = aTags.intersection(myTags).length;
          final bOverlap = bTags.intersection(myTags).length;
          
          // Secondary sort: same semester proximity
          int semBonus(Map data) {
            if (mySemester == null || mySemester.isEmpty) return 0;
            return (data['semester']?.toString() == mySemester) ? 1 : 0;
          }

          final aScore = aOverlap * 2 + semBonus(aData);
          final bScore = bOverlap * 2 + semBonus(bData);
          return bScore.compareTo(aScore);
        });
      }

      // Store pending requests separately
      _pendingRequests = pendingDocs;

    } catch (e) {
      debugPrint("Seance Load Error: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoadingUsers = false);
      }
    }
  }

  Future<List<UserModel>> _fetchUsers(List<String> uids) async {
    if (uids.isEmpty) return [];
    final list = <UserModel>[];
    for (final uid in uids.take(20)) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists) {
          list.add(UserModel.fromDocument(doc));
        }
      } catch (e) {
        debugPrint("Error fetching user $uid: $e");
      }
    }
    return list;
  }

  void _showTagSelectionDialog() {
    List<String> selectedTags = List<String>.from(_currentUser?.tags ?? []);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F0F0F),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Colors.white10)),
              title: Text(
                "SELECT INTEREST TAGS (${selectedTags.length}/20)",
                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableTags.map((tag) {
                      final isSelected = selectedTags.contains(tag);
                      return GestureDetector(
                        onTap: () {
                          setModalState(() {
                            if (isSelected) {
                              selectedTags.remove(tag);
                            } else if (selectedTags.length < 20) {
                              selectedTags.add(tag);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFFF8700).withOpacity(0.2) : Colors.white.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isSelected ? const Color(0xFFFF8700) : Colors.white10),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(color: isSelected ? const Color(0xFFFF8700) : Colors.white70, fontSize: 12),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("CANCEL", style: TextStyle(color: Colors.white38)),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    if (uid != null) {
                      await FirebaseFirestore.instance.collection('users').doc(uid).update({
                        'tags': selectedTags,
                      });
                      _loadData();
                    }
                  },
                  child: const Text("SAVE TAGS", style: TextStyle(color: Color(0xFFFF8700))),
                ),
              ],
            );
          },
        );
      },
    );
  }

  bool _onSwipe(int previousIndex, int? currentIndex, CardSwiperDirection direction) {
    if (previousIndex >= _users.length) return true;

    if (currentIndex != null) {
      setState(() => _deckIndex = currentIndex);
    } else {
      setState(() => _deckIndex = _users.length);
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return true;

    final targetUid = _users[previousIndex].id;
    final isRightSwipe = direction == CardSwiperDirection.right;

    LimitService.incrementSwipe();

    // Persist Swipe
    final swipeId = "${currentUser.uid}_$targetUid";
    FirebaseFirestore.instance.collection('swipes').doc(swipeId).set({
      'ownerId': currentUser.uid,
      'targetId': targetUid,
      'type': isRightSwipe ? 'right' : 'left',
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (isRightSwipe) {
      // Check for mutual right swipe
      final inverseSwipeId = "${targetUid}_${currentUser.uid}";
      FirebaseFirestore.instance.collection('swipes').doc(inverseSwipeId).get().then((doc) async {
        if (doc.exists && doc.data()?['type'] == 'right') {
          // Mutual Match! Create Chat Inbox Entry
          final chatId = (currentUser.uid.compareTo(targetUid) < 0)
              ? '${currentUser.uid}_$targetUid'
              : '${targetUid}_${currentUser.uid}';

          await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
            'participants': [currentUser.uid, targetUid],
            'createdAt': FieldValue.serverTimestamp(),
            'lastMessageAt': FieldValue.serverTimestamp(),
            'lastMessage': "Dialogue unlocked! Say hi.",
          });

          await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
            'friends': FieldValue.arrayUnion([targetUid])
          });
          await FirebaseFirestore.instance.collection('users').doc(targetUid).update({
            'friends': FieldValue.arrayUnion([currentUser.uid])
          });

          if (mounted) {
            _showMatchNotification(targetUid, chatId);
          }
        }
      });
    }

    return true;
  }

  void _showMatchNotification(String otherUid, String chatId) {
    FirebaseFirestore.instance.collection('users').doc(otherUid).get().then((doc) {
      if (!doc.exists || !mounted) return;
      final otherUser = UserModel.fromDocument(doc);
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF0F0F0F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Color(0xFF00FF88))),
          title: Text("VISIBLE CONNECTION!", style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: const Color(0xFF00FF88))),
          content: Text("A spiritual bond is unlocked with ${otherUser.name}. Tap below to whisper."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CLOSE", style: TextStyle(color: Colors.white38)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DirectChatScreen(chatId: chatId, otherUser: otherUser)),
                );
              },
              child: const Text("WHISPER", style: TextStyle(color: Color(0xFFFF8700))),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final mode = GhostTheme.of(context)?.themeMode ?? AppThemeMode.ghosted;
    final themeColor = DesignSystem.getThemeColor(mode);
    final isComic = mode == AppThemeMode.comic;

    if (_currentUser == null) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFF8700)));
    }

    final bool needsTags = _currentUser!.tags.isEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(LucideIcons.menu, color: isComic ? DesignSystem.comicInk : Colors.white),
          onPressed: () => AppLayout.openDrawer(context),
          tooltip: "OPEN MENU",
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'THE SÉANCE',
          style: isComic 
              ? GoogleFonts.bangers(fontSize: 26, color: DesignSystem.comicInk, letterSpacing: 2)
              : GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 22, color: Colors.white, letterSpacing: 2),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(LucideIcons.tag, color: isComic ? DesignSystem.comicInk : const Color(0xFFFF8700)),
            onPressed: _showTagSelectionDialog,
            tooltip: "MY TAGS",
          ),
          IconButton(
            icon: Icon(LucideIcons.settings, color: isComic ? DesignSystem.comicInk : Colors.white70),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
            tooltip: "SETTINGS",
          ),
        ],
      ),
      body: _isLoadingUsers
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF8700)))
          : needsTags
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: VoidEmptyState(
                      message: "SÉANCE GATEWAY:\nYOU MUST CHOOSE AT LEAST ONE TAG TO BEGIN MATCHING.",
                      actionLabel: "CHOOSE MY TAGS",
                      onAction: _showTagSelectionDialog,
                    ),
                  ),
                )
              : Padding(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).size.width < 768 ? 110 : 0),
                  child: Column(
                    children: [
                      // Pending Requests Banner
                      if (_pendingRequests.isNotEmpty) ...[
                        GestureDetector(
                          onTap: () => setState(() => _showingPending = !_showingPending),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [themeColor.withOpacity(0.15), themeColor.withOpacity(0.05)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: themeColor.withOpacity(0.4)),
                            ),
                            child: Row(
                              children: [
                                Icon(LucideIcons.userCheck, color: themeColor, size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "${_pendingRequests.length} PENDING FRIEND REQUEST${_pendingRequests.length > 1 ? 'S' : ''}",
                                    style: GoogleFonts.outfit(
                                      color: themeColor,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                                Icon(
                                  _showingPending ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                                  color: themeColor,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_showingPending) ...[
                          SizedBox(
                            height: 180,
                            child: _pendingIndex < _pendingRequests.length
                                ? _buildPendingCard(UserModel.fromDocument(_pendingRequests[_pendingIndex]), themeColor)
                                : Center(
                                    child: Text(
                                      "All requests reviewed!",
                                      style: GoogleFonts.inter(color: Colors.white38),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],

                      // Regular Suggestions
                      Expanded(
                        child: (_users.isEmpty || _deckIndex >= _users.length)
                            ? const VoidEmptyState(message: "THE VEIL IS STILL... NO SUGGESTIONS MATCH YOUR TAGS CURRENTLY.")
                            : Center(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final double cardWidth = min(380.0, constraints.maxWidth - 48);
                                    final double cardHeight = min(520.0, constraints.maxHeight - 20);

                                    return Container(
                                      height: cardHeight,
                                      width: cardWidth,
                                      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                      child: CardSwiper(
                                        controller: controller,
                                        cardsCount: _users.length,
                                        onSwipe: _onSwipe,
                                        isLoop: false,
                                        numberOfCardsDisplayed: 1,
                                        padding: EdgeInsets.zero,
                                        cardBuilder: (context, index, x, y) {
                                          final doc = _users[index];
                                          final targetUser = UserModel.fromDocument(doc);
                                          return Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              _buildSpiritCard(targetUser, themeColor),
                                              if (x > 10)
                                                Positioned.fill(
                                                  child: Opacity(
                                                    opacity: (x / 100.0).clamp(0.0, 1.0),
                                                    child: Container(
                                                      alignment: Alignment.center,
                                                      decoration: BoxDecoration(
                                                        border: Border.all(color: const Color(0xFF00FF88), width: 3),
                                                        borderRadius: BorderRadius.circular(28),
                                                        color: const Color(0xFF00FF88).withOpacity(0.1),
                                                      ),
                                                      child: Center(
                                                        child: Transform.rotate(
                                                          angle: -0.2,
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                                            decoration: BoxDecoration(
                                                              border: Border.all(color: const Color(0xFF00FF88), width: 4),
                                                              color: Colors.black,
                                                              borderRadius: BorderRadius.circular(12),
                                                            ),
                                                            child: Text(
                                                              "ACCEPTED",
                                                              style: GoogleFonts.outfit(
                                                                color: const Color(0xFF00FF88),
                                                                fontWeight: FontWeight.w900,
                                                                fontSize: 28,
                                                                letterSpacing: 3,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              if (x < -10)
                                                Positioned.fill(
                                                  child: Opacity(
                                                    opacity: (x.abs() / 100.0).clamp(0.0, 1.0),
                                                    child: Container(
                                                      alignment: Alignment.center,
                                                      decoration: BoxDecoration(
                                                        border: Border.all(color: Colors.redAccent, width: 3),
                                                        borderRadius: BorderRadius.circular(28),
                                                        color: Colors.redAccent.withOpacity(0.1),
                                                      ),
                                                      child: Center(
                                                        child: Transform.rotate(
                                                          angle: 0.2,
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                                            decoration: BoxDecoration(
                                                              border: Border.all(color: Colors.redAccent, width: 4),
                                                              color: Colors.black,
                                                              borderRadius: BorderRadius.circular(12),
                                                            ),
                                                            child: Text(
                                                              "GHOSTED",
                                                              style: GoogleFonts.outfit(
                                                                color: Colors.redAccent,
                                                                fontWeight: FontWeight.w900,
                                                                fontSize: 28,
                                                                letterSpacing: 3,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildPendingCard(UserModel user, Color themeColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundImage: user.photoUrl.isNotEmpty ? NetworkImage(user.photoUrl) : null,
            backgroundColor: Colors.white10,
            child: user.photoUrl.isEmpty ? const Icon(LucideIcons.ghost, color: Colors.white38) : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  user.name.toUpperCase(),
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                ),
                if (user.semester != null && user.semester!.isNotEmpty)
                  Text("Sem ${user.semester}", style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
                if (user.tags.isNotEmpty)
                  Text(
                    user.tags.take(3).join(' · '),
                    style: GoogleFonts.inter(color: themeColor.withOpacity(0.7), fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Accept
              GestureDetector(
                onTap: () => _respondToPendingRequest(user, accepted: true, themeColor: themeColor),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.green.withOpacity(0.4)),
                  ),
                  child: const Icon(LucideIcons.check, color: Colors.greenAccent, size: 18),
                ),
              ),
              const SizedBox(height: 8),
              // Decline
              GestureDetector(
                onTap: () => _respondToPendingRequest(user, accepted: false, themeColor: themeColor),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                  ),
                  child: const Icon(LucideIcons.x, color: Colors.redAccent, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _respondToPendingRequest(UserModel user, {required bool accepted, required Color themeColor}) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Record my response
    await FirebaseFirestore.instance.collection('swipes').doc("${currentUser.uid}_${user.uid}").set({
      'ownerId': currentUser.uid,
      'targetId': user.uid,
      'type': accepted ? 'right' : 'left',
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (accepted) {
      // Mutual match - create chat
      final chatId = (currentUser.uid.compareTo(user.uid) < 0)
          ? '${currentUser.uid}_${user.uid}'
          : '${user.uid}_${currentUser.uid}';

      await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
        'participants': [currentUser.uid, user.uid],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessage': "Connection established! Say hi 👋",
      });

      if (mounted) {
        _showMatchNotification(user.uid, chatId);
      }
    }

    setState(() {
      _pendingRequests.removeAt(_pendingIndex);
      // _pendingIndex stays the same to show next item
    });
  }

  Widget _buildSpiritCard(UserModel user, Color themeColor) {
    final mode = GhostTheme.of(context)?.themeMode ?? AppThemeMode.ghosted;
    final isComic = mode == AppThemeMode.comic;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: isComic
          ? BoxDecoration(
              color: DesignSystem.comicPaper,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: DesignSystem.comicInk, width: 3.0),
              boxShadow: const [
                BoxShadow(
                  color: DesignSystem.comicInk,
                  offset: Offset(6, 6),
                ),
              ],
            )
          : BoxDecoration(
              color: const Color(0xFF07070C),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: themeColor.withOpacity(0.18), width: 1.5),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0F0F1A),
                  Color(0xFF040407),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: themeColor.withOpacity(0.06),
                  blurRadius: 32,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Corner accents for technical telemetry design
          if (!isComic)
            Positioned.fill(
              child: CustomPaint(
                painter: _CardTelemetryPainter(color: themeColor.withOpacity(0.4)),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isComic ? Colors.white : themeColor.withOpacity(0.04),
                    shape: BoxShape.circle,
                    border: Border.all(color: isComic ? DesignSystem.comicInk : themeColor.withOpacity(0.15), width: isComic ? 2.5 : 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: isComic ? DesignSystem.comicInk.withOpacity(0.1) : themeColor.withOpacity(0.05),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: GhoulIcon(size: 48, color: isComic ? DesignSystem.comicInk : themeColor),
                ),
              ).animate().scale(delay: 100.ms, duration: 400.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 20),
              Text(
                user.name.toUpperCase(),
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: isComic ? DesignSystem.comicInk : Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: 2,
                  shadows: isComic
                      ? null
                      : [
                          Shadow(color: themeColor.withOpacity(0.3), blurRadius: 8),
                        ],
                ),
              ),
              if (user.semester != null && user.semester!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  "SEMESTER ${user.semester}",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: isComic ? DesignSystem.comicInk.withOpacity(0.8) : themeColor.withOpacity(0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isComic ? Colors.white : Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isComic ? DesignSystem.comicInk : Colors.white.withOpacity(0.03),
                    width: isComic ? 1.5 : 1.0,
                  ),
                  boxShadow: isComic
                      ? const [BoxShadow(color: DesignSystem.comicInk, offset: Offset(3, 3))]
                      : null,
                ),
                child: Text(
                  user.bio.isNotEmpty ? user.bio : "No transmission recorded.",
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: isComic ? DesignSystem.comicInk : Colors.white70,
                    fontSize: 12,
                    height: 1.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
               const SizedBox(height: 24),
              Text(
                "SIGNAL COMPATIBILITY",
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w900,
                  color: isComic ? DesignSystem.comicInk.withOpacity(0.5) : Colors.white30,
                  fontSize: 9,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: user.tags.take(6).map((tag) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isComic ? Colors.white : themeColor.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isComic ? DesignSystem.comicInk : themeColor.withOpacity(0.15),
                      width: isComic ? 1.5 : 1.0,
                    ),
                    boxShadow: isComic
                        ? const [BoxShadow(color: DesignSystem.comicInk, offset: Offset(2, 2))]
                        : null,
                  ),
                  child: Text(
                    tag.toUpperCase(),
                    style: GoogleFonts.outfit(
                      color: isComic ? DesignSystem.comicInk : themeColor,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => _showMoreDetailsSheet(user, themeColor),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "TAP TO VIEW MORE",
                        style: GoogleFonts.outfit(
                          color: isComic ? DesignSystem.comicInk : themeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(LucideIcons.chevronUp, size: 12, color: isComic ? DesignSystem.comicInk : themeColor),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showMoreDetailsSheet(UserModel user, Color themeColor) {
    final mode = GhostTheme.of(context)?.themeMode ?? AppThemeMode.ghosted;
    final isComic = mode == AppThemeMode.comic;
    
    final myTags = _currentUser?.tags ?? [];
    final commonInterests = user.tags.where((tag) => myTags.contains(tag)).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isComic ? DesignSystem.comicPaper : const Color(0xFF0F0F15),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: isComic ? const BorderSide(color: DesignSystem.comicInk, width: 3) : BorderSide.none,
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "SPIRIT PROFILE",
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w900, 
                      color: isComic ? DesignSystem.comicInk : themeColor, 
                      letterSpacing: 2, 
                      fontSize: 14
                    ),
                  ),
                  IconButton(
                    icon: Icon(LucideIcons.x, color: isComic ? DesignSystem.comicInk : Colors.white38, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundImage: user.photoUrl.isNotEmpty ? NetworkImage(user.photoUrl) : null,
                    backgroundColor: Colors.white10,
                    child: user.photoUrl.isEmpty ? const Icon(LucideIcons.ghost, size: 28) : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w900, 
                            color: isComic ? DesignSystem.comicInk : Colors.white, 
                            fontSize: 18
                          ),
                        ),
                        if (user.semester != null && user.semester!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            "Semester ${user.semester}", 
                            style: GoogleFonts.inter(
                              color: isComic ? Colors.black87 : Colors.white60, 
                              fontSize: 12
                            )
                          ),
                        ],
                        if (user.age != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            "Age: ${user.age}", 
                            style: GoogleFonts.inter(
                              color: isComic ? Colors.black54 : Colors.white38, 
                              fontSize: 11
                            )
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Common Interests
              if (commonInterests.isNotEmpty) ...[
                Text(
                  "COMMON INTERESTS",
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold, 
                    color: isComic ? DesignSystem.comicInk : const Color(0xFF00FF88), 
                    fontSize: 11, 
                    letterSpacing: 1
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: commonInterests.map((tag) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isComic ? Colors.white : const Color(0xFF00FF88).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isComic ? DesignSystem.comicInk : const Color(0xFF00FF88).withOpacity(0.3),
                        width: isComic ? 1.5 : 1.0,
                      ),
                    ),
                    child: Text(
                      tag, 
                      style: GoogleFonts.inter(
                        color: isComic ? DesignSystem.comicInk : const Color(0xFF00FF88), 
                        fontSize: 10, 
                        fontWeight: FontWeight.bold
                      )
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 16),
              ],

              // Mutual / Common Friends
              (() {
                final myFriends = _currentUser?.friends ?? [];
                final otherFriends = user.friends;
                final commonFriendUids = myFriends.where((f) => otherFriends.contains(f)).toList();
                final displayUids = commonFriendUids.isNotEmpty ? commonFriendUids : otherFriends;
                final bool isMutual = commonFriendUids.isNotEmpty;
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      isMutual ? "MUTUAL SPIRITS (COMMON FRIENDS)" : "SPIRIT CONNECTIONS (FRIENDS)",
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold, 
                        color: isMutual ? (isComic ? DesignSystem.comicInk : const Color(0xFF00FF88)) : (isComic ? Colors.black45 : Colors.white38), 
                        fontSize: 11, 
                        letterSpacing: 1
                      ),
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<List<UserModel>>(
                      future: _fetchUsers(displayUids),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24),
                            ),
                          );
                        }
                        final friendsList = snapshot.data ?? [];
                        if (friendsList.isEmpty) {
                          return Text(
                            "No matched connections recorded.",
                            style: GoogleFonts.inter(
                              color: isComic ? Colors.black38 : Colors.white24, 
                              fontSize: 11
                            ),
                          );
                        }
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: friendsList.map((f) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isComic ? Colors.white : Colors.white.withOpacity(0.02),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isComic ? DesignSystem.comicInk : Colors.white.withOpacity(0.05),
                                width: isComic ? 1.5 : 1.0,
                              ),
                              boxShadow: isComic ? [const BoxShadow(color: DesignSystem.comicInk, offset: Offset(2, 2))] : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 10,
                                  backgroundImage: f.photoUrl.isNotEmpty ? NetworkImage(f.photoUrl) : null,
                                  backgroundColor: Colors.white10,
                                  child: f.photoUrl.isEmpty ? const Icon(LucideIcons.user, size: 8, color: Colors.white38) : null,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  f.name,
                                  style: GoogleFonts.inter(
                                    color: isComic ? DesignSystem.comicInk : Colors.white70, 
                                    fontSize: 11, 
                                    fontWeight: FontWeight.bold
                                  ),
                                ),
                              ],
                            ),
                          )).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              }()),

              // Bio
              Text(
                "TRANSMISSION / BIO",
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold, 
                  color: isComic ? Colors.black45 : Colors.white38, 
                  fontSize: 11, 
                  letterSpacing: 1
                ),
              ),
              const SizedBox(height: 8),
              Text(
                user.bio.isNotEmpty ? user.bio : "This spirit is silent...",
                style: GoogleFonts.inter(
                  color: isComic ? DesignSystem.comicInk : Colors.white70, 
                  fontSize: 12.5, 
                  height: 1.4
                ),
              ),
              const SizedBox(height: 16),

              // All Interests
              if (user.tags.isNotEmpty) ...[
                Text(
                  "ALL INTERESTS",
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold, 
                    color: isComic ? Colors.black45 : Colors.white38, 
                    fontSize: 11, 
                    letterSpacing: 1
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: user.tags.map((tag) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isComic ? Colors.white : themeColor.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isComic ? DesignSystem.comicInk : themeColor.withOpacity(0.15),
                        width: isComic ? 1.5 : 1.0,
                      ),
                    ),
                    child: Text(
                      tag, 
                      style: GoogleFonts.inter(
                        color: isComic ? DesignSystem.comicInk : Colors.white60, 
                        fontSize: 10
                      )
                    ),
                  )).toList(),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class _CardTelemetryPainter extends CustomPainter {
  final Color color;
  _CardTelemetryPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;
    final pad = 6.0;
    final len = 10.0;

    canvas.drawPath(Path()
      ..moveTo(w - pad - len, pad)
      ..lineTo(w - pad, pad)
      ..lineTo(w - pad, pad + len), paint);

    canvas.drawPath(Path()
      ..moveTo(pad, h - pad - len)
      ..lineTo(pad, h - pad)
      ..lineTo(pad + len, h - pad), paint);
  }

  @override
  bool shouldRepaint(covariant _CardTelemetryPainter oldDelegate) => oldDelegate.color != color;
}
