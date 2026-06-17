import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/echo_model.dart';
import '../services/cloudinary_service.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/design_system.dart';
import 'ghost_theme.dart';

class EchoBar extends StatelessWidget {
  const EchoBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('echoes')
            .where('expiresAt', isGreaterThan: Timestamp.now())
            .orderBy('expiresAt')
            .snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: docs.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildAddEcho(context);
              }
              final echo = Echo.fromDocument(docs[index - 1]);
              return _buildEchoItem(context, echo);
            },
          );
        },
      ),
    );
  }

  Widget _buildAddEcho(BuildContext context) {
    final mode = GhostTheme.of(context)?.themeMode ?? AppThemeMode.ghosted;
    final themeColor = DesignSystem.getThemeColor(mode);
    
    return GestureDetector(
      onTap: () => _handleCreateEcho(context),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        width: 70,
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: themeColor, width: 2),
                color: Colors.white.withOpacity(0.05),
              ),
              child: Icon(LucideIcons.plus, color: themeColor, size: 30),
            ),
            const SizedBox(height: 4),
            Text("ECHO", style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildEchoItem(BuildContext context, Echo echo) {
    return GestureDetector(
      onTap: () => _showEcho(context, echo),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        width: 70,
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFF00FF), width: 2),
                image: DecorationImage(image: NetworkImage(echo.mediaUrl), fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 4),
            Text(echo.authorName, 
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ).animate().scale().fadeIn();
  }

  Future<void> _handleCreateEcho(BuildContext context) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    
    if (file != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("MANIFESTING ECHO...")));
      try {
        final bytes = await file.readAsBytes();
        final url = await CloudinaryService.uploadMedia(bytes, 'echoes');
        
        final user = FirebaseAuth.instance.currentUser;
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user?.uid).get();
        final name = userDoc.data()?['name'] ?? 'Ghost';

        await FirebaseFirestore.instance.collection('echoes').add({
          'authorId': user?.uid,
          'authorName': name,
          'mediaUrl': url,
          'type': 'image',
          'createdAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 1))),
        });
        
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ECHO RELEASED. IT WILL FADE IN 1 HOUR.")));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("ECHO FAILED: $e"), backgroundColor: Colors.redAccent));
      }
    }
  }

  void _showEcho(BuildContext context, Echo echo) {
    showDialog(
      context: context,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Material(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(echo.mediaUrl, fit: BoxFit.contain),
              Positioned(
                top: 50,
                left: 20,
                right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(echo.authorName.toUpperCase(), style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 2)),
                    Text("FADING IN ${echo.expiresAt.difference(DateTime.now()).inMinutes} MIN", style: GoogleFonts.outfit(color: const Color(0xFFFF00FF), fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
