import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'dart:async';
import 'dart:convert';

class YoutubePlayerWidget extends StatefulWidget {
  final String videoId;
  final bool isPlaying;
  final double seekTime;
  final DateTime? lastUpdated;
  final VoidCallback? onEnded;
  final ValueChanged<double>? onDurationChanged;
  final ValueChanged<double>? onTimeUpdated;
  final bool enableNativeControls;

  const YoutubePlayerWidget({
    super.key,
    required this.videoId,
    required this.isPlaying,
    required this.seekTime,
    this.lastUpdated,
    this.onEnded,
    this.onDurationChanged,
    this.onTimeUpdated,
    this.enableNativeControls = false,
  });

  @override
  State<YoutubePlayerWidget> createState() => _YoutubePlayerWidgetState();
}

class _YoutubePlayerWidgetState extends State<YoutubePlayerWidget> {
  late String _viewId;
  html.IFrameElement? _iframe;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _clickSubscription;
  StreamSubscription? _touchSubscription;
  bool _audioUnlocked = false;
  bool _isReady = false;
  int? _playerState;
  DateTime? _lastSeekTime;
  double? _syncPosition;
  DateTime? _syncTime;
  bool _hasEndedTriggered = false;

  double get _targetTime {
    if (_syncTime == null || _syncPosition == null) return widget.seekTime;
    if (!widget.isPlaying) return _syncPosition!;
    final diff = DateTime.now().difference(_syncTime!).inMilliseconds / 1000.0;
    return _syncPosition! + diff;
  }

  void _syncPlayerToWidget() {
    if (!_isReady) return;
    final target = widget.seekTime;
    _sendPlayerCommand('seekTo', args: [target, true]);
    if (widget.isPlaying) {
      _sendPlayerCommand('playVideo');
    } else {
      _sendPlayerCommand('pauseVideo');
      Future.delayed(const Duration(milliseconds: 150), () {
        _sendPlayerCommand('pauseVideo');
      });
    }
    _syncPosition = target;
    _syncTime = DateTime.now();
    _lastSeekTime = DateTime.now();
  }

  void _setupAudioUnlock() {
    _clickSubscription = html.window.onClick.listen((_) => _unlockAudio());
    _touchSubscription = html.window.onTouchStart.listen((_) => _unlockAudio());
  }

  void _unlockAudio() {
    if (_audioUnlocked) return;
    _audioUnlocked = true;
    _clickSubscription?.cancel();
    _touchSubscription?.cancel();
    if (_isReady) {
      _sendPlayerCommand('unMute');
      if (widget.isPlaying) {
        _sendPlayerCommand('playVideo');
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _setupAudioUnlock();
    _viewId = 'youtube-player-${DateTime.now().microsecondsSinceEpoch}';
    _registerView();
    _messageSubscription = html.window.onMessage.listen((event) {
      try {
        final data = event.data;
        Map<String, dynamic>? msgMap;
        if (data is String) {
          msgMap = jsonDecode(data) as Map<String, dynamic>?;
        } else if (data is Map) {
          msgMap = Map<String, dynamic>.from(data);
        }

        if (msgMap != null) {
          final eventName = msgMap['event'];
          final info = msgMap['info'];

          if (eventName == 'initialDelivery' || eventName == 'onReady' || eventName == 'infoDelivery') {
            if (!_isReady) {
              setState(() {
                _isReady = true;
              });
              _sendListeningCommand();
              _syncPlayerToWidget();
            }
          }

          if (eventName == 'onStateChange') {
            final int? stateVal = info is int ? info : (info is num ? info.toInt() : null);
            _playerState = stateVal;
            if (stateVal == 0 && !_hasEndedTriggered) {
              _hasEndedTriggered = true;
              widget.onEnded?.call();
            } else if (stateVal != 0) {
              _hasEndedTriggered = false;
            }
          }

          if (info is Map) {
            // Extract playerState if available
            if (info['playerState'] != null) {
              final val = info['playerState'];
              final stateVal = val is int ? val : (val is num ? val.toInt() : null);
              _playerState = stateVal;
              if (stateVal == 0 && !_hasEndedTriggered) {
                _hasEndedTriggered = true;
                widget.onEnded?.call();
              } else if (stateVal != 0) {
                _hasEndedTriggered = false;
              }
            }

            final double? duration = info['duration'] != null ? (info['duration'] as num).toDouble() : null;
            final double? currentTime = info['currentTime'] != null ? (info['currentTime'] as num).toDouble() : null;

            if (duration != null && widget.onDurationChanged != null) {
              widget.onDurationChanged!(duration);
            }
            if (currentTime != null) {
              if (widget.onTimeUpdated != null) {
                widget.onTimeUpdated!(currentTime);
              }

              // Drift correction
              if (widget.isPlaying && _playerState == 1) {
                final target = _targetTime;
                final diff = (currentTime - target).abs();
                final canSeek = _lastSeekTime == null ||
                    DateTime.now().difference(_lastSeekTime!).inSeconds >= 3;
                if (diff > 2.0 && canSeek) {
                  _sendPlayerCommand('seekTo', args: [target, true]);
                  _syncPosition = target;
                  _syncTime = DateTime.now();
                  _lastSeekTime = DateTime.now();
                }
              }
            }
          }
        }
      } catch (e) {
        // ignore
      }
    });
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _clickSubscription?.cancel();
    _touchSubscription?.cancel();
    super.dispose();
  }

  void _registerView() {
    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
      final iframe = html.IFrameElement()
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.pointerEvents = widget.enableNativeControls ? 'auto' : 'none'
        ..allow = 'autoplay; encrypted-media; picture-in-picture';
      
      _iframe = iframe;
      _iframe!.onLoad.listen((_) {
        _sendListeningCommand();
      });
      _updateIFrameSrc();
      return iframe;
    });
  }

  void _updateIFrameSrc() {
    if (_iframe == null) return;
    final start = widget.seekTime.round();
    final autoplay = widget.isPlaying ? 1 : 0;
    final controls = widget.enableNativeControls ? 1 : 0;
    
    // YouTube embed URL with autoplay, start time, controls, API enabled, and origin
    final origin = html.window.location.origin;
    final src = 'https://www.youtube.com/embed/${widget.videoId}?autoplay=$autoplay&start=$start&enablejsapi=1&rel=0&controls=$controls&mute=1&origin=${Uri.encodeComponent(origin)}';
    if (_iframe!.src != src) {
      _iframe!.src = src;
    }
  }

  void _sendPlayerCommand(String func, {List<dynamic>? args}) {
    if (_iframe == null) return;
    try {
      final message = jsonEncode({
        'event': 'command',
        'func': func,
        'args': args ?? [],
      });
      _iframe!.contentWindow?.postMessage(message, '*');
    } catch (e) {
      debugPrint("Error sending player command: $e");
    }
  }

  void _sendListeningCommand() {
    if (_iframe == null) return;
    try {
      final message = jsonEncode({
        'event': 'listening',
        'id': 1,
        'channel': 'widget',
      });
      _iframe!.contentWindow?.postMessage(message, '*');
    } catch (e) {
      debugPrint("Error sending listening command: $e");
    }
  }

  @override
  void didUpdateWidget(covariant YoutubePlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      setState(() {
        _isReady = false;
        _playerState = null;
        _syncPosition = null;
        _syncTime = null;
        _hasEndedTriggered = false;
      });
      _updateIFrameSrc();
    } else {
      if (!_isReady) return;

      if (oldWidget.isPlaying != widget.isPlaying) {
        if (widget.isPlaying) {
          _sendPlayerCommand('playVideo');
        } else {
          _sendPlayerCommand('pauseVideo');
        }
        // Update sync position/time
        _syncPosition = _targetTime;
        _syncTime = DateTime.now();
      }
      if (oldWidget.lastUpdated != widget.lastUpdated) {
        if (_syncPosition == null || (widget.seekTime - _syncPosition!).abs() > 1.5) {
          _sendPlayerCommand('seekTo', args: [widget.seekTime, true]);
          _syncPosition = widget.seekTime;
          _syncTime = DateTime.now();
          _lastSeekTime = DateTime.now();
          
          // Enforce pause if not playing to prevent YouTube autoplay bugs on seek
          if (!widget.isPlaying) {
            Future.delayed(const Duration(milliseconds: 150), () {
              _sendPlayerCommand('pauseVideo');
            });
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF8700).withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8700).withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          fit: StackFit.expand,
          children: [
            HtmlElementView(viewType: _viewId),
            if (!widget.enableNativeControls)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  _unlockAudio();
                  if (_isReady && widget.isPlaying) {
                    _sendPlayerCommand('playVideo');
                  }
                },
                child: const SizedBox.expand(),
              ),
          ],
        ),
      ),
    );
  }
}
