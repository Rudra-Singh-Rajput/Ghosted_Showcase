import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/design_system.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb

class ReelPlayer extends StatefulWidget {
  final String url;
  final bool isFullScreen;
  const ReelPlayer({super.key, required this.url, this.isFullScreen = false});

  @override
  State<ReelPlayer> createState() => _ReelPlayerState();
}

class _ReelPlayerState extends State<ReelPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _isInitialized = true);
          _controller.setLooping(true);
          
          // Browsers block autoplay with sound. Start muted on web to ensure it plays.
          if (kIsWeb) {
            _controller.setVolume(0);
          } else {
            _controller.setVolume(widget.isFullScreen ? 1 : 0);
          }
          
          _controller.play();
        }
      }).catchError((error) {
        print("VIDEO PLAYER ERROR: $error");
        if (mounted) setState(() => _isInitialized = false);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Container(
        height: widget.isFullScreen ? double.infinity : 400,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: widget.isFullScreen ? null : BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: DesignSystem.ghostOrange, strokeWidth: 2),
            const SizedBox(height: 12),
            Text("TUNING TO ECHOES...", style: GoogleFonts.inconsolata(color: Colors.white24, fontSize: 10, letterSpacing: 2)),
            const SizedBox(height: 20),
            if (widget.url.isEmpty) 
              Text("NO SOURCE SIGNAL", style: GoogleFonts.inconsolata(color: Colors.redAccent, fontSize: 8))
            else
              Text("SOURCE: ${widget.url.split('/').last}", style: GoogleFonts.inconsolata(color: Colors.white10, fontSize: 8)),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _controller.value.isPlaying ? _controller.pause() : _controller.play();
        });
      },
      child: ClipRRect(
        borderRadius: widget.isFullScreen ? BorderRadius.zero : BorderRadius.circular(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              ),
            ),
            if (!_controller.value.isPlaying)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.play, color: Colors.white, size: 40),
              ),
            Positioned(
              bottom: 20,
              right: 20,
              child: IconButton(
                icon: Icon(
                  _controller.value.volume > 0 ? LucideIcons.volume2 : LucideIcons.volumeX,
                  color: Colors.white.withOpacity(0.5),
                  size: 24,
                ),
                onPressed: () {
                  setState(() {
                    _controller.setVolume(_controller.value.volume > 0 ? 0 : 1);
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

