import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class CompressionService {
  /// Compresses an image to be ideally under 500KB.
  static Future<Uint8List> compressImage(Uint8List bytes) async {
    if (kIsWeb) {
       // Web compression is limited without heavy JS interop.
       // We assume the ImagePicker's 'imageQuality' handled basic compression.
       return bytes;
    }
    
    try {
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minHeight: 1080,
        minWidth: 1080,
        quality: 70,
      );
      return compressed;
    } catch (e) {
      print("Compression Error: $e");
      return bytes;
    }
  }

  /// Note: Video compression is computationally expensive for a Flutter app.
  /// We primarily rely on duration limits (10s) and file size rejection.
}
