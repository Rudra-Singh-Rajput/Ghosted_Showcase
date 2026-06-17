
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import './cloudinary_service.dart';

class VoiceService {
  static final _record = AudioRecorder();
  static String? _currentPath;

  static Future<void> startRecording() async {
    print("VoiceService: Requesting permission...");
    if (await _record.hasPermission()) {
      print("VoiceService: Permission granted.");
      if (kIsWeb) {
        _currentPath = null; 
      } else {
        final directory = await getTemporaryDirectory();
        _currentPath = '${directory.path}/wispr_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      }
      
      const config = RecordConfig(
        bitRate: 32000, // Low bitrate for sub-15s speed
        numChannels: 1, // Mono
      );
      print("VoiceService: Starting recorder (32kbps Mono)...");
      await _record.start(config, path: _currentPath ?? '');
    } else {
      print("VoiceService: PERMISSION DENIED");
      throw Exception("Microphone permission denied. Enable it in your browser settings to Whisper.");
    }
  }

  static Future<String?> stopAndUpload({Function(double)? onProgress}) async {
    print("VoiceService: Stopping recording...");
    final path = await _record.stop().timeout(const Duration(seconds: 10), onTimeout: () {
      print("VoiceService: Record stop HUNG");
      return null;
    });
    if (path == null) {
      print("VoiceService: Stop returned null path or timed out.");
      return null;
    }
    print("VoiceService: Recorded to $path");

    try {
      final Uint8List bytes;
      if (kIsWeb) {
        print("VoiceService: Fetching blob from $path");
        final response = await http.get(Uri.parse(path));
        if (response.statusCode != 200) {
          throw Exception("Failed to fetch recording blob: ${response.statusCode}");
        }
        bytes = response.bodyBytes;
      } else {
        // On native platforms, you would use File(path).readAsBytes()
        // but since this is optimized for Web, we avoid dart:io imports.
        throw Exception("Native file reading not implemented in Web build.");
      }

      if (bytes.isEmpty) throw Exception("Recorded bytes are empty.");
      
      print("VoiceService: Uploading ${bytes.length} bytes to Cloudinary...");

      if (onProgress != null) onProgress(0.5); // Mock progress

      final url = await CloudinaryService.uploadMedia(bytes, 'wispr_voice').timeout(
        const Duration(seconds: 120),
        onTimeout: () => throw Exception("VOICE UPLOAD TIMED OUT: Connection too slow."),
      );
      
      if (onProgress != null) onProgress(1.0);
      
      print("VoiceService: Upload complete. URL: $url");
      return url;
    } catch (e) {
      print("VoiceService ERROR: $e");
      return null;
    }
  }
  
  static void dispose() {
    _record.dispose();
  }
}
