import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/cloudinary_service.dart';
import '../widgets/void_empty_state.dart';
import '../utils/design_system.dart';
import '../widgets/ghost_theme.dart';
import '../models/user_model.dart';
import '../widgets/story_viewer.dart';
import 'direct_chat_screen.dart';
import '../layout/app_layout.dart';
import 'settings_screen.dart';

class YearbookScreen extends StatefulWidget {
  const YearbookScreen({super.key});

  @override
  State<YearbookScreen> createState() => _YearbookScreenState();
}

class _YearbookScreenState extends State<YearbookScreen> {
  bool _isUploading = false;
  String? _temporaryPhotoUrl;
  List<String> _temporaryPhotos = [];
  bool _isUploadingPost = false;
  
  // Raking options: 'views' or 'likes'
  String _rankingType = 'views'; 
  
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (doc.exists && mounted) {
      setState(() {
        _currentUser = UserModel.fromDocument(doc);
      });
    }
  }

  Widget _buildStoriesRow(Color themeColor) {
    final now = DateTime.now();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('stories')
          .where('expiresAt', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        
        final docs = snapshot.data!.docs;
        
        // Group stories by userId
        final Map<String, List<DocumentSnapshot>> groupedStories = {};
        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final String uid = data['userId'] ?? '';
          if (uid.isNotEmpty) {
            groupedStories.putIfAbsent(uid, () => []).add(doc);
          }
        }
        
        final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
        final myStories = groupedStories[currentUserId] ?? [];
        
        // List of other users who have active stories
        final otherUserIds = groupedStories.keys.where((uid) => uid != currentUserId).toList();
        
        return Container(
          height: 112,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              // 1. My Story Bubble
              _buildMyStoryBubble(myStories, themeColor),
              
              // 2. Other User Story Bubbles
              ...otherUserIds.map((uid) {
                final userStories = groupedStories[uid]!;
                final firstStory = userStories.first.data() as Map<String, dynamic>;
                final String name = firstStory['userName'] ?? 'Ghost';
                final String photoUrl = firstStory['userPhotoUrl'] ?? '';
                
                return _buildStoryBubble(
                  name: name,
                  photoUrl: photoUrl,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StoryViewer(
                          stories: userStories,
                          initialIndex: 0,
                        ),
                      ),
                    );
                  },
                  themeColor: themeColor,
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMyStoryBubble(List<DocumentSnapshot> myStories, Color themeColor) {
    final String photoUrl = _currentUser?.photoUrl ?? '';
    final bool hasStories = myStories.isNotEmpty;
    
    return GestureDetector(
      onTap: () {
        if (hasStories) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StoryViewer(
                stories: myStories,
                initialIndex: 0,
              ),
            ),
          );
        } else {
          _showAddStorySheet();
        }
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 16.0),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: hasStories 
                          ? [themeColor, const Color(0xFFFF4500)] 
                          : [Colors.white24, Colors.white10],
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                    backgroundColor: Colors.white10,
                    child: photoUrl.isEmpty ? const Icon(LucideIcons.user, color: Colors.white24, size: 24) : null,
                  ),
                ),
                if (!hasStories)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF8000),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.plus, size: 10, color: Colors.black),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              "My Story",
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryBubble({
    required String name,
    required String photoUrl,
    required VoidCallback onTap,
    required Color themeColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFFF8000), Color(0xFFFF4500)],
                ),
              ),
              child: CircleAvatar(
                radius: 28,
                backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                backgroundColor: Colors.white10,
                child: photoUrl.isEmpty ? const Icon(LucideIcons.user, color: Colors.white24, size: 24) : null,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 64,
              child: Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddStorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F0F0F),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        final TextEditingController textController = TextEditingController();
        String? localPhotoUrl;
        bool isUploadingImage = false;
        bool isPostingStory = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 24,
                left: 24,
                right: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "ADD TO STORY",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2),
                    ),
                    const SizedBox(height: 24),
                    
                    // Photo Upload
                    Text(
                      "STORY PORTRAIT",
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white54, fontSize: 10),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();
                        final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 40);
                        if (file != null) {
                          setModalState(() => isUploadingImage = true);
                          final bytes = await file.readAsBytes();
                          final url = await CloudinaryService.uploadMedia(bytes, 'stories');
                          setModalState(() {
                            localPhotoUrl = url;
                            isUploadingImage = false;
                          });
                        }
                      },
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.02),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                          image: localPhotoUrl != null
                              ? DecorationImage(image: NetworkImage(localPhotoUrl!), fit: BoxFit.contain)
                              : null,
                        ),
                        child: isUploadingImage
                            ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF8000)))
                            : localPhotoUrl == null
                                ? const Center(child: Icon(LucideIcons.camera, color: Colors.white38, size: 32))
                                : null,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Story caption
                    TextField(
                      controller: textController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      maxLength: 120,
                      decoration: InputDecoration(
                        hintText: "Add overlay text to your story...",
                        hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.02),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFF8000))),
                        counterStyle: const TextStyle(color: Colors.white24),
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF8000),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: isPostingStory || localPhotoUrl == null
                          ? null
                          : () async {
                              setModalState(() => isPostingStory = true);
                              
                              final user = FirebaseAuth.instance.currentUser;
                              if (user == null) return;
                              
                              final expires = DateTime.now().add(const Duration(hours: 24));
                              
                              await FirebaseFirestore.instance.collection('stories').add({
                                'userId': user.uid,
                                'userName': _currentUser?.name ?? 'Anonymous Ghost',
                                'userPhotoUrl': _currentUser?.photoUrl ?? '',
                                'mediaUrl': localPhotoUrl,
                                'text': textController.text.trim(),
                                'timestamp': FieldValue.serverTimestamp(),
                                'expiresAt': Timestamp.fromDate(expires),
                              });
                              
                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Story uploaded successfully!")),
                                );
                              }
                            },
                      child: isPostingStory
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : const Text("POST STORY"),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      _loadCurrentUser(); // Reload after upload
    });
  }

  @override
  Widget build(BuildContext context) {
    final mode = GhostTheme.of(context)?.themeMode ?? AppThemeMode.ghosted;
    final themeColor = DesignSystem.getThemeColor(mode);
    final isComic = mode == AppThemeMode.comic;
    final double screenWidth = MediaQuery.of(context).size.width;

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
          'THE ARCHIVES',
          style: isComic 
              ? GoogleFonts.bangers(fontSize: 26, color: DesignSystem.comicInk, letterSpacing: 2)
              : GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 22, color: Colors.white, letterSpacing: 2),
        ),
        centerTitle: true,
        actions: [
          if (screenWidth < 600)
            IconButton(
              icon: Icon(LucideIcons.upload, color: isComic ? DesignSystem.comicInk : themeColor),
              onPressed: () => _showUploadSheet(context),
              tooltip: "UPLOAD ESSENCE",
            ),
          IconButton(
            icon: Icon(LucideIcons.settings, color: isComic ? DesignSystem.comicInk : Colors.white70),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
            tooltip: "SETTINGS",
          ),
        ],
      ),
      body: Column(
        children: [
          // Dynamic Stories Row
          _buildStoriesRow(themeColor),
          const Divider(color: Colors.white10, height: 1),

          // Ranking Selection Tab Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _rankingType = 'views'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _rankingType == 'views' 
                            ? (isComic ? DesignSystem.comicYellow : themeColor.withOpacity(0.1)) 
                            : (isComic ? Colors.white.withOpacity(0.5) : Colors.white.withOpacity(0.01)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _rankingType == 'views' 
                              ? (isComic ? DesignSystem.comicInk : themeColor) 
                              : (isComic ? DesignSystem.comicInk.withOpacity(0.2) : Colors.white10),
                          width: isComic ? 2.0 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.eye, 
                            color: _rankingType == 'views' 
                                ? (isComic ? DesignSystem.comicInk : themeColor) 
                                : (isComic ? DesignSystem.comicInk.withOpacity(0.4) : Colors.white38), 
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "VIEW RANKING", 
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold, 
                              fontSize: 11, 
                              color: _rankingType == 'views' 
                                  ? (isComic ? DesignSystem.comicInk : Colors.white) 
                                  : (isComic ? DesignSystem.comicInk.withOpacity(0.4) : Colors.white38),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _rankingType = 'likes'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _rankingType == 'likes' 
                            ? (isComic ? DesignSystem.comicYellow : themeColor.withOpacity(0.1)) 
                            : (isComic ? Colors.white.withOpacity(0.5) : Colors.white.withOpacity(0.01)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _rankingType == 'likes' 
                              ? (isComic ? DesignSystem.comicInk : themeColor) 
                              : (isComic ? DesignSystem.comicInk.withOpacity(0.2) : Colors.white10),
                          width: isComic ? 2.0 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.heart, 
                            color: _rankingType == 'likes' 
                                ? (isComic ? DesignSystem.comicInk : themeColor) 
                                : (isComic ? DesignSystem.comicInk.withOpacity(0.4) : Colors.white38), 
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "LIKE RANKING", 
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold, 
                              fontSize: 11, 
                              color: _rankingType == 'likes' 
                                  ? (isComic ? DesignSystem.comicInk : Colors.white) 
                                  : (isComic ? DesignSystem.comicInk.withOpacity(0.4) : Colors.white38),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // User Grid View
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').where('joinedArchives', isEqualTo: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFFF8700)));
                }

                final List<QueryDocumentSnapshot> users = snapshot.data!.docs.toList();

                // Sort based on selected ranking type
                users.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  if (_rankingType == 'views') {
                    final aViews = aData['viewCount'] ?? 0;
                    final bViews = bData['viewCount'] ?? 0;
                    return bViews.compareTo(aViews);
                  } else {
                    final aLikes = aData['soulCount'] ?? 0;
                    final bLikes = bData['soulCount'] ?? 0;
                    return bLikes.compareTo(aLikes);
                  }
                });

                if (users.isEmpty) {
                  return const VoidEmptyState(message: "THE ARCHIVES ARE BARE... CHOOSE UPLOAD BELOW TO LEAVE YOUR PORTRAIT.");
                }

                final double screenWidth = MediaQuery.of(context).size.width;
                int columns = 2;
                if (screenWidth >= 1200) {
                  columns = 6;
                } else if (screenWidth >= 900) {
                  columns = 4;
                } else if (screenWidth >= 600) {
                  columns = 3;
                }

                return DesignSystem.responsiveWidth(
                  child: GridView.builder(
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 120),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final doc = users[index];
                      final userModel = UserModel.fromDocument(doc);
                      return _buildUserCard(userModel, index + 1, themeColor);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: screenWidth >= 600
          ? Padding(
              padding: const EdgeInsets.only(bottom: 80.0),
              child: FloatingActionButton.extended(
                onPressed: () => _showUploadSheet(context),
                backgroundColor: themeColor,
                icon: const Icon(LucideIcons.upload, color: Colors.black),
                label: Text("UPLOAD ESSENCE", style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.black)),
              ),
            )
          : null,
    );
  }

  Widget _buildUserCard(UserModel user, int rank, Color themeColor) {
    final bool isTopRank = rank <= 3;
    final Color rankColor = isTopRank ? themeColor : Colors.white24;
    final mode = GhostTheme.of(context)?.themeMode ?? AppThemeMode.ghosted;
    final bool isComic = mode == AppThemeMode.comic;

    return GestureDetector(
      onTap: () => _showProfileDetails(user),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF06060A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isTopRank ? themeColor.withOpacity(0.4) : Colors.white.withOpacity(0.06),
            width: isTopRank ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: (isTopRank ? themeColor : Colors.black).withOpacity(0.08),
              blurRadius: 16,
              spreadRadius: isTopRank ? 1 : -4,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image
            if (user.photoUrl.isNotEmpty)
              Image.network(user.photoUrl, fit: BoxFit.cover)
            else
              const Center(child: Icon(LucideIcons.user, size: 40, color: Colors.white10)),

            // Sleek Gradient Overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.0),
                    Colors.black.withOpacity(0.2),
                    Colors.black.withOpacity(0.85),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),

            // Telemetry Corner Lines for premium look
            if (!isComic)
              Positioned.fill(
                child: CustomPaint(
                  painter: _CardTelemetryPainter(color: rankColor.withOpacity(0.4)),
                ),
              ),

            // Rank Badge
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: rankColor.withOpacity(0.5), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isTopRank)
                      Icon(LucideIcons.trophy, color: themeColor, size: 10),
                    if (isTopRank) const SizedBox(width: 4),
                    Text(
                      "#$rank",
                      style: GoogleFonts.outfit(
                        color: isTopRank ? themeColor : Colors.white70,
                        fontWeight: FontWeight.w900,
                        fontSize: 9,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Info Details
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.eye, color: themeColor.withOpacity(0.8), size: 10),
                        const SizedBox(width: 3),
                        Text(
                          "${user.viewCount}",
                          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Icon(LucideIcons.heart, color: const Color(0xFFFF3366), size: 10),
                        const SizedBox(width: 3),
                        Text(
                          "${user.soulCount}",
                          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1), curve: Curves.easeOutCubic);
  }

  void _showProfileDetails(UserModel initialUser) {
    // Increment view count (field is 'viewCount' to match UserModel)
    FirebaseFirestore.instance.collection('users').doc(initialUser.uid).update({
      'viewCount': FieldValue.increment(1),
    });

    final myUid = FirebaseAuth.instance.currentUser?.uid;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0A0A0A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) {
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(initialUser.uid).get(),
          builder: (context, snapshot) {
            final user = snapshot.hasData && snapshot.data!.exists
                ? UserModel.fromDocument(snapshot.data!)
                : initialUser;
            
            // Check if current user has liked this profile
            final likedByMe = myUid != null && 
                (snapshot.data?.data() as Map<String, dynamic>?)?['likedBy'] is List &&
                ((snapshot.data?.data() as Map<String, dynamic>)['likedBy'] as List).contains(myUid);

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "SPIRIT ARCHIVE",
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: const Color(0xFFFF8700), letterSpacing: 2),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.x, color: Colors.white38),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Avatar & Basic Info
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundImage: user.photoUrl.isNotEmpty ? NetworkImage(user.photoUrl) : null,
                          backgroundColor: Colors.white10,
                          child: user.photoUrl.isEmpty ? const Icon(LucideIcons.ghost, size: 36) : null,
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name,
                                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 20),
                              ),
                              if (user.semester != null && user.semester!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  "Semester ${user.semester}",
                                  style: GoogleFonts.inter(color: Colors.white60, fontSize: 12),
                                ),
                              ],
                              if (user.age != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  "Age: ${user.age}",
                                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(LucideIcons.eye, color: Colors.white38, size: 12),
                                  const SizedBox(width: 4),
                                  Text("${user.viewCount}", style: GoogleFonts.inter(color: Colors.white38, fontSize: 10)),
                                  const SizedBox(width: 12),
                                  Icon(LucideIcons.heart, color: Colors.redAccent.withOpacity(0.7), size: 12),
                                  const SizedBox(width: 4),
                                  Text("${user.soulCount}", style: GoogleFonts.inter(color: Colors.white38, fontSize: 10)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  // Like Button (with toggle unlike capability)
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: likedByMe 
                                          ? Colors.redAccent.withOpacity(0.25) 
                                          : Colors.redAccent.withOpacity(0.08),
                                      foregroundColor: Colors.redAccent,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onPressed: myUid == null || myUid == user.uid ? null : () async {
                                      if (likedByMe) {
                                        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                                          'soulCount': FieldValue.increment(-1),
                                          'likedBy': FieldValue.arrayRemove([myUid]),
                                        });
                                      } else {
                                        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                                          'soulCount': FieldValue.increment(1),
                                          'likedBy': FieldValue.arrayUnion([myUid]),
                                        });
                                      }
                                    },
                                    icon: Icon(likedByMe ? LucideIcons.heart : LucideIcons.heart, size: 14),
                                    label: Text(likedByMe ? "LIKED ♥" : "LIKE"),
                                  ),
                                  const SizedBox(width: 12),

                                  // Friend Request / Connect Button (with cancel request capability)
                                  FutureBuilder<DocumentSnapshot>(
                                    future: FirebaseFirestore.instance.collection('swipes').doc("${myUid}_${user.uid}").get(),
                                    builder: (context, swipeSnapshot) {
                                      final hasSentRequest = swipeSnapshot.hasData && swipeSnapshot.data!.exists;
                                      return ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: hasSentRequest 
                                              ? Colors.amber.withOpacity(0.15) 
                                              : const Color(0xFFFF8700).withOpacity(0.1),
                                          foregroundColor: hasSentRequest ? Colors.amber : const Color(0xFFFF8700),
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        onPressed: myUid == null || myUid == user.uid ? null : () async {
                                          if (hasSentRequest) {
                                            // Revert request
                                            await FirebaseFirestore.instance.collection('swipes').doc("${myUid}_${user.uid}").delete();
                                            if (mounted && context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text("Friend request cancelled.")),
                                              );
                                            }
                                          } else {
                                            // Log swipe right to simulate direct friend request match trigger
                                            await FirebaseFirestore.instance.collection('swipes').doc("${myUid}_${user.uid}").set({
                                              'ownerId': myUid,
                                              'targetId': user.uid,
                                              'type': 'right',
                                              'timestamp': FieldValue.serverTimestamp(),
                                            });

                                            // Auto check mutual swipe
                                            final doc = await FirebaseFirestore.instance.collection('swipes').doc("${user.uid}_$myUid").get();
                                            if (doc.exists && doc.data()?['type'] == 'right') {
                                              // Mutual match - create chat
                                              final chatId = (myUid.compareTo(user.uid) < 0) ? '${myUid}_${user.uid}' : '${user.uid}_$myUid';
                                              await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
                                                'participants': [myUid, user.uid],
                                                'createdAt': FieldValue.serverTimestamp(),
                                                'lastMessageAt': FieldValue.serverTimestamp(),
                                                'lastMessage': "Dialogue unlocked via Archive request.",
                                              });
                                              await FirebaseFirestore.instance.collection('users').doc(myUid).update({
                                                'friends': FieldValue.arrayUnion([user.uid])
                                              });
                                              await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                                                'friends': FieldValue.arrayUnion([myUid])
                                              });
                                              if (mounted && context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text("✨ Mutual match! Chat unlocked.")),
                                                );
                                              }
                                            } else {
                                              if (mounted && context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text("Friend request sent!")),
                                                );
                                              }
                                            }
                                          }
                                        },
                                        icon: Icon(hasSentRequest ? LucideIcons.userMinus : LucideIcons.userPlus, size: 14),
                                        label: Text(hasSentRequest ? "PENDING" : "CONNECT"),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Tags
                    if (user.tags.isNotEmpty) ...[
                      Text(
                        "INTERESTS",
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white38, fontSize: 11, letterSpacing: 1),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: user.tags.take(12).map((tag) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF8700).withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFF8700).withOpacity(0.2)),
                          ),
                          child: Text(tag, style: GoogleFonts.inter(color: Colors.white60, fontSize: 10)),
                        )).toList(),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Bio
                    Text(
                      "BIO",
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white38, fontSize: 11, letterSpacing: 1),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      user.bio.isNotEmpty ? user.bio : "This spirit is silent...",
                      style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 24),

                    // Additional Posts (Grid of 4 posts)
                    Text(
                      "ESSENCE POSTS",
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white38, fontSize: 11, letterSpacing: 1),
                    ),
                    const SizedBox(height: 12),
                    if (user.profilePhotos.isNotEmpty)
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1.0,
                        ),
                        itemCount: user.profilePhotos.length,
                        itemBuilder: (context, i) {
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.02),
                              borderRadius: BorderRadius.circular(16),
                              image: DecorationImage(image: NetworkImage(user.profilePhotos[i]), fit: BoxFit.cover),
                              border: Border.all(color: Colors.white.withOpacity(0.05)),
                            ),
                          );
                        },
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.01),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.03)),
                        ),
                        child: const Center(
                          child: Text("No posts released yet.", style: TextStyle(color: Colors.white24, fontSize: 12)),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }

  void _showUploadSheet(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final bool alreadyJoined = data['joinedArchives'] ?? false;

    final nameController = TextEditingController(text: data['name'] ?? "");
    final bioController = TextEditingController(text: data['bio'] ?? "");
    final semesterController = TextEditingController(text: data['semester'] ?? "");
    
    _temporaryPhotoUrl = data['photoUrl'];
    _temporaryPhotos = List<String>.from(data['profilePhotos'] ?? []);

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F0F0F),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24, top: 24, left: 24, right: 24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      alreadyJoined ? "UPDATE ARCHIVE ENTRY" : "JOIN THE ARCHIVES",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2),
                    ),
                    const SizedBox(height: 24),

                    // Primary Mandatory Photo
                    Text(
                      "MANDATORY PROFILE PHOTO (REAL ABOUT YOU)",
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white54, fontSize: 10),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();
                        final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 40);
                        if (file != null) {
                          setModalState(() => _isUploading = true);
                          final bytes = await file.readAsBytes();
                          final url = await CloudinaryService.uploadMedia(bytes, 'profile_photos');
                          setModalState(() {
                            _temporaryPhotoUrl = url;
                            _isUploading = false;
                          });
                        }
                      },
                      child: Container(
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.02),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                          image: _temporaryPhotoUrl != null
                              ? DecorationImage(image: NetworkImage(_temporaryPhotoUrl!), fit: BoxFit.cover)
                              : null,
                        ),
                        child: _isUploading
                            ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF8700)))
                            : _temporaryPhotoUrl == null
                                ? const Center(child: Icon(LucideIcons.camera, color: Colors.white38, size: 32))
                                : null,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 4 Additional Posts
                    Text(
                      "ESSENCE POSTS (GRID OF 4 - OPTIONAL)",
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white54, fontSize: 10),
                    ),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: 4,
                      itemBuilder: (context, i) {
                        final bool hasImage = i < _temporaryPhotos.length;
                        return GestureDetector(
                          onTap: () async {
                            final picker = ImagePicker();
                            final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 40);
                            if (file != null) {
                              setModalState(() => _isUploadingPost = true);
                              final bytes = await file.readAsBytes();
                              final url = await CloudinaryService.uploadMedia(bytes, 'archive_posts');
                              setModalState(() {
                                if (hasImage) {
                                  _temporaryPhotos[i] = url;
                                } else {
                                  _temporaryPhotos.add(url);
                                }
                                _isUploadingPost = false;
                              });
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.02),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white10),
                              image: hasImage
                                  ? DecorationImage(image: NetworkImage(_temporaryPhotos[i]), fit: BoxFit.cover)
                                  : null,
                            ),
                            child: !hasImage
                                ? const Center(child: Icon(LucideIcons.plus, color: Colors.white38))
                                : null,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: "Alias", labelStyle: TextStyle(color: Colors.white54)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: semesterController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: "Semester of Study", labelStyle: TextStyle(color: Colors.white54)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bioController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: "Bio (100 words max)", labelStyle: TextStyle(color: Colors.white54)),
                    ),
                    const SizedBox(height: 20),
                    
                    const SizedBox(height: 32),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF8700),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () async {
                        if (_temporaryPhotoUrl == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("A profile photo is mandatory to join the archives.")),
                          );
                          return;
                        }

                        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                          'name': nameController.text.trim().isEmpty ? 'Anonymous Ghost' : nameController.text.trim(),
                          'photoUrl': _temporaryPhotoUrl,
                          'profilePhotos': _temporaryPhotos,
                          'joinedArchives': true,
                          'semester': semesterController.text.trim(),
                          'bio': bioController.text.trim(),
                          'email': user.email,
                          'uid': user.uid,
                        }, SetOptions(merge: true));

                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Essence archived successfully!")),
                          );
                        }
                      },
                      child: const Text("SUBMIT TO ARCHIVES"),
                    ),
                  ],
                ),
              ),
            );
          }
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
