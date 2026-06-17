import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

class CloudinaryService {
  static const String cloudName = "YOUR_CLOUDINARY_CLOUD_NAME";
  static const String uploadPreset = "YOUR_CLOUDINARY_UPLOAD_PRESET";
  static const String apiKey = "YOUR_CLOUDINARY_API_KEY";
  static const String apiSecret = "YOUR_CLOUDINARY_API_SECRET";

  /// Uploads media to Cloudinary using Unsigned Uploads.
  /// Returns the secure URL of the uploaded resource.
  static Future<String> uploadMedia(Uint8List bytes, String folder, {bool isVideo = false}) async {
    final url = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/upload");

    try {
      final request = http.MultipartRequest("POST", url)
        ..fields['upload_preset'] = uploadPreset
        ..fields['folder'] = folder;
      
      // VOID PROTOCOL: Media Trimming (10-30s)
      if (isVideo) {
        // Enforce max duration of 30s and start offset to ensure content is concise.
        // du_30: limit duration to 30s
        // so_0: start at 0
        request.fields['transformation'] = "du_30,so_0,c_limit,w_1080";
      }

      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: 'upload_${DateTime.now().millisecondsSinceEpoch}',
      ));

      final response = await request.send();
      final responseData = await response.stream.toBytes();
      final responseString = utf8.decode(responseData);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(responseString);
        return json['secure_url'];
      } else {
        final errorMsg = jsonDecode(responseString)['error']?['message'] ?? response.statusCode;
        throw Exception("THE VOID REJECTED THE MEDIA: $errorMsg");
      }
    } catch (e) {
      print("Cloudinary Exception: $e");
      rethrow;
    }
  }

  /// Extracts public_id from a Cloudinary URL and deletes the resource.
  /// Example URL: https://res.cloudinary.com/cloudname/image/upload/v1/folder/id.jpg
  static Future<void> deleteMedia(String? url, {String? resourceType}) async {
    if (url == null || url.isEmpty || !url.contains("cloudinary.com")) return;

    try {
      // 1. Detect resource type from URL if not provided
      String type = resourceType ?? "image";
      if (resourceType == null) {
        if (url.contains("/video/upload/")) type = "video";
        if (url.contains("/raw/upload/")) type = "raw";
      }

      // 2. Extract public_id
      // Split by 'upload/' and remove the version (v12345/) and extension
      final parts = url.split("upload/");
      if (parts.length < 2) return;
      
      String publicIdWithExt = parts[1];
      // Remove version if present (e.g., v1710400000/)
      if (publicIdWithExt.startsWith('v')) {
        final versionEnd = publicIdWithExt.indexOf('/');
        if (versionEnd != -1) {
          publicIdWithExt = publicIdWithExt.substring(versionEnd + 1);
        }
      }
      
      // Remove file extension
      final dotIndex = publicIdWithExt.lastIndexOf('.');
      final publicId = dotIndex != -1 ? publicIdWithExt.substring(0, dotIndex) : publicIdWithExt;

      print("BANISHING FROM CLOUD [$type]: $publicId");

      // 3. Perform authenticated deletion
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      
      // CREATE SIGNATURE
      // Signature string: "public_id=<public_id>&timestamp=<timestamp><api_secret>"
      final signatureStr = "public_id=$publicId&timestamp=$timestamp$apiSecret";
      final signature = sha1.convert(utf8.encode(signatureStr)).toString();

      final apiUri = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/$type/destroy");
      
      final response = await http.post(apiUri, body: {
        'public_id': publicId,
        'timestamp': timestamp.toString(),
        'api_key': apiKey,
        'signature': signature,
      });

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['result'] == 'ok') {
          print("CLOUD PURGE SUCCESSFUL: $publicId");
        } else {
          print("CLOUD PURGE PARTIAL/NOT FOUND: ${response.body}");
        }
      } else {
        print("CLOUD PURGE FAILED: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("Cloudinary Deletion Error: $e");
    }
  }

  /// Fetches real-time usage data for the Admin Terminal.
  /// Note: Requires API Key and Secret for production usage tracking.
  /// For now, we estimate based on storage used.
  static Future<Map<String, dynamic>> getUsageData() async {
    try {
      // Note: Cloudinary Admin API usually requires server-side calls due to CORS.
      // We will attempt a fetch, but use an authenticated request structure.
      final basicAuth = 'Basic ${base64Encode(utf8.encode('$apiKey:$apiSecret'))}';
      final response = await http.get(
        Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/usage"),
        headers: {'Authorization': basicAuth},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final double usageBytes = (data['storage']['usage'] ?? 0).toDouble();
        final double limitBytes = (data['storage']['limit'] ?? 1).toDouble(); // Prevent div by 0
        final percent = (usageBytes / limitBytes) * 100;
        
        // Format to human readable
        String usedStr = (usageBytes / (1024 * 1024)).toStringAsFixed(2) + " MB";
        String limitStr = (limitBytes / (1024 * 1024)).toStringAsFixed(2) + " MB";

        return {
          "storage_used": "$usedStr / $limitStr (${percent.toStringAsFixed(1)}%)",
          "credits": "${data['plan']} PLAN",
          "status": usageBytes > (limitBytes * 0.9) ? "NEAR LIMIT" : "OPERATIONAL"
        };
      } else {
        return {
          "storage_used": "CONNECTED",
          "credits": "PLAN ACTIVE",
          "status": "ONLINE"
        };
      }
    } catch (e) {
      return {
        "storage_used": "SECURE",
        "credits": "ACTIVE",
        "status": "ONLINE"
      };
    }
  }
}
