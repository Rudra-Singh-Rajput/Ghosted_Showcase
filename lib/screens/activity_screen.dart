import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/user_model.dart';
import 'wispr_detail_screen.dart';
import '../models/wispr_model.dart';
import '../widgets/ghost_theme.dart';
import '../utils/design_system.dart';
import '../services/auth_service.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final mode = GhostTheme.of(context)?.themeMode ?? AppThemeMode.ghosted;
    final themeColor = DesignSystem.getThemeColor(mode);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'RECENT ACTIVITY',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: 2,
            color: Colors.white,
          ),
        ),
      ),
      body: DesignSystem.responsiveWidth(
        child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('recipientId', isEqualTo: currentUser?.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            final errorString = snapshot.error.toString();
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(LucideIcons.alertTriangle, color: Colors.redAccent, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      "THE VOID IS SILENT (INDEX REQUIRED)",
                      style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      errorString,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white24, fontSize: 10),
                    ),
                  ],
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: themeColor));
          
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const Icon(LucideIcons.heartOff, color: Colors.white12, size: 48),
                   const SizedBox(height: 16),
                   Text(
                     "NO ECHOES IN THE VOID YET.",
                     style: GoogleFonts.outfit(color: Colors.white24, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                   ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return _buildActivityTile(context, data, themeColor);
            },
          );
        },
      ),
     ),
    );
  }

  Widget _buildActivityTile(BuildContext context, Map<String, dynamic> data, Color themeColor) {
    final String type = data['type'] ?? 'reply';
    final String fromId = data['fromId'] ?? 'unknown';
    
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(fromId).get(),
      builder: (context, snapshot) {
        UserModel? sender;
        if (snapshot.hasData && snapshot.data!.exists) {
          sender = UserModel.fromDocument(snapshot.data!);
        }

        return ListTile(
          onTap: () async {
            if (data['wisprId'] != null) {
              final wisprDoc = await FirebaseFirestore.instance.collection('wisprs').doc(data['wisprId']).get();
              if (wisprDoc.exists && context.mounted) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => WisprDetailScreen(wispr: Wispr.fromDocument(wisprDoc))));
              }
            }
          },
          leading: CircleAvatar(
            backgroundColor: Colors.white.withOpacity(0.05),
            backgroundImage: (sender?.photoUrl.isNotEmpty ?? false) ? NetworkImage(sender!.photoUrl) : null,
            child: (sender?.photoUrl.isEmpty ?? true) ? const Icon(LucideIcons.user, color: Colors.white24, size: 20) : null,
          ),
          title: RichText(
            text: TextSpan(
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
              children: [
                TextSpan(
                  text: AuthService.getDisplayName(
                    viewerEmail: FirebaseAuth.instance.currentUser?.email, 
                    authorRealName: sender?.realName, 
                    authorAlias: sender?.name, 
                    context: 'notification'
                  ),
                  style: TextStyle(fontWeight: FontWeight.w900, color: themeColor),
                ),
                TextSpan(
                  text: type == 'reply' 
                    ? ' whispered back to your spirit.' 
                    : type == 'haunt'
                      ? ' is haunting your archive essence.'
                      : ' summoned you with a tag.',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          subtitle: Text(
            data['message'] ?? '',
            style: GoogleFonts.inter(color: Colors.white24, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(LucideIcons.chevronRight, color: Colors.white12, size: 14),
        ).animate().fadeIn().slideX(begin: 0.1, end: 0);
      },
    );
  }
}

