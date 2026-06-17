import 'dart:math';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:html' as html;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/user_model.dart';
import '../utils/design_system.dart';
import '../widgets/ghost_theme.dart';
import '../widgets/void_empty_state.dart';
import '../widgets/youtube_player_widget.dart';
import '../layout/app_layout.dart';
import 'settings_screen.dart';

class HappyWatchScreen extends StatefulWidget {
  const HappyWatchScreen({super.key});

  @override
  State<HappyWatchScreen> createState() => _HappyWatchScreenState();
}

class _HappyWatchScreenState extends State<HappyWatchScreen> with SingleTickerProviderStateMixin {
  static double _serverClockOffset = 0.0;
  static bool _hasFetchedOffset = false;
  bool _isCinematic = false;

  bool _showCreateRoomForm = false;
  String _selectedGenre = "General";
  final TextEditingController _roomNameController = TextEditingController();
  final TextEditingController _roomPasswordController = TextEditingController();

  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _roomIdController = TextEditingController();
  final TextEditingController _chatController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  
  bool _isConnected = false;
  String _currentRoomId = "";
  UserModel? _currentUser;
  bool _hasProfilePhoto = false;
  bool _isPrivateRoom = false;
  TabController? _tabController;
  StreamSubscription? _beforeUnloadSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkProfilePhoto();
    _cleanupExpiredRooms();
    if (kIsWeb) {
      _fetchServerClockOffset();
      _beforeUnloadSubscription = html.window.onBeforeUnload.listen((event) {
        _leaveRoomIfNeeded();
      });
    }
  }

  @override
  void dispose() {
    _beforeUnloadSubscription?.cancel();
    _tabController?.dispose();
    _nicknameController.dispose();
    _roomIdController.dispose();
    _chatController.dispose();
    _urlController.dispose();
    _roomNameController.dispose();
    _roomPasswordController.dispose();
    _leaveRoomIfNeeded();
    super.dispose();
  }

  Future<void> _checkProfilePhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (doc.exists) {
      final model = UserModel.fromDocument(doc);
      setState(() {
        _currentUser = model;
        _nicknameController.text = model.name;
        _hasProfilePhoto = model.photoUrl.isNotEmpty && model.joinedArchives;
      });
      if (kIsWeb) {
        _fetchServerClockOffset();
      }
    }
  }

  Future<void> _leaveRoomIfNeeded() async {
    if (!_isConnected || _currentRoomId.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final roomRef = FirebaseFirestore.instance.collection('happy_watch_rooms').doc(_currentRoomId);
    
    try {
      final doc = await roomRef.get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['pilots'] is List) {
          final List pilots = List.from(data['pilots']);
          pilots.removeWhere((p) => p['uid'] == user.uid);
          
          if (pilots.isEmpty) {
            // Update emptyAt timestamp for self-termination after 15 minutes
            await roomRef.update({
              'pilots': pilots,
              'emptyAt': FieldValue.serverTimestamp(),
              'lastActivityAt': FieldValue.serverTimestamp(),
            });
          } else {
            await roomRef.update({
              'pilots': pilots,
              'lastActivityAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error leaving room: $e");
    }
  }

  Future<void> _cleanupExpiredRooms() async {
    try {
      final now = DateTime.now();
      final cutoff = now.subtract(const Duration(minutes: 15));
      final inactivityCutoff = now.subtract(const Duration(minutes: 30));
      
      final query = await FirebaseFirestore.instance
          .collection('happy_watch_rooms')
          .get();
          
      for (var doc in query.docs) {
        final data = doc.data();
        bool shouldDelete = false;
        
        if (data['emptyAt'] != null) {
          final emptyAt = (data['emptyAt'] as Timestamp).toDate();
          if (emptyAt.isBefore(cutoff)) {
            shouldDelete = true;
          }
        }
        
        if (!shouldDelete && data['lastActivityAt'] != null) {
          final lastActivity = (data['lastActivityAt'] as Timestamp).toDate();
          if (lastActivity.isBefore(inactivityCutoff)) {
            shouldDelete = true;
          }
        }
        
        if (shouldDelete) {
          await doc.reference.delete();
        }
      }
    } catch (e) {
      debugPrint("Error cleaning up expired rooms: $e");
    }
  }

  Future<void> _fetchServerClockOffset() async {
    if (_hasFetchedOffset) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final startLocal = DateTime.now().millisecondsSinceEpoch;
      await userRef.update({'lastClockSync': FieldValue.serverTimestamp()});
      final doc = await userRef.get();
      final endLocal = DateTime.now().millisecondsSinceEpoch;
      final serverTimestamp = doc.data()?['lastClockSync'] as Timestamp?;
      if (serverTimestamp != null) {
        final serverMs = serverTimestamp.millisecondsSinceEpoch;
        final rtt = endLocal - startLocal;
        final estimatedLocalMs = startLocal + (rtt ~/ 2);
        _serverClockOffset = (serverMs - estimatedLocalMs) / 1000.0;
        _hasFetchedOffset = true;
        debugPrint("[HappyWatch] Firestore clock offset calculated: $_serverClockOffset seconds (RTT: $rtt ms)");
      }
    } catch (e) {
      debugPrint("[HappyWatch] Error calculating server clock offset: $e");
    }
  }

  String _unescapeUnicode(String input) {
    try {
      return input.replaceAllMapped(RegExp(r'\\u([0-9a-fA-F]{4})'), (Match match) {
        final hex = match.group(1)!;
        final code = int.parse(hex, radix: 16);
        return String.fromCharCode(code);
      }).replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
    } catch (e) {
      return input;
    }
  }

  Future<List<Map<String, String>>> _searchYoutube(String query) async {
    if (kIsWeb) {
      // Try working proxy APIs for web to bypass CORS
      final proxies = [
        "https://pipedapi.kavin.rocks/search?q=",
        "https://invidious.jing.rocks/api/v1/search?q=",
        "https://invidious.nerdvpn.de/api/v1/search?q=",
        "https://inv.tux.pizza/api/v1/search?q=",
        "https://pipedapi.lunar.icu/search?q=",
        "https://invidious.flokinet.to/api/v1/search?q=",
      ];
      
      for (final proxy in proxies) {
        try {
          final isPiped = proxy.contains("piped");
          final urlStr = proxy + Uri.encodeComponent(query) + (isPiped ? "&filter=all" : "");
          final url = Uri.parse(urlStr);
          final response = await http.get(url).timeout(const Duration(seconds: 5));
          
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final results = <Map<String, String>>[];
            final items = isPiped ? (data['items'] as List) : (data as List);
            
            for (var item in items) {
              if (isPiped && item['type'] != 'stream') continue;
              if (!isPiped && item['type'] != 'video') continue;
              
              final videoId = isPiped ? item['url'].toString().split('?v=')[1] : item['videoId'];
              results.add({
                'videoId': videoId,
                'title': item['title'] ?? 'Unknown',
                'author': isPiped ? item['uploaderName'] : item['author'],
                'thumbnail': 'https://img.youtube.com/vi/$videoId/0.jpg',
              });
              if (results.length >= 15) break;
            }
            if (results.isNotEmpty) return results;
          }
        } catch (e) {
          debugPrint("Web proxy search error on $proxy: $e");
        }
      }
    }

    // Fallback to youtube_explode_dart (Works reliably on native, blocked on web by CORS)
    final yt = YoutubeExplode();
    try {
      final videos = await yt.search.search(query);
      final results = <Map<String, String>>[];
      for (var video in videos.take(15)) {
        results.add({
          'videoId': video.id.value,
          'title': video.title,
          'author': video.author,
          'thumbnail': 'https://img.youtube.com/vi/${video.id.value}/0.jpg',
        });
      }
      return results;
    } catch (e) {
      debugPrint("YoutubeExplode search error: $e");
      return [];
    } finally {
      yt.close();
    }
  }


  Future<void> _addVideoToQueueWithMetadata(String videoId, String title) async {
    if (_currentRoomId.isEmpty) return;
    final roomRef = FirebaseFirestore.instance.collection('happy_watch_rooms').doc(_currentRoomId);
    try {
      await roomRef.update({
        'queue': FieldValue.arrayUnion([
          {
            'videoId': videoId,
            'title': title,
            'addedBy': _currentUser?.name ?? "Pilot",
          }
        ])
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Video added to queue")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error adding video: $e")),
      );
    }
  }

  void _searchAndShowResults(String query) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // Let Container clip/handle it
      isScrollControlled: true,
      builder: (context) {
        final mode = GhostTheme.of(context)?.themeMode ?? AppThemeMode.ghosted;
        final themeColor = DesignSystem.getThemeColor(mode);
        final isComic = mode == AppThemeMode.comic;
        
        return StatefulBuilder(
          builder: (context, setModalState) {
            return FutureBuilder<List<Map<String, String>>>(
              future: _searchYoutube(query),
              builder: (context, snapshot) {
                Widget content;
                
                if (snapshot.connectionState == ConnectionState.waiting) {
                  content = SizedBox(
                    height: 300,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: isComic ? DesignSystem.comicInk : themeColor),
                          const SizedBox(height: 16),
                          Text(
                            "Searching telemetry networks...",
                            style: isComic
                                ? GoogleFonts.comicNeue(color: DesignSystem.comicInk, fontSize: 13, fontWeight: FontWeight.bold)
                                : GoogleFonts.outfit(color: Colors.white60, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  );
                } else if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                  content = SizedBox(
                    height: 300,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.alertTriangle, color: isComic ? DesignSystem.comicRed : Colors.amber, size: 40),
                            const SizedBox(height: 16),
                            Text(
                              "No results found on YouTube system.\nTry pasting a direct YouTube video link.",
                              textAlign: TextAlign.center,
                              style: isComic
                                  ? GoogleFonts.comicNeue(color: DesignSystem.comicInk, fontSize: 13, fontWeight: FontWeight.bold, height: 1.4)
                                  : GoogleFonts.outfit(color: Colors.white70, fontSize: 13, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                } else {
                  final videos = snapshot.data!;
                  content = Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.7,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: videos.length,
                      itemBuilder: (context, index) {
                        final video = videos[index];
                        final videoId = video['videoId']!;
                        final title = video['title']!;
                        final author = video['author']!;
                        final thumbnail = video['thumbnail']!;
                        
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isComic ? Colors.white : Colors.white.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(isComic ? 4 : 12),
                            border: Border.all(
                              color: isComic ? DesignSystem.comicInk : Colors.white.withOpacity(0.05),
                              width: isComic ? 2.5 : 1.0,
                            ),
                            boxShadow: isComic
                                ? const [BoxShadow(color: DesignSystem.comicInk, offset: Offset(4, 4))]
                                : null,
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.horizontal(left: Radius.circular(isComic ? 2 : 11)),
                                child: Image.network(
                                  thumbnail,
                                  width: 100,
                                  height: 75,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    width: 100,
                                    height: 75,
                                    color: isComic ? DesignSystem.comicPaper : Colors.white10,
                                    child: Icon(LucideIcons.video, color: isComic ? DesignSystem.comicInk : Colors.white30),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: isComic
                                            ? GoogleFonts.comicNeue(
                                                color: DesignSystem.comicInk,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              )
                                            : GoogleFonts.inter(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        author,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: isComic
                                            ? GoogleFonts.comicNeue(
                                                color: DesignSystem.comicInk.withOpacity(0.7),
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              )
                                            : GoogleFonts.outfit(
                                                color: Colors.white38,
                                                fontSize: 10,
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      LucideIcons.play,
                                      color: isComic ? DesignSystem.comicInk : themeColor,
                                      size: 18,
                                    ),
                                    tooltip: "PLAY NOW",
                                    onPressed: () {
                                      _changeVideo(videoId);
                                      _urlController.clear();
                                      Navigator.pop(context);
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      LucideIcons.plus,
                                      color: isComic ? DesignSystem.comicInk : Colors.white70,
                                      size: 18,
                                    ),
                                    tooltip: "ADD TO QUEUE",
                                    onPressed: () {
                                      _addVideoToQueueWithMetadata(videoId, title);
                                      _urlController.clear();
                                      Navigator.pop(context);
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                }
 
                return Container(
                  decoration: BoxDecoration(
                    color: isComic ? DesignSystem.comicPaper : const Color(0xFF0F0F0F),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    border: Border.all(
                      color: isComic ? DesignSystem.comicInk : Colors.transparent,
                      width: isComic ? 4.0 : 0.0,
                    ),
                  ),
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isComic ? DesignSystem.comicInk.withOpacity(0.3) : Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          "SEARCH RESULTS: $query",
                          textAlign: TextAlign.center,
                          style: isComic
                              ? GoogleFonts.bangers(
                                  color: DesignSystem.comicInk,
                                  fontSize: 20,
                                  letterSpacing: 1.5,
                                )
                              : GoogleFonts.outfit(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  fontSize: 16,
                                  letterSpacing: 1,
                                ),
                        ),
                      ),
                      Divider(color: isComic ? DesignSystem.comicInk.withOpacity(0.15) : Colors.white10, height: 1),
                      content,
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _terminateSessionDueToInactivity() async {
    if (_currentRoomId.isEmpty) return;
    final roomRef = FirebaseFirestore.instance.collection('happy_watch_rooms').doc(_currentRoomId);
    try {
      await roomRef.update({'inactiveTerminated': true});
      Future.delayed(const Duration(seconds: 2), () async {
        final messagesSnap = await roomRef.collection('messages').get();
        for (var doc in messagesSnap.docs) {
          await doc.reference.delete();
        }
        await roomRef.delete();
      });
    } catch (e) {
      debugPrint("Error terminating room due to inactivity: $e");
    }
  }

  Future<void> _connectToSpace({required bool isCreate}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final String nickname = _nicknameController.text.trim().isEmpty 
        ? "Pilot_${Random().nextInt(1000)}" 
        : _nicknameController.text.trim();
    
    String room = _roomIdController.text.trim().toUpperCase();
    
    if (isCreate) {
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
      final random = Random();
      room = String.fromCharCodes(Iterable.generate(7, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
      _roomIdController.text = room;
    } else {
      if (room.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter a target Room ID")),
        );
        return;
      }
    }

    final roomRef = FirebaseFirestore.instance.collection('happy_watch_rooms').doc(room);
    final myPilot = {
      'uid': user.uid,
      'name': nickname,
      'photoUrl': _currentUser?.photoUrl ?? "",
    };

    final mode = GhostTheme.of(context)?.themeMode ?? AppThemeMode.ghosted;
    final themeColor = DesignSystem.getThemeColor(mode);
    final isComic = mode == AppThemeMode.comic;

    try {
      final doc = await roomRef.get();
      if (isCreate) {
        await roomRef.set({
          'roomId': room,
          'roomName': _roomNameController.text.trim().isEmpty ? "Space $room" : _roomNameController.text.trim(),
          'genre': _selectedGenre,
          'password': _isPrivateRoom ? _roomPasswordController.text.trim() : "",
          'videoId': 'dQw4w9WgXcQ', // Default video: Rickroll!
          'isPlaying': true,
          'seekTime': 0.0,
          'lastUpdated': FieldValue.serverTimestamp(),
          'hostUid': user.uid,
          'pilots': [myPilot],
          'queue': [],
          'isPrivate': _isPrivateRoom,
          'emptyAt': null,
          'createdAt': FieldValue.serverTimestamp(),
          'lastActivityAt': FieldValue.serverTimestamp(),
          'warningSent30m': false,
        });
      } else {
        if (!doc.exists) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Room not found! Verify the ID.")),
          );
          return;
        }
        
        final data = doc.data();
        final isPrivate = data != null && data['isPrivate'] == true;
        if (isPrivate) {
          final roomPassword = data['password'] as String? ?? "";
          final enteredPassword = await _showPasswordDialog(context, isComic, themeColor);
          if (enteredPassword == null) {
            return;
          }
          if (enteredPassword != roomPassword) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Incorrect room key! Access denied.")),
              );
            }
            return;
          }
        }

        final List pilots = data != null && data['pilots'] is List ? List.from(data['pilots']) : [];
        if (!pilots.any((p) => p['uid'] == user.uid)) {
          pilots.add(myPilot);
          await roomRef.update({
            'pilots': pilots,
            'emptyAt': null, // Clear emptyAt since a pilot joined
            'lastActivityAt': FieldValue.serverTimestamp(),
          });
        } else {
          await roomRef.update({
            'lastActivityAt': FieldValue.serverTimestamp(),
          });
        }
      }

      setState(() {
        _currentRoomId = room;
        _isConnected = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Connection error: $e")),
      );
    }
  }

  Future<String?> _showPasswordDialog(BuildContext context, bool isComic, Color themeColor) async {
    final TextEditingController pinController = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isComic ? DesignSystem.comicPaper : const Color(0xFF0F0F0F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isComic ? 4 : 16),
            side: isComic ? const BorderSide(color: DesignSystem.comicInk, width: 4) : BorderSide(color: Colors.white.withOpacity(0.05)),
          ),
          title: Text(
            "ENTER SPACE KEY",
            style: isComic 
                ? GoogleFonts.bangers(color: DesignSystem.comicInk, fontSize: 24, letterSpacing: 1.5)
                : GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "This space is private. Enter the custom key (password) to join.",
                style: isComic
                    ? GoogleFonts.comicNeue(color: DesignSystem.comicInk, fontWeight: FontWeight.bold, fontSize: 13)
                    : GoogleFonts.inter(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinController,
                obscureText: true,
                style: TextStyle(
                  color: isComic ? DesignSystem.comicInk : Colors.white,
                  fontSize: 13,
                  fontWeight: isComic ? FontWeight.bold : FontWeight.normal
                ),
                decoration: InputDecoration(
                  hintText: "Enter password...",
                  hintStyle: TextStyle(color: isComic ? Colors.black38 : Colors.white24, fontSize: 12),
                  filled: true,
                  fillColor: isComic ? Colors.white : Colors.white.withOpacity(0.02),
                  border: isComic 
                      ? OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: DesignSystem.comicInk, width: 3))
                      : OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
                  focusedBorder: isComic 
                      ? OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: DesignSystem.comicInk, width: 3.5))
                      : OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: themeColor)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text(
                "CANCEL",
                style: isComic 
                    ? GoogleFonts.bangers(color: Colors.redAccent, fontSize: 16)
                    : GoogleFonts.outfit(color: Colors.white54, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isComic ? DesignSystem.comicYellow : themeColor,
                foregroundColor: isComic ? DesignSystem.comicInk : Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isComic ? 4 : 8),
                  side: isComic ? const BorderSide(color: DesignSystem.comicInk, width: 2) : BorderSide.none,
                ),
              ),
              onPressed: () {
                Navigator.pop(context, pinController.text.trim());
              },
              child: Text(
                "JOIN",
                style: isComic 
                    ? GoogleFonts.bangers(fontSize: 16)
                    : GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _terminateSession() async {
    if (_currentRoomId.isEmpty) return;
    final roomRef = FirebaseFirestore.instance.collection('happy_watch_rooms').doc(_currentRoomId);
    try {
      final messagesSnap = await roomRef.collection('messages').get();
      for (var doc in messagesSnap.docs) {
        await doc.reference.delete();
      }
      await roomRef.delete();
    } catch (e) {
      debugPrint("Error terminating session: $e");
    }
  }

  Widget _buildLobbyMain(bool isComic, Color themeColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isComic ? Colors.white : themeColor.withOpacity(0.08),
              shape: BoxShape.circle,
              border: isComic ? Border.all(color: DesignSystem.comicInk, width: 3) : null,
              boxShadow: isComic ? const [BoxShadow(color: DesignSystem.comicInk, offset: Offset(3, 3))] : null,
            ),
            child: Icon(LucideIcons.tv, color: isComic ? DesignSystem.comicInk : themeColor, size: 48),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          "Happy Watch",
          textAlign: TextAlign.center,
          style: isComic 
              ? GoogleFonts.bangers(color: DesignSystem.comicInk, fontSize: 32, letterSpacing: 1.5)
              : GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 24, letterSpacing: 1),
        ),
        const SizedBox(height: 6),
        Text(
          "Futuristic Sync Experience",
          textAlign: TextAlign.center,
          style: isComic 
              ? GoogleFonts.comicNeue(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.bold)
              : GoogleFonts.inter(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _nicknameController,
          maxLength: 15,
          style: TextStyle(color: isComic ? DesignSystem.comicInk : Colors.white, fontSize: 13, fontWeight: isComic ? FontWeight.bold : FontWeight.normal),
          decoration: InputDecoration(
            hintText: "Enter your nickname...",
            hintStyle: TextStyle(color: isComic ? Colors.black38 : Colors.white24, fontSize: 12),
            filled: true,
            fillColor: isComic ? Colors.white : Colors.white.withOpacity(0.02),
            border: isComic 
                ? OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: DesignSystem.comicInk, width: 3))
                : OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
            focusedBorder: isComic 
                ? OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: DesignSystem.comicInk, width: 3.5))
                : OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: themeColor)),
            counterText: "",
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _roomIdController,
          style: TextStyle(color: isComic ? DesignSystem.comicInk : Colors.white, fontSize: 13, fontWeight: isComic ? FontWeight.bold : FontWeight.normal),
          decoration: InputDecoration(
            hintText: "Enter target Room ID to join",
            hintStyle: TextStyle(color: isComic ? Colors.black38 : Colors.white24, fontSize: 12),
            filled: true,
            fillColor: isComic ? Colors.white : Colors.white.withOpacity(0.02),
            border: isComic 
                ? OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: DesignSystem.comicInk, width: 3))
                : OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
            focusedBorder: isComic 
                ? OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: DesignSystem.comicInk, width: 3.5))
                : OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: themeColor)),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isComic ? DesignSystem.comicYellow : themeColor,
            foregroundColor: isComic ? DesignSystem.comicInk : Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isComic ? 4 : 12),
              side: isComic ? const BorderSide(color: DesignSystem.comicInk, width: 3) : BorderSide.none,
            ),
            elevation: isComic ? 0 : null,
          ),
          onPressed: () {
            final room = _roomIdController.text.trim();
            if (room.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Enter a target Room ID to join!")),
              );
              return;
            }
            _connectToSpace(isCreate: false);
          },
          child: Text(
            "Join Existing Space",
            style: isComic 
                ? GoogleFonts.bangers(fontSize: 18, letterSpacing: 1.5)
                : GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            backgroundColor: isComic ? Colors.white : Colors.transparent,
            foregroundColor: isComic ? DesignSystem.comicInk : themeColor,
            side: BorderSide(color: isComic ? DesignSystem.comicInk : themeColor, width: isComic ? 3 : 1),
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isComic ? 4 : 12)),
            elevation: 0,
          ),
          onPressed: () {
            setState(() {
              _showCreateRoomForm = true;
            });
          },
          child: Text(
            "Create Custom Space",
            style: isComic 
                ? GoogleFonts.bangers(fontSize: 18, letterSpacing: 1.5)
                : GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14),
          ),
        ),
        // --- EXPLORE PUBLIC SPACES BUTTON ---
        isComic 
            ? Container(height: 3, color: DesignSystem.comicInk, margin: const EdgeInsets.symmetric(vertical: 20))
            : Divider(color: themeColor.withOpacity(0.2), height: 32),
            
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: isComic ? DesignSystem.comicYellow : themeColor.withOpacity(0.15),
            foregroundColor: isComic ? DesignSystem.comicInk : themeColor,
            side: isComic ? const BorderSide(color: DesignSystem.comicInk, width: 3) : BorderSide(color: themeColor.withOpacity(0.3), width: 1),
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isComic ? 4 : 12)),
            elevation: 0,
          ),
          icon: Icon(LucideIcons.globe, size: 18, color: isComic ? DesignSystem.comicInk : themeColor),
          label: Text(
            "EXPLORE PUBLIC SPACES",
            style: isComic 
                ? GoogleFonts.bangers(fontSize: 18, letterSpacing: 1.5)
                : GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          onPressed: () {
            _openPublicSpacesScreen(context, isComic, themeColor);
          },
        ),
      ],
    );
  }

  void _openPublicSpacesScreen(BuildContext context, bool isComic, Color themeColor) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (context) {
          return Scaffold(
            backgroundColor: isComic ? DesignSystem.comicPaper : const Color(0xFF0F0F0F),
            appBar: AppBar(
              backgroundColor: isComic ? DesignSystem.comicPaper : const Color(0xFF0F0F0F),
              elevation: 0,
              iconTheme: IconThemeData(color: isComic ? DesignSystem.comicInk : Colors.white),
              title: Text(
                "LIVE PUBLIC SPACES",
                style: isComic 
                    ? GoogleFonts.bangers(color: DesignSystem.comicInk, fontSize: 24, letterSpacing: 1.5)
                    : GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5),
              ),
              centerTitle: true,
            ),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('happy_watch_rooms')
                          .where('isPrivate', isEqualTo: false)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator(color: Color(0xFFFF8700)));
                        }

                        final now = DateTime.now();
                        final docs = snapshot.data!.docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>?;
                          if (data == null) return false;
                          final createdAt = data['createdAt'] as Timestamp?;
                          if (createdAt == null) return true;
                          final diff = now.difference(createdAt.toDate());
                          return diff.inHours < 24;
                        }).toList();

                        if (docs.isEmpty) {
                          return Center(
                            child: Text(
                              "NO ACTIVE PUBLIC SPACES YET.\nLAUNCH ONE TO START THE PARTY!",
                              textAlign: TextAlign.center,
                              style: isComic
                                  ? GoogleFonts.comicNeue(color: DesignSystem.comicInk.withOpacity(0.6), fontSize: 14, fontWeight: FontWeight.bold)
                                  : GoogleFonts.inter(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final String roomId = data['roomId'] ?? doc.id;
                            final String roomName = data['roomName'] ?? "Space $roomId";
                            final String genre = data['genre'] ?? "General";
                            final List<dynamic> pilotsList = data['pilots'] as List<dynamic>? ?? [];
                            final int pilotCount = pilotsList.length;

                            final createdAt = data['createdAt'] as Timestamp?;
                            String timeRemaining = "24h";
                            if (createdAt != null) {
                              final remaining = const Duration(hours: 24) - now.difference(createdAt.toDate());
                              if (remaining.isNegative) {
                                timeRemaining = "0m";
                              } else {
                                timeRemaining = "${remaining.inHours}h ${remaining.inMinutes % 60}m";
                              }
                            }

                            if (isComic) {
                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: DesignSystem.comicInk, width: 2.5),
                                  boxShadow: const [
                                    BoxShadow(color: DesignSystem.comicInk, offset: Offset(4, 4)),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      roomName.toUpperCase(),
                                      style: GoogleFonts.bangers(color: DesignSystem.comicInk, fontSize: 18, letterSpacing: 1),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "GENRE: $genre | ID: $roomId",
                                          style: GoogleFonts.comicNeue(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          "👤 $pilotCount online",
                                          style: GoogleFonts.comicNeue(color: DesignSystem.comicInk, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "⏳ Life left: $timeRemaining",
                                      style: GoogleFonts.comicNeue(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: DesignSystem.comicYellow,
                                        foregroundColor: DesignSystem.comicInk,
                                        side: const BorderSide(color: DesignSystem.comicInk, width: 2),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                      ),
                                      onPressed: () {
                                        _roomIdController.text = roomId;
                                        _connectToSpace(isCreate: false);
                                        Navigator.pop(context);
                                      },
                                      child: Text(
                                        "JOIN SESSION",
                                        style: GoogleFonts.bangers(fontSize: 14, letterSpacing: 1),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.02),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: themeColor.withOpacity(0.12), width: 1.2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            roomName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: themeColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            genre,
                                            style: GoogleFonts.outfit(color: themeColor, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "ID: $roomId",
                                          style: GoogleFonts.inconsolata(color: Colors.white38, fontSize: 11),
                                        ),
                                        Row(
                                          children: [
                                            const Icon(LucideIcons.users, color: Colors.white38, size: 12),
                                            const SizedBox(width: 4),
                                            Text(
                                              "$pilotCount online",
                                              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(LucideIcons.clock, color: Colors.redAccent.withOpacity(0.8), size: 12),
                                            const SizedBox(width: 4),
                                            Text(
                                              "Expires in: $timeRemaining",
                                              style: GoogleFonts.outfit(color: Colors.redAccent.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: themeColor,
                                            foregroundColor: Colors.black,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            textStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11),
                                          ),
                                          onPressed: () {
                                            _roomIdController.text = roomId;
                                            _connectToSpace(isCreate: false);
                                            Navigator.pop(context);
                                          },
                                          child: const Text("JOIN"),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCreateRoomForm(bool isComic, Color themeColor) {
    final List<String> genres = ["General", "Anime", "Movies", "Music", "Gaming", "Telemetry", "Other"];
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon: Icon(LucideIcons.arrowLeft, color: isComic ? DesignSystem.comicInk : Colors.white70),
              onPressed: () {
                setState(() {
                  _showCreateRoomForm = false;
                });
              },
            ),
            const SizedBox(width: 8),
            Text(
              "CREATE SPACE",
              style: isComic
                  ? GoogleFonts.bangers(color: DesignSystem.comicInk, fontSize: 24, letterSpacing: 1.5)
                  : GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _roomNameController,
          maxLength: 25,
          style: TextStyle(color: isComic ? DesignSystem.comicInk : Colors.white, fontSize: 13, fontWeight: isComic ? FontWeight.bold : FontWeight.normal),
          decoration: InputDecoration(
            hintText: "Enter Space Name...",
            hintStyle: TextStyle(color: isComic ? Colors.black38 : Colors.white24, fontSize: 12),
            filled: true,
            fillColor: isComic ? Colors.white : Colors.white.withOpacity(0.02),
            border: isComic 
                ? OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: DesignSystem.comicInk, width: 3))
                : OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
            focusedBorder: isComic 
                ? OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: DesignSystem.comicInk, width: 3.5))
                : OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: themeColor)),
            counterText: "",
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedGenre,
          dropdownColor: isComic ? Colors.white : const Color(0xFF1E1E1E),
          style: TextStyle(color: isComic ? DesignSystem.comicInk : Colors.white, fontSize: 13, fontWeight: isComic ? FontWeight.bold : FontWeight.normal),
          decoration: InputDecoration(
            labelText: "Content Genre",
            labelStyle: TextStyle(color: isComic ? DesignSystem.comicInk : Colors.white70, fontSize: 12),
            filled: true,
            fillColor: isComic ? Colors.white : Colors.white.withOpacity(0.02),
            border: isComic 
                ? OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: DesignSystem.comicInk, width: 3))
                : OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
          ),
          items: genres.map((g) {
            return DropdownMenuItem<String>(
              value: g,
              child: Text(g),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedGenre = val;
              });
            }
          },
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Private Space",
              style: isComic
                  ? GoogleFonts.bangers(color: DesignSystem.comicInk, fontSize: 16, letterSpacing: 1)
                  : GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            Switch(
              value: _isPrivateRoom,
              activeColor: isComic ? DesignSystem.comicInk : themeColor,
              activeTrackColor: isComic ? DesignSystem.comicYellow : null,
              onChanged: (val) {
                setState(() {
                  _isPrivateRoom = val;
                });
              },
            ),
          ],
        ),
        if (_isPrivateRoom) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _roomPasswordController,
            obscureText: true,
            style: TextStyle(color: isComic ? DesignSystem.comicInk : Colors.white, fontSize: 13, fontWeight: isComic ? FontWeight.bold : FontWeight.normal),
            decoration: InputDecoration(
              hintText: "Enter room password...",
              hintStyle: TextStyle(color: isComic ? Colors.black38 : Colors.white24, fontSize: 12),
              filled: true,
              fillColor: isComic ? Colors.white : Colors.white.withOpacity(0.02),
              border: isComic 
                  ? OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: DesignSystem.comicInk, width: 3))
                  : OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
              focusedBorder: isComic 
                  ? OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: DesignSystem.comicInk, width: 3.5))
                  : OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: themeColor)),
            ),
          ),
        ],
        const SizedBox(height: 24),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isComic ? DesignSystem.comicYellow : themeColor,
            foregroundColor: isComic ? DesignSystem.comicInk : Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isComic ? 4 : 12),
              side: isComic ? const BorderSide(color: DesignSystem.comicInk, width: 3) : BorderSide.none,
            ),
            elevation: isComic ? 0 : null,
          ),
          onPressed: () {
            if (_roomNameController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Space Name cannot be empty!")),
              );
              return;
            }
            if (_isPrivateRoom && _roomPasswordController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Private room password cannot be empty!")),
              );
              return;
            }
            _connectToSpace(isCreate: true);
          },
          child: Text(
            "Launch Space",
            style: isComic 
                ? GoogleFonts.bangers(fontSize: 18, letterSpacing: 1.5)
                : GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Future<void> _inviteFriends() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _currentRoomId.isEmpty) return;

    final String origin = kIsWeb ? html.window.location.origin : "http://localhost:3000";
    final inviteLink = "$origin/#/happy-watch?room=$_currentRoomId";

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F0F0F),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('happy_watch_rooms').doc(_currentRoomId).snapshots(),
          builder: (context, roomSnap) {
            if (!roomSnap.hasData || !roomSnap.data!.exists) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFFFF8700)));
            }

            final roomData = roomSnap.data!.data() as Map<String, dynamic>;
            final List currentPilots = roomData['pilots'] is List ? roomData['pilots'] : [];
            final pilotUids = currentPilots.map((p) => (p as Map)['uid']?.toString()).whereType<String>().toSet();

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .where('participants', arrayContains: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFFF8700)));
                }

                final chats = snapshot.data!.docs;
                final uniqueMatches = <String, String>{};
                for (var chatDoc in chats) {
                  final chatData = chatDoc.data() as Map<String, dynamic>;
                  if (chatData['isGroup'] == true) continue;
                  final participants = chatData['participants'] as List;
                  final otherUserId = participants.firstWhere((id) => id != user.uid, orElse: () => null);
                  if (otherUserId != null && !pilotUids.contains(otherUserId.toString())) {
                    uniqueMatches[otherUserId.toString()] = chatDoc.id;
                  }
                }
                
                final uniqueUserIds = uniqueMatches.keys.toList();

                if (uniqueUserIds.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        "No active matches to invite. Match with spirits in Séance first!",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(color: Colors.white60),
                      ),
                    ),
                  );
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        "INVITE TO HAPPY WATCH",
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16),
                      ),
                    ),
                    const Divider(color: Colors.white10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: uniqueUserIds.length,
                        itemBuilder: (context, index) {
                          final otherUserId = uniqueUserIds[index];
                          final chatId = uniqueMatches[otherUserId]!;

                          return FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
                            builder: (context, userSnap) {
                              if (!userSnap.hasData || !userSnap.data!.exists) return const SizedBox.shrink();
                              final otherUser = UserModel.fromDocument(userSnap.data!);

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: otherUser.photoUrl.isNotEmpty ? NetworkImage(otherUser.photoUrl) : null,
                                  child: otherUser.photoUrl.isEmpty ? const Icon(LucideIcons.user) : null,
                                ),
                                title: Text(otherUser.name, style: const TextStyle(color: Colors.white)),
                                trailing: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF8700),
                                    foregroundColor: Colors.black,
                                  ),
                                  onPressed: () async {
                                    Navigator.pop(context);
                                    
                                    await FirebaseFirestore.instance
                                        .collection('chats')
                                        .doc(chatId)
                                        .collection('messages')
                                        .add({
                                      'text': "🚀 Join my Happy Watch session! Room ID: $_currentRoomId\nLink: $inviteLink",
                                      'senderId': user.uid,
                                      'timestamp': FieldValue.serverTimestamp(),
                                    });

                                    await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
                                      'lastMessage': "🚀 Invited to Happy Watch space",
                                      'lastMessageAt': FieldValue.serverTimestamp(),
                                    });

                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text("Invite sent to ${otherUser.name}!")),
                                      );
                                    }
                                  },
                                  child: const Text("INVITE"),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _sendChatMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty || _currentRoomId.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _chatController.clear();
    final roomRef = FirebaseFirestore.instance.collection('happy_watch_rooms').doc(_currentRoomId);
    await roomRef.collection('messages').add({
      'text': text,
      'senderId': user.uid,
      'senderName': _currentUser?.name ?? "Pilot",
      'photoUrl': _currentUser?.photoUrl ?? "",
      'timestamp': FieldValue.serverTimestamp(),
    });
    await roomRef.update({'lastActivityAt': FieldValue.serverTimestamp()});
  }

  Future<void> _changeVideo(String videoId) async {
    if (_currentRoomId.isEmpty) return;
    final roomRef = FirebaseFirestore.instance.collection('happy_watch_rooms').doc(_currentRoomId);
    try {
      final doc = await roomRef.get();
      if (doc.exists) {
        final data = doc.data();
        final List queue = data != null && data['queue'] is List ? List.from(data['queue']) : [];
        queue.removeWhere((item) => item['videoId'] == videoId);
        
        await roomRef.update({
          'videoId': videoId,
          'seekTime': 0.0,
          'isPlaying': true,
          'lastUpdated': FieldValue.serverTimestamp(),
          'queue': queue,
          'lastActivityAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint("Error changing video: $e");
    }
  }

  Future<void> _removeVideoFromQueueAtIndex(int index, List<dynamic> currentQueue) async {
    if (_currentRoomId.isEmpty) return;
    final roomRef = FirebaseFirestore.instance.collection('happy_watch_rooms').doc(_currentRoomId);
    final newQueue = List<dynamic>.from(currentQueue);
    if (index >= 0 && index < newQueue.length) {
      newQueue.removeAt(index);
      await roomRef.update({
        'queue': newQueue,
        'lastActivityAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _togglePlayPause(bool currentPlay, double currentSeek) async {
    if (_currentRoomId.isEmpty) return;
    final roomRef = FirebaseFirestore.instance.collection('happy_watch_rooms').doc(_currentRoomId);
    await roomRef.update({
      'isPlaying': !currentPlay,
      'seekTime': currentSeek,
      'lastUpdated': FieldValue.serverTimestamp(),
      'lastActivityAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _seekVideo(double seconds) async {
    if (_currentRoomId.isEmpty) return;
    final roomRef = FirebaseFirestore.instance.collection('happy_watch_rooms').doc(_currentRoomId);
    await roomRef.update({
      'seekTime': seconds,
      'lastUpdated': FieldValue.serverTimestamp(),
      'lastActivityAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _playNextVideo() async {
    if (_currentRoomId.isEmpty) return;
    final roomRef = FirebaseFirestore.instance.collection('happy_watch_rooms').doc(_currentRoomId);
    final doc = await roomRef.get();
    if (!doc.exists) return;
    
    final data = doc.data();
    final List queue = data != null && data['queue'] is List ? List.from(data['queue']) : [];
    if (queue.isNotEmpty) {
      final nextItem = Map<String, dynamic>.from(queue.first);
      final nextVideoId = nextItem['videoId'] as String;
      
      queue.removeAt(0);
      await roomRef.update({
        'videoId': nextVideoId,
        'seekTime': 0.0,
        'isPlaying': true,
        'lastUpdated': FieldValue.serverTimestamp(),
        'queue': queue,
        'lastActivityAt': FieldValue.serverTimestamp(),
      });
    } else {
      await roomRef.update({
        'isPlaying': false,
        'seekTime': 0.0,
        'lastUpdated': FieldValue.serverTimestamp(),
        'lastActivityAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _handleVideoEnded(String endedVideoId) async {
    if (_currentRoomId.isEmpty) return;
    final roomRef = FirebaseFirestore.instance.collection('happy_watch_rooms').doc(_currentRoomId);
    bool shouldFetchRelated = false;
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(roomRef);
        if (!snapshot.exists) return;
        final data = snapshot.data();
        if (data == null) return;
        final currentVideoId = data['videoId'] as String?;
        if (currentVideoId == endedVideoId) {
          final List queue = data['queue'] is List ? List.from(data['queue']) : [];
          if (queue.isNotEmpty) {
            final nextItem = Map<String, dynamic>.from(queue.first);
            final nextVideoId = nextItem['videoId'] as String;
            queue.removeAt(0);
            transaction.update(roomRef, {
              'videoId': nextVideoId,
              'seekTime': 0.0,
              'isPlaying': true,
              'lastUpdated': FieldValue.serverTimestamp(),
              'queue': queue,
              'lastActivityAt': FieldValue.serverTimestamp(),
            });
          } else {
            // Check if we are the host/first pilot to avoid duplicate fetches
            final pilots = data['pilots'] is List ? List.from(data['pilots']) : [];
            final user = FirebaseAuth.instance.currentUser;
            if (pilots.isNotEmpty && pilots.first['uid'] == user?.uid) {
               shouldFetchRelated = true;
            }
            transaction.update(roomRef, {
              'isPlaying': false,
              'seekTime': 0.0,
              'lastUpdated': FieldValue.serverTimestamp(),
              'lastActivityAt': FieldValue.serverTimestamp(),
            });
          }
        }
      });

      if (shouldFetchRelated) {
        _fetchAndPlayRelatedVideos(endedVideoId);
      }
    } catch (e) {
      debugPrint("Error handling video ended transaction: $e");
    }
  }

  Future<void> _fetchAndPlayRelatedVideos(String videoId) async {
    try {
      final yt = YoutubeExplode();
      final video = await yt.videos.get(videoId);
      final words = video.title.split(' ');
      final query = words.take(4).join(' '); // Search for similar keywords
      
      final results = await _searchYoutube(query);
      if (results.isEmpty) return;
      
      results.removeWhere((v) => v['videoId'] == videoId); // Don't play the exact same video
      
      final newQueue = <Map<String, dynamic>>[];
      for (var result in results.take(5)) {
        newQueue.add({
          'videoId': result['videoId'],
          'title': result['title'],
          'addedBy': "AutoPlay 🤖",
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }
      
      if (newQueue.isNotEmpty) {
        final firstItem = newQueue.removeAt(0);
        final roomRef = FirebaseFirestore.instance.collection('happy_watch_rooms').doc(_currentRoomId);
        await roomRef.update({
          'videoId': firstItem['videoId'],
          'seekTime': 0.0,
          'isPlaying': true,
          'lastUpdated': FieldValue.serverTimestamp(),
          'queue': FieldValue.arrayUnion(newQueue),
          'lastActivityAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint("Error auto-playing similar videos: $e");
    }
  }

  Future<void> _addVibeToQueue(String vibeName) async {
    if (_currentRoomId.isEmpty) return;
    final List<Map<String, String>> vibeVideos = [];
    if (vibeName == "Lofi") {
      vibeVideos.addAll([
        {'id': 'jfKfPfyJRdk', 'title': 'Lofi 1'},
        {'id': '4xDzrJKXOOY', 'title': 'Lofi 2'},
        {'id': '1fueZCTYkpA', 'title': 'Lofi 3'},
      ]);
    } else if (vibeName == "Pop Hits") {
      vibeVideos.addAll([
        {'id': 'kTJczUoc26U', 'title': 'Pop Hits 1'},
        {'id': 'nYh-n7EOtMA', 'title': 'Pop Hits 2'},
        {'id': 'fHI8X4OXluQ', 'title': 'Pop Hits 3'},
      ]);
    } else if (vibeName == "Gaming") {
      vibeVideos.addAll([
        {'id': 'D1sZ_vwqwcE', 'title': 'Gaming 1'},
        {'id': 'Uj1ykZWtPYI', 'title': 'Gaming 2'},
        {'id': 'L_jWHffIx5E', 'title': 'Gaming 3'},
      ]);
    } else if (vibeName == "Jazz") {
      vibeVideos.addAll([
        {'id': 'neV3EPgvZ3g', 'title': 'Jazz 1'},
        {'id': 'Dz1Xb3ZgBcc', 'title': 'Jazz 2'},
        {'id': 'RPa3JZcgAwc', 'title': 'Jazz 3'},
      ]);
    } else if (vibeName == "EDM") {
      vibeVideos.addAll([
        {'id': 'ALZHF5UqnU4', 'title': 'EDM 1'},
        {'id': 'J2X5mJ3HDYE', 'title': 'EDM 2'},
        {'id': '0Aiv0gY2rU8', 'title': 'EDM 3'},
      ]);
    } else if (vibeName == "Acoustic") {
      vibeVideos.addAll([
        {'id': 'm7Bc3pLyij0', 'title': 'Acoustic 1'},
        {'id': '4zW9mEaE8J8', 'title': 'Acoustic 2'},
        {'id': 'K1_jD1p0q7Q', 'title': 'Acoustic 3'},
      ]);
    }

    final newQueue = <Map<String, dynamic>>[];
    for (var v in vibeVideos) {
      newQueue.add({
        'videoId': v['id'],
        'title': v['title'],
        'addedBy': _currentUser?.name ?? "Host",
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }

    final roomRef = FirebaseFirestore.instance.collection('happy_watch_rooms').doc(_currentRoomId);
    await roomRef.update({
      'queue': FieldValue.arrayUnion(newQueue),
      'lastActivityAt': FieldValue.serverTimestamp(),
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Added $vibeName vibe to queue!")));
    }
  }

  Future<void> _moveQueueItem(int index, bool moveUp, List<dynamic> queue) async {
    if (_currentRoomId.isEmpty) return;
    
    final newQueue = List<dynamic>.from(queue);
    final int targetIndex = moveUp ? index - 1 : index + 1;
    
    if (targetIndex < 0 || targetIndex >= newQueue.length) return;
    
    final temp = newQueue[index];
    newQueue[index] = newQueue[targetIndex];
    newQueue[targetIndex] = temp;
    
    final roomRef = FirebaseFirestore.instance.collection('happy_watch_rooms').doc(_currentRoomId);
    await roomRef.update({
      'queue': newQueue,
      'lastActivityAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _sendFriendRequest(String targetUid) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final swipeId = "${user.uid}_$targetUid";
    await FirebaseFirestore.instance.collection('swipes').doc(swipeId).set({
      'ownerId': user.uid,
      'targetId': targetUid,
      'type': 'right',
      'timestamp': FieldValue.serverTimestamp(),
    });
    
    final inverseSwipeId = "${targetUid}_${user.uid}";
    final inverseDoc = await FirebaseFirestore.instance.collection('swipes').doc(inverseSwipeId).get();
    if (inverseDoc.exists && inverseDoc.data()?['type'] == 'right') {
      final chatId = (user.uid.compareTo(targetUid) < 0)
          ? '${user.uid}_$targetUid'
          : '${targetUid}_${user.uid}';

      await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
        'participants': [user.uid, targetUid],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessage': "Dialogue unlocked! Say hi in Séance.",
      });

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'friends': FieldValue.arrayUnion([targetUid])
      });
      await FirebaseFirestore.instance.collection('users').doc(targetUid).update({
        'friends': FieldValue.arrayUnion([user.uid])
      });
      
      await _checkProfilePhoto(); // reload local friends state

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("MATCH UNLOCKED! Dialogue created in Séance."), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connection request sent via Séance!"), backgroundColor: Colors.orange),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final mode = GhostTheme.of(context)?.themeMode ?? AppThemeMode.ghosted;
    final themeColor = DesignSystem.getThemeColor(mode);
    final isComic = mode == AppThemeMode.comic;

    if (!_hasProfilePhoto) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: VoidEmptyState(
              message: "GATED PORTAL:\nYOU MUST SUBMIT A REAL PHOTO TO THE ARCHIVES TO ACCESS HAPPY WATCH.",
              actionLabel: "GO TO ARCHIVES",
              onAction: () {
                AppLayout.navigateTo(context, 1);
              },
            ),
          ),
        ),
      );
    }

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
          _isConnected ? 'SPACE: $_currentRoomId' : 'HAPPY WATCH',
          style: isComic 
              ? GoogleFonts.bangers(fontSize: 26, color: DesignSystem.comicInk, letterSpacing: 2)
              : GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 22, color: Colors.white, letterSpacing: 2),
        ),
        centerTitle: true,
        actions: [
          if (_isConnected)
            IconButton(
              icon: Icon(LucideIcons.userPlus, color: isComic ? DesignSystem.comicInk : const Color(0xFFFF8700)),
              onPressed: _inviteFriends,
              tooltip: "INVITE FRIENDS",
            ),
          if (_isConnected)
            IconButton(
              icon: const Icon(LucideIcons.logOut, color: Colors.redAccent),
              onPressed: () async {
                await _leaveRoomIfNeeded();
                setState(() {
                  _isConnected = false;
                  _currentRoomId = "";
                });
              },
              tooltip: "EXIT SPACE",
            ),
          if (!_isConnected)
            IconButton(
              icon: Icon(LucideIcons.settings, color: isComic ? DesignSystem.comicInk : Colors.white70),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
              tooltip: "SETTINGS",
            ),
        ],
      ),
      body: _isConnected
          ? StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('happy_watch_rooms')
                  .doc(_currentRoomId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.active) {
                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_isConnected) {
                        setState(() {
                          _isConnected = false;
                          _currentRoomId = "";
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("The session has expired or been terminated by the host."),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    });
                    return const Center(child: CircularProgressIndicator(color: Color(0xFFFF8700)));
                  }
                } else {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFFFF8700)));
                  }
                }

                final roomData = snapshot.data!.data() as Map<String, dynamic>;
                if (roomData['inactiveTerminated'] == true) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_isConnected) {
                      setState(() {
                        _isConnected = false;
                        _currentRoomId = "";
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("The session has been terminated due to 30 minutes of inactivity."),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  });
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFFF8700)));
                }

                final videoId = roomData['videoId'] as String? ?? 'dQw4w9WgXcQ';
                final isPlaying = roomData['isPlaying'] as bool? ?? true;
                final lastUpdated = roomData['lastUpdated'] as Timestamp?;
                double seekTime = (roomData['seekTime'] as num? ?? 0).toDouble();

                if (isPlaying && lastUpdated != null) {
                  final now = DateTime.now().add(Duration(milliseconds: (_serverClockOffset * 1000).round()));
                  final updatedTime = lastUpdated.toDate();
                  final difference = now.difference(updatedTime).inMilliseconds / 1000.0;
                  if (difference > 0 && difference < 43200) {
                    seekTime += difference;
                  }
                }
                final queue = roomData['queue'] as List<dynamic>? ?? [];
                final pilots = roomData['pilots'] as List<dynamic>? ?? [];
                
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isDesktop = constraints.maxWidth >= 768;
                    final bool isPrimaryPilot = pilots.isNotEmpty && pilots[0]['uid'] == FirebaseAuth.instance.currentUser?.uid;

                    // Expiration calculation (24h lifespan)
                    final roomName = roomData['roomName'] as String? ?? _currentRoomId;
                    final genre = roomData['genre'] as String? ?? "General";
                    final createdAtTimestamp = roomData['createdAt'] as Timestamp?;
                    final warningSent30m = roomData['warningSent30m'] as bool? ?? false;

                    // 30-Minute Inactivity auto-disable check
                    final lastActivityTimestamp = roomData['lastActivityAt'] as Timestamp?;
                    if (lastActivityTimestamp != null) {
                      final lastActivity = lastActivityTimestamp.toDate();
                      final now = DateTime.now().add(Duration(milliseconds: (_serverClockOffset * 1000).round()));
                      final inactiveDiff = now.difference(lastActivity);
                      if (inactiveDiff.inMinutes >= 30) {
                        if (isPrimaryPilot) {
                          _terminateSessionDueToInactivity();
                        }
                      }
                    }

                    int secondsRemaining = 86400; 
                    String timeLeftStr = "24h 00m";
                    bool showWarningBanner = false;

                    if (createdAtTimestamp != null) {
                      final createdTime = createdAtTimestamp.toDate();
                      final difference = DateTime.now().difference(createdTime);
                      final remaining = const Duration(hours: 24) - difference;
                      secondsRemaining = remaining.inSeconds;
                      
                      if (secondsRemaining <= 0) {
                        if (isPrimaryPilot) {
                          _terminateSession();
                        }
                      } else {
                        final hours = remaining.inHours;
                        final minutes = remaining.inMinutes % 60;
                        timeLeftStr = "${hours}h ${minutes.toString().padLeft(2, '0')}m";
                        if (secondsRemaining <= 3600) {
                          showWarningBanner = true;
                        }
                        if (secondsRemaining <= 1800 && !warningSent30m) {
                          if (isPrimaryPilot) {
                            FirebaseFirestore.instance
                                .collection('happy_watch_rooms')
                                .doc(_currentRoomId)
                                .update({'warningSent30m': true});
                            
                            FirebaseFirestore.instance
                                .collection('happy_watch_rooms')
                                .doc(_currentRoomId)
                                .collection('messages')
                                .add({
                              'text': "⏳ WARNING: This space is expiring in less than 30 minutes. Please prepare to transition.",
                              'senderId': 'system',
                              'senderName': 'SYSTEM',
                              'photoUrl': '',
                              'timestamp': FieldValue.serverTimestamp(),
                            });
                          }
                        }
                      }
                    }

                    final playerColumn = WatchPartyPlayerSection(
                      videoId: videoId,
                      isPlaying: isPlaying,
                      seekTime: seekTime,
                      lastUpdated: lastUpdated,
                      themeColor: themeColor,
                      isComic: isComic,
                      isCinematic: _isCinematic,
                      onToggleCinematic: () {
                        if (mounted) setState(() => _isCinematic = !_isCinematic);
                      },
                      onTogglePlay: _togglePlayPause,
                      onSeek: _seekVideo,
                      onChangeVideo: _changeVideo,
                      onSearch: _searchAndShowResults,
                      onEnded: () => _handleVideoEnded(videoId),
                      onSkip: queue.isNotEmpty ? _playNextVideo : null,
                      roomId: _currentRoomId,
                    );

                    final metadataRow = Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: RichText(
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: "SPACE: ",
                                    style: GoogleFonts.outfit(
                                      color: themeColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  TextSpan(
                                    text: "$roomName  |  ",
                                    style: GoogleFonts.outfit(
                                      color: isComic ? DesignSystem.comicInk : Colors.white70,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  TextSpan(
                                    text: "GENRE: ",
                                    style: GoogleFonts.outfit(
                                      color: themeColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  TextSpan(
                                    text: genre,
                                    style: GoogleFonts.outfit(
                                      color: isComic ? DesignSystem.comicInk : Colors.white70,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.clock, size: 14, color: showWarningBanner ? Colors.redAccent : themeColor),
                              const SizedBox(width: 6),
                              Text(
                                "Life left: $timeLeftStr",
                                style: GoogleFonts.outfit(
                                  color: showWarningBanner ? Colors.redAccent : (isComic ? DesignSystem.comicInk : Colors.white70),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );

                    final warningBanner = showWarningBanner
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.redAccent.withOpacity(0.4), width: 1.5),
                            ),
                            child: Row(
                              children: [
                                const Icon(LucideIcons.alertTriangle, color: Colors.redAccent, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "This watch room will expire in less than $timeLeftStr. Please create a new space to continue.",
                                    style: GoogleFonts.outfit(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink();

                    final sidebarColumn = Container(
                      decoration: BoxDecoration(
                        color: isComic ? Colors.white : const Color(0xFF0D0D0D),
                        borderRadius: BorderRadius.circular(16),
                        border: isComic ? Border.all(color: DesignSystem.comicInk, width: 3) : Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Column(
                        children: [
                          TabBar(
                            controller: _tabController,
                            indicatorColor: isComic ? DesignSystem.comicInk : themeColor,
                            labelColor: isComic ? DesignSystem.comicInk : themeColor,
                            unselectedLabelColor: isComic ? Colors.black38 : Colors.white38,
                            tabs: const [
                              Tab(text: "CHAT"),
                              Tab(text: "QUEUE"),
                              Tab(text: "PILOTS"),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                // Chat Room View
                                Column(
                                  children: [
                                    Expanded(
                                      child: StreamBuilder<QuerySnapshot>(
                                        stream: FirebaseFirestore.instance
                                            .collection('happy_watch_rooms')
                                            .doc(_currentRoomId)
                                            .collection('messages')
                                            .orderBy('timestamp', descending: true)
                                            .snapshots(),
                                        builder: (context, msgSnapshot) {
                                          if (!msgSnapshot.hasData) {
                                            return const Center(child: CircularProgressIndicator());
                                          }
                                          final messages = msgSnapshot.data!.docs;
                                          return ListView.builder(
                                            reverse: true,
                                            padding: const EdgeInsets.all(12),
                                            itemCount: messages.length,
                                            itemBuilder: (context, index) {
                                              final data = messages[index].data() as Map<String, dynamic>;
                                              return Container(
                                                margin: const EdgeInsets.symmetric(vertical: 4),
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 14,
                                                      backgroundImage: (data['photoUrl'] as String? ?? '').isNotEmpty 
                                                          ? NetworkImage(data['photoUrl']) 
                                                          : null,
                                                      child: (data['photoUrl'] as String? ?? '').isEmpty 
                                                          ? const Icon(LucideIcons.user, size: 12) 
                                                          : null,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            data['senderName'] ?? "Pilot",
                                                            style: TextStyle(color: isComic ? DesignSystem.comicInk : themeColor, fontWeight: FontWeight.bold, fontSize: 11),
                                                          ),
                                                          Text(
                                                            data['text'] ?? "",
                                                            style: TextStyle(color: isComic ? Colors.black87 : Colors.white, fontSize: 13),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        border: Border(top: isComic ? const BorderSide(color: DesignSystem.comicInk, width: 2) : BorderSide(color: Colors.white.withOpacity(0.05))),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: _chatController,
                                              style: TextStyle(color: isComic ? Colors.black : Colors.white, fontSize: 13),
                                              decoration: InputDecoration(
                                                hintText: "Say something...",
                                                hintStyle: TextStyle(color: isComic ? Colors.black38 : Colors.white24, fontSize: 12),
                                                filled: true,
                                                fillColor: isComic ? Colors.black.withOpacity(0.05) : Colors.white.withOpacity(0.02),
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              ),
                                              onSubmitted: (_) => _sendChatMessage(),
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(LucideIcons.send, color: isComic ? DesignSystem.comicInk : themeColor),
                                            onPressed: _sendChatMessage,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                // Queue Room View
                                Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                      decoration: BoxDecoration(
                                        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
                                      ),
                                      child: Row(
                                        children: [
                                          const Text("VIBES:", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              child: Row(
                                                children: [
                                                  ActionChip(
                                                    label: const Text("Lofi", style: TextStyle(fontSize: 11)),
                                                    backgroundColor: Colors.white.withOpacity(0.05),
                                                    onPressed: () => _addVibeToQueue("Lofi"),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  ActionChip(
                                                    label: const Text("Pop Hits", style: TextStyle(fontSize: 11)),
                                                    backgroundColor: Colors.white.withOpacity(0.05),
                                                    onPressed: () => _addVibeToQueue("Pop Hits"),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  ActionChip(
                                                    label: const Text("Gaming", style: TextStyle(fontSize: 11)),
                                                    backgroundColor: Colors.white.withOpacity(0.05),
                                                    onPressed: () => _addVibeToQueue("Gaming"),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  ActionChip(
                                                    label: const Text("Jazz", style: TextStyle(fontSize: 11)),
                                                    backgroundColor: Colors.white.withOpacity(0.05),
                                                    onPressed: () => _addVibeToQueue("Jazz"),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  ActionChip(
                                                    label: const Text("EDM", style: TextStyle(fontSize: 11)),
                                                    backgroundColor: Colors.white.withOpacity(0.05),
                                                    onPressed: () => _addVibeToQueue("EDM"),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  ActionChip(
                                                    label: const Text("Acoustic", style: TextStyle(fontSize: 11)),
                                                    backgroundColor: Colors.white.withOpacity(0.05),
                                                    onPressed: () => _addVibeToQueue("Acoustic"),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  ActionChip(
                                                    label: const Text("Workout", style: TextStyle(fontSize: 11)),
                                                    backgroundColor: Colors.white.withOpacity(0.05),
                                                    onPressed: () => _addVibeToQueue("Workout"),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: ListView.builder(
                                        padding: const EdgeInsets.all(12),
                                        itemCount: queue.length,
                                        itemBuilder: (context, index) {
                                          final item = queue[index] as Map<String, dynamic>;
                                          final itemVideoId = item['videoId'] as String? ?? '';
                                          return Card(
                                            color: Colors.white.withOpacity(0.03),
                                            margin: const EdgeInsets.symmetric(vertical: 4),
                                            child: ListTile(
                                              leading: const Icon(LucideIcons.video, color: Colors.white38),
                                              title: Text(item['title'] ?? "YouTube Video", style: const TextStyle(color: Colors.white, fontSize: 13)),
                                              subtitle: Text("Added by ${item['addedBy']}", style: const TextStyle(color: Colors.white38, fontSize: 10)),
                                              trailing: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (index > 0)
                                                    IconButton(
                                                      icon: const Icon(LucideIcons.arrowUp, color: Colors.white60, size: 16),
                                                      tooltip: "Move Up",
                                                      onPressed: () => _moveQueueItem(index, true, queue),
                                                    ),
                                                  if (index < queue.length - 1)
                                                    IconButton(
                                                      icon: const Icon(LucideIcons.arrowDown, color: Colors.white60, size: 16),
                                                      tooltip: "Move Down",
                                                      onPressed: () => _moveQueueItem(index, false, queue),
                                                    ),
                                                  IconButton(
                                                    icon: Icon(LucideIcons.play, color: themeColor, size: 16),
                                                    tooltip: "Play & Remove from Queue",
                                                    onPressed: () => _changeVideo(itemVideoId),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(LucideIcons.trash2, color: Colors.redAccent, size: 16),
                                                    tooltip: "Remove",
                                                    onPressed: () => _removeVideoFromQueueAtIndex(index, queue),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                // Pilots Room View
                                ListView.builder(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: pilots.length,
                                  itemBuilder: (context, index) {
                                    final pilot = pilots[index] as Map<String, dynamic>;
                                    final pilotPhoto = pilot['photoUrl'] as String? ?? '';
                                    final pilotUid = pilot['uid'] as String? ?? '';
                                    final user = FirebaseAuth.instance.currentUser;
                                    final isMe = pilotUid == user?.uid;
                                    final isFriend = _currentUser?.friends.contains(pilotUid) ?? false;

                                    if (isMe) {
                                      return ListTile(
                                        leading: CircleAvatar(
                                          backgroundImage: pilotPhoto.isNotEmpty ? NetworkImage(pilotPhoto) : null,
                                          child: pilotPhoto.isEmpty ? const Icon(LucideIcons.user) : null,
                                        ),
                                        title: Text(pilot['name'] ?? "Pilot", style: const TextStyle(color: Colors.white, fontSize: 13)),
                                        trailing: const Text("YOU", style: TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold)),
                                      );
                                    }

                                    if (isFriend) {
                                      return ListTile(
                                        leading: CircleAvatar(
                                          backgroundImage: pilotPhoto.isNotEmpty ? NetworkImage(pilotPhoto) : null,
                                          child: pilotPhoto.isEmpty ? const Icon(LucideIcons.user) : null,
                                        ),
                                        title: Text(pilot['name'] ?? "Pilot", style: const TextStyle(color: Colors.white, fontSize: 13)),
                                        trailing: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(LucideIcons.heart, color: Colors.redAccent, size: 14),
                                            SizedBox(width: 4),
                                            Text("FRIENDS", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      );
                                    }

                                    return FutureBuilder<DocumentSnapshot>(
                                      future: FirebaseFirestore.instance.collection('swipes').doc("${user?.uid}_$pilotUid").get(),
                                      builder: (context, outgoingSnap) {
                                        return FutureBuilder<DocumentSnapshot>(
                                          future: FirebaseFirestore.instance.collection('swipes').doc("${pilotUid}_${user?.uid}").get(),
                                          builder: (context, incomingSnap) {
                                            final hasSent = outgoingSnap.hasData && outgoingSnap.data!.exists && outgoingSnap.data!['type'] == 'right';
                                            final hasReceived = incomingSnap.hasData && incomingSnap.data!.exists && incomingSnap.data!['type'] == 'right';

                                            Widget? trailingWidget;
                                            if (hasSent) {
                                              trailingWidget = const Text("PENDING", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold));
                                            } else if (hasReceived) {
                                              trailingWidget = ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFFFF8700),
                                                  foregroundColor: Colors.black,
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
                                                onPressed: () => _sendFriendRequest(pilotUid),
                                                icon: const Icon(LucideIcons.userCheck, size: 12),
                                                label: const Text("ACCEPT"),
                                              );
                                            } else {
                                              trailingWidget = IconButton(
                                                icon: Icon(LucideIcons.userPlus, color: themeColor, size: 18),
                                                tooltip: "Add Friend via Séance",
                                                onPressed: () => _sendFriendRequest(pilotUid),
                                              );
                                            }

                                            return ListTile(
                                              leading: CircleAvatar(
                                                backgroundImage: pilotPhoto.isNotEmpty ? NetworkImage(pilotPhoto) : null,
                                                child: pilotPhoto.isEmpty ? const Icon(LucideIcons.user) : null,
                                              ),
                                              title: Text(pilot['name'] ?? "Pilot", style: const TextStyle(color: Colors.white, fontSize: 13)),
                                              trailing: trailingWidget,
                                            );
                                          },
                                        );
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );

                    return WatchPartyPlayerSection(
                      videoId: videoId,
                      isPlaying: isPlaying,
                      seekTime: seekTime,
                      lastUpdated: lastUpdated,
                      themeColor: themeColor,
                      isComic: isComic,
                      isCinematic: _isCinematic,
                      onToggleCinematic: () {
                        if (mounted) setState(() => _isCinematic = !_isCinematic);
                      },
                      onTogglePlay: _togglePlayPause,
                      onSeek: _seekVideo,
                      onChangeVideo: _changeVideo,
                      onSearch: _searchAndShowResults,
                      onEnded: () => _handleVideoEnded(videoId),
                      onSkip: queue.isNotEmpty ? _playNextVideo : null,
                      warningBanner: showWarningBanner ? warningBanner : null,
                      metadataRow: metadataRow,
                      sidebarWidget: sidebarColumn,
                      isDesktop: isDesktop,
                      roomId: _currentRoomId,
                    );
                  },
                );
              },
            )
          : Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 120),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      constraints: _isCinematic ? const BoxConstraints(maxWidth: 1200) : const BoxConstraints(maxWidth: 600),
                      padding: _isCinematic ? const EdgeInsets.all(8.0) : const EdgeInsets.all(24.0),
                      decoration: isComic
                          ? BoxDecoration(
                              color: DesignSystem.comicPaper,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: DesignSystem.comicInk, width: 4.0),
                              boxShadow: const [
                                BoxShadow(color: DesignSystem.comicInk, offset: Offset(8, 8)),
                              ],
                            )
                          : BoxDecoration(
                              color: const Color(0xFF0F0F0F),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: Colors.white.withOpacity(0.05)),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40, spreadRadius: 5),
                              ],
                            ),
                      child: _showCreateRoomForm
                          ? _buildCreateRoomForm(isComic, themeColor)
                          : _buildLobbyMain(isComic, themeColor),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class WatchPartyPlayerSection extends StatefulWidget {
  final String videoId;
  final bool isPlaying;
  final double seekTime;
  final Timestamp? lastUpdated;
  final Color themeColor;
  final bool isComic;
  final bool isCinematic;
  final VoidCallback onToggleCinematic;
  final Function(bool, double) onTogglePlay;
  final Function(double) onSeek;
  final Function(String) onChangeVideo;
  final Function(String) onSearch;
  final VoidCallback onEnded;
  final VoidCallback? onSkip;
  
  final Widget? warningBanner;
  final Widget? metadataRow;
  final Widget? sidebarWidget;
  final bool isDesktop;
  final String roomId;

  const WatchPartyPlayerSection({
    super.key,
    required this.videoId,
    required this.isPlaying,
    required this.seekTime,
    required this.lastUpdated,
    required this.themeColor,
    required this.isComic,
    required this.isCinematic,
    required this.onToggleCinematic,
    required this.onTogglePlay,
    required this.onSeek,
    required this.onChangeVideo,
    required this.onSearch,
    required this.onEnded,
    this.onSkip,
    this.warningBanner,
    this.metadataRow,
    this.sidebarWidget,
    this.isDesktop = false,
    required this.roomId,
  });

  @override
  State<WatchPartyPlayerSection> createState() => _WatchPartyPlayerSectionState();
}

class _WatchPartyPlayerSectionState extends State<WatchPartyPlayerSection> {
  late double _localSeekTime;
  double _videoDuration = 600.0;
  final TextEditingController _localUrlController = TextEditingController();

  void _sendReaction(String emoji) {
    final effectiveRoomId = widget.roomId.isNotEmpty ? widget.roomId : widget.videoId;
    if (effectiveRoomId.isEmpty) return;
    
    final user = FirebaseAuth.instance.currentUser;
    final roomRef = FirebaseFirestore.instance.collection('happy_watch_rooms').doc(effectiveRoomId);
    
    final randomY = 0.1 + (Random().nextDouble() * 0.7);
    
    roomRef.collection('reactions').add({
      'emoji': emoji,
      'uid': user?.uid ?? 'anonymous',
      'yPos': randomY,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  void initState() {
    super.initState();
    _syncLocalSeekTime();
  }

  @override
  void didUpdateWidget(covariant WatchPartyPlayerSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId ||
        oldWidget.isPlaying != widget.isPlaying ||
        oldWidget.seekTime != widget.seekTime ||
        oldWidget.lastUpdated != widget.lastUpdated) {
      _syncLocalSeekTime();
    }
  }

  @override
  void dispose() {
    _localUrlController.dispose();
    super.dispose();
  }

  void _syncLocalSeekTime() {
    setState(() {
      _localSeekTime = widget.seekTime;
    });
  }

  String? _extractVideoId(String url) {
    url = url.trim();
    if (url.length == 11) return url;
    RegExp regExp = RegExp(
      r'^.*(youtu.be\/|v\/|u\/\w\/|embed\/|watch\?v=|\&v=)([^#\&\?]*).*',
      caseSensitive: false,
      multiLine: false,
    );
    Match? match = regExp.firstMatch(url);
    if (match != null && match.groupCount >= 2) {
      final id = match.group(2);
      if (id != null && id.length == 11) {
        return id;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final searchAndCinemaRow = Row(
      children: [
        Expanded(
          child: TextField(
            controller: _localUrlController,
            style: TextStyle(color: widget.isComic ? DesignSystem.comicInk : Colors.white, fontSize: 13, fontWeight: widget.isComic ? FontWeight.bold : FontWeight.normal),
            onSubmitted: (val) {
              final query = val.trim();
              if (query.isEmpty) return;
              final extracted = _extractVideoId(query);
              if (extracted != null) {
                widget.onChangeVideo(extracted);
                _localUrlController.clear();
              } else {
                widget.onSearch(query);
              }
            },
            decoration: InputDecoration(
              hintText: widget.isComic ? "Search YouTube..." : "Search or Paste YouTube Link...",
              hintStyle: TextStyle(color: widget.isComic ? Colors.black38 : Colors.white24, fontSize: 12),
              filled: true,
              fillColor: widget.isComic ? Colors.white : Colors.white.withOpacity(0.02),
              border: widget.isComic 
                  ? OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: DesignSystem.comicInk, width: 2))
                  : OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              focusedBorder: widget.isComic 
                  ? OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: DesignSystem.comicInk, width: 2.5))
                  : OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: widget.themeColor)),
              prefixIcon: Icon(LucideIcons.search, size: 16, color: widget.isComic ? DesignSystem.comicInk : Colors.white54),
              suffixIcon: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: widget.isComic ? DesignSystem.comicYellow : widget.themeColor,
                  borderRadius: BorderRadius.circular(6),
                  border: widget.isComic ? Border.all(color: DesignSystem.comicInk, width: 1.5) : null,
                ),
                child: IconButton(
                  icon: Icon(
                    LucideIcons.search,
                    size: 16,
                    color: widget.isComic ? DesignSystem.comicInk : Colors.black,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () {
                    final query = _localUrlController.text.trim();
                    if (query.isEmpty) return;
                    final extracted = _extractVideoId(query);
                    if (extracted != null) {
                      widget.onChangeVideo(extracted);
                      _localUrlController.clear();
                    } else {
                      widget.onSearch(query);
                    }
                  },
                ),
              ),
              contentPadding: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 12),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            color: widget.isCinematic ? Colors.redAccent.withOpacity(0.1) : widget.themeColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: widget.isCinematic ? Colors.redAccent : widget.themeColor, width: 2),
          ),
          child: TextButton.icon(
            icon: Icon(widget.isCinematic ? LucideIcons.minimize : LucideIcons.maximize, color: widget.isCinematic ? Colors.redAccent : widget.themeColor, size: 16),
            label: Text(widget.isCinematic ? "EXIT CINEMA" : "CINEMA MODE", style: TextStyle(color: widget.isCinematic ? Colors.redAccent : widget.themeColor, fontWeight: FontWeight.bold, fontSize: 12)),
            onPressed: widget.onToggleCinematic,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ],
    );

    final videoPlayerWidget = AspectRatio(
      aspectRatio: 16 / 9,
      child: YoutubePlayerWidget(
        videoId: widget.videoId,
        isPlaying: widget.isPlaying,
        seekTime: _localSeekTime,
        lastUpdated: widget.lastUpdated?.toDate(),
        onEnded: widget.onEnded,
        onDurationChanged: (duration) {
          if (mounted) {
            setState(() {
              _videoDuration = duration;
            });
          }
        },
        onTimeUpdated: (currentTime) {
          if (mounted) {
            setState(() {
              _localSeekTime = currentTime;
            });
          }
        },
      ),
    );

    final controlsWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(
                  widget.isPlaying ? LucideIcons.pause : LucideIcons.play,
                  color: widget.themeColor,
                ),
                onPressed: () => widget.onTogglePlay(widget.isPlaying, _localSeekTime),
              ),
              if (widget.onSkip != null) ...[
                IconButton(
                  icon: const Icon(LucideIcons.skipForward, color: Colors.white, size: 20),
                  tooltip: "SKIP VIDEO",
                  onPressed: widget.onSkip,
                ),
              ],
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: widget.themeColor,
                    inactiveTrackColor: Colors.white10,
                    thumbColor: widget.themeColor,
                    trackHeight: 2.0,
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10.0),
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                  ),
                  child: Slider(
                    value: _localSeekTime.clamp(0.0, _videoDuration > 0 ? _videoDuration : 1.0),
                    min: 0,
                    max: _videoDuration > 0 ? _videoDuration : 1.0,
                    onChanged: (val) {
                      setState(() {
                        _localSeekTime = val;
                      });
                    },
                    onChangeEnd: widget.onSeek,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Text(
                  "${_formatDuration(Duration(seconds: _localSeekTime.toInt()))} / ${_formatDuration(Duration(seconds: _videoDuration.toInt()))}",
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final emoji in ['🔥', '❤️', '😂', '👏'])
                    InkWell(
                      onTap: () => _sendReaction(emoji),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Text(emoji, style: const TextStyle(fontSize: 16)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    final leftContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.isCinematic && widget.warningBanner != null) widget.warningBanner!,
        if (!widget.isCinematic && widget.metadataRow != null) widget.metadataRow!,
        searchAndCinemaRow,
        const SizedBox(height: 12),
        videoPlayerWidget,
        if (!widget.isDesktop || widget.sidebarWidget == null || widget.isCinematic) ...[
          const SizedBox(height: 8),
          controlsWidget,
        ]
      ],
    );

    final sidebarWithReactions = widget.sidebarWidget != null
        ? Stack(
            children: [
              widget.sidebarWidget!,
              Positioned.fill(
                child: LiveReactionsOverlay(roomId: widget.roomId.isNotEmpty ? widget.roomId : widget.videoId),
              ),
            ],
          )
        : null;

    if (widget.isCinematic) {
      return SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 120),
        child: leftContent,
      );
    }

    if (widget.isDesktop && sidebarWithReactions != null) {
      return Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 120),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: leftContent),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      Expanded(child: sidebarWithReactions),
                      const SizedBox(height: 8),
                      controlsWidget,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      return SingleChildScrollView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 120),
        child: Column(
          children: [
            leftContent,
            const SizedBox(height: 16),
            if (sidebarWithReactions != null) SizedBox(height: 350, child: sidebarWithReactions),
          ],
        ),
      );
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class LiveReactionsOverlay extends StatefulWidget {
  final String roomId;
  const LiveReactionsOverlay({super.key, required this.roomId});

  @override
  State<LiveReactionsOverlay> createState() => _LiveReactionsOverlayState();
}

class _LiveReactionsOverlayState extends State<LiveReactionsOverlay> {
  final List<Map<String, dynamic>> _activeReactions = [];
  final Set<String> _processedIds = {};
  StreamSubscription? _sub;
  
  @override
  void initState() {
    super.initState();
    _listenToReactions();
  }
  
  void _listenToReactions() {
    _sub = FirebaseFirestore.instance
        .collection('happy_watch_rooms')
        .doc(widget.roomId)
        .collection('reactions')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final id = change.doc.id;
          if (_processedIds.contains(id)) continue;
          _processedIds.add(id);

          final data = change.doc.data();
          if (data != null) {
            // Check if it's too old
            final ts = data['timestamp'] as Timestamp?;
            if (ts != null) {
              final diff = DateTime.now().difference(ts.toDate());
              if (diff.inSeconds > 10) continue; // Skip old reactions on initial load
            }
            
            final emoji = data['emoji'] as String? ?? '❤️';
            final yPos = (data['yPos'] as num?)?.toDouble() ?? 0.5;
            final id = change.doc.id;
            
            if (mounted) {
              setState(() {
                _activeReactions.add({
                  'id': id,
                  'emoji': emoji,
                  'xPos': yPos, // use yPos from DB as xPos for random horizontal placement
                });
              });
              
              Future.delayed(const Duration(seconds: 4), () {
                if (mounted) {
                  setState(() {
                    _activeReactions.removeWhere((r) => r['id'] == id);
                  });
                }
              });
            }
          }
        }
      }
    });
  }
  
  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: _activeReactions.map((reaction) {
          return AnimatedReaction(
            key: ValueKey(reaction['id']),
            emoji: reaction['emoji'],
            xPos: reaction['xPos'],
          );
        }).toList(),
      ),
    );
  }
}

class AnimatedReaction extends StatefulWidget {
  final String emoji;
  final double xPos;
  
  const AnimatedReaction({super.key, required this.emoji, required this.xPos});
  
  @override
  State<AnimatedReaction> createState() => _AnimatedReactionState();
}

class _AnimatedReactionState extends State<AnimatedReaction> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _yAnim;
  late Animation<double> _opacityAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _yAnim = Tween<double>(begin: 1.0, end: -0.2).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _opacityAnim = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 60),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_controller);
    _scaleAnim = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 0.5, end: 1.5), weight: 20),
      TweenSequenceItem(tween: Tween<double>(begin: 1.5, end: 1.0), weight: 80),
    ]).animate(_controller);
    
    _controller.forward();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Align(
          alignment: FractionalOffset(widget.xPos, _yAnim.value),
          child: Opacity(
            opacity: _opacityAnim.value,
            child: Transform.scale(
              scale: _scaleAnim.value,
              child: Text(widget.emoji, style: const TextStyle(fontSize: 48)),
            ),
          ),
        );
      },
    );
  }
}
