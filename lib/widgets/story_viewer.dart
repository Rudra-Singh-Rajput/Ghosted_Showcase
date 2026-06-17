import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StoryViewer extends StatefulWidget {
  final List<DocumentSnapshot> stories;
  final int initialIndex;

  const StoryViewer({
    super.key,
    required this.stories,
    required this.initialIndex,
  });

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late AnimationController _progressController;
  bool _isPaused = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStory();
      }
    });

    _showStory();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _showStory() async {
    _timer?.cancel();
    _progressController.reset();

    _progressController.forward();
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _showStory();
    } else {
      Navigator.pop(context);
    }
  }

  void _prevStory() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _showStory();
    } else {
      // Restart current
      _showStory();
    }
  }

  void _pause() {
    if (_isPaused) return;
    setState(() {
      _isPaused = true;
    });
    _progressController.stop();
  }

  void _resume() {
    if (!_isPaused) return;
    setState(() {
      _isPaused = false;
    });
    _progressController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final storyDoc = widget.stories[_currentIndex];
    final storyData = storyDoc.data() as Map<String, dynamic>;
    final String userPhotoUrl = storyData['userPhotoUrl'] ?? '';
    final String userName = storyData['userName'] ?? 'Anonymous';
    final String mediaUrl = storyData['mediaUrl'] ?? '';
    final String text = storyData['text'] ?? '';

    
    final Timestamp? timestamp = storyData['timestamp'] as Timestamp?;
    String timeAgo = '';
    if (timestamp != null) {
      final diff = DateTime.now().difference(timestamp.toDate());
      if (diff.inHours > 0) {
        timeAgo = '${diff.inHours}h ago';
      } else {
        timeAgo = '${diff.inMinutes}m ago';
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onLongPressStart: (_) => _pause(),
        onLongPressEnd: (_) => _resume(),
        onTapDown: (details) {
          final width = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < width / 3) {
            _prevStory();
          } else {
            _nextStory();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Media Image
            if (mediaUrl.isNotEmpty)
              Image.network(
                mediaUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFFF8000)));
                },
              )
            else
              Container(
                color: const Color(0xFF0F0F0F),
                child: const Center(
                  child: Icon(LucideIcons.ghost, size: 72, color: Colors.white10),
                ),
              ),

            // Top Gradient Shadow
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 140,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black87, Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // Bottom Gradient Shadow
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 180,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black87],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // Progress Bar Indicators
            Positioned(
              top: 44,
              left: 12,
              right: 12,
              child: Row(
                children: List.generate(
                  widget.stories.length,
                  (index) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: AnimatedBuilder(
                            animation: _progressController,
                            builder: (context, child) {
                              double val = 0.0;
                              if (index < _currentIndex) {
                                val = 1.0;
                              } else if (index == _currentIndex) {
                                val = _progressController.value;
                              }
                              return LinearProgressIndicator(
                                value: val,
                                backgroundColor: Colors.white.withOpacity(0.2),
                                color: const Color(0xFFFF8000),
                                minHeight: 3,
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // User Info Header
            Positioned(
              top: 60,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: userPhotoUrl.isNotEmpty ? NetworkImage(userPhotoUrl) : null,
                    backgroundColor: Colors.white10,
                    child: userPhotoUrl.isEmpty ? const Icon(LucideIcons.user, size: 18, color: Colors.white30) : null,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        userName,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 13, letterSpacing: 1),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timeAgo,
                        style: GoogleFonts.inter(color: Colors.white38, fontSize: 9),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(LucideIcons.x, color: Colors.white70, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Text Description Overlay (Center Bottom)
            if (text.isNotEmpty)
              Positioned(
                bottom: 80,
                left: 24,
                right: 24,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ),

          ],
        ),
      ),
    );
  }
}
