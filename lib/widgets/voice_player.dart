import 'package:flutter/material.dart';
import 'dart:js_interop';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';

@JS('Audio')
extension type WebAudio._(JSObject _) implements JSObject {
  external WebAudio(String url);
  external void play();
  external void pause();
  external double get duration;
  external double get currentTime;
  external set currentTime(double value);
  external bool get paused;
  external void addEventListener(String type, JSFunction listener);
  external void removeEventListener(String type, JSFunction listener);
}

class VoicePlayer extends StatefulWidget {
  final String url;
  const VoicePlayer({super.key, required this.url});

  @override
  State<VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<VoicePlayer> {
  late WebAudio _player;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  JSFunction? _timeUpdateListener;
  JSFunction? _endedListener;
  JSFunction? _durationChangeListener;

  @override
  void initState() {
    super.initState();
    
    // FOR WEB COMPATIBILITY: Force MP3 delivery from Cloudinary
    final mp3Url = widget.url.replaceFirst('/upload/', '/upload/f_mp3/');
    _player = WebAudio(mp3Url);

    _timeUpdateListener = (() {
      if (mounted) {
        setState(() {
          _position = Duration(milliseconds: (_player.currentTime * 1000).toInt());
        });
      }
    }).toJS;

    _endedListener = (() {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
          _player.currentTime = 0;
        });
      }
    }).toJS;

    _durationChangeListener = (() {
      if (mounted) {
        setState(() {
          final d = _player.duration;
          if (!d.isNaN && d.isFinite) {
            _duration = Duration(milliseconds: (d * 1000).toInt());
          }
        });
      }
    }).toJS;

    _player.addEventListener('timeupdate', _timeUpdateListener!);
    _player.addEventListener('ended', _endedListener!);
    _player.addEventListener('durationchange', _durationChangeListener!);
  }

  @override
  void dispose() {
    _player.pause();
    if (_timeUpdateListener != null) {
      _player.removeEventListener('timeupdate', _timeUpdateListener!);
    }
    if (_endedListener != null) {
      _player.removeEventListener('ended', _endedListener!);
    }
    if (_durationChangeListener != null) {
      _player.removeEventListener('durationchange', _durationChangeListener!);
    }
    super.dispose();
  }

  void _togglePlay() {
    if (_isPlaying) {
      _player.pause();
    } else {
      _player.play();
    }
    setState(() => _isPlaying = !_isPlaying);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Color(0xFFFF8700), shape: BoxShape.circle),
              child: Icon(_isPlaying ? LucideIcons.pause : LucideIcons.play, color: Colors.black, size: 16),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: _duration.inMilliseconds > 0 ? _position.inMilliseconds / _duration.inMilliseconds : 0,
                  backgroundColor: Colors.white10,
                  color: const Color(0xFFFF8700),
                  minHeight: 2,
                ),
                const SizedBox(height: 4),
                Text(
                  "VOICE WHISPER",
                  style: GoogleFonts.outfit(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

