import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/design_system.dart';
import '../widgets/void_empty_state.dart';
import '../widgets/upload_notes_sheet.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../widgets/ghost_theme.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _categories = ["CSE", "ICT", "ENERGY", "CIVIL"];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = GhostTheme.of(context)?.themeMode ?? AppThemeMode.ghosted;
    final isComic = mode == AppThemeMode.comic;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: isComic ? DesignSystem.comicInk : Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "UNIVERSITY NOTES",
          style: isComic 
              ? GoogleFonts.bangers(fontSize: 24, color: DesignSystem.comicInk, letterSpacing: 2)
              : GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  fontSize: 18,
                ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: isComic ? DesignSystem.comicInk : DesignSystem.ghostOrange,
          labelColor: isComic ? DesignSystem.comicInk : DesignSystem.ghostOrange,
          unselectedLabelColor: isComic ? Colors.black45 : Colors.white24,
          labelStyle: isComic 
              ? GoogleFonts.comicNeue(fontWeight: FontWeight.bold, fontSize: 12)
              : GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12),
          tabs: _categories.map((c) => Tab(text: c)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _categories.map((cat) => _buildNotesList(cat)).toList(),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 130.0),
        child: FloatingActionButton.extended(
          onPressed: () => _showUploadSheet(),
          backgroundColor: DesignSystem.ghostOrange,
          icon: const Icon(LucideIcons.plus, color: Colors.black),
          label: Text("UPLOAD NOTES", style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold)),
        ).animate().scale(),
      ),
    );
  }

  Widget _buildNotesList(String category) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notes')
          .where('category', isEqualTo: category)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("ERROR: ${snapshot.error}", style: const TextStyle(color: Colors.white24)));
        }
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFF8700)));
        }
        
        final docs = snapshot.data?.docs.toList() ?? [];
        docs.sort((a, b) {
          final aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          final bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        });

        return _buildNoteListFromDocs(docs, category);
      },
    );
  }

  Widget _buildNoteListFromDocs(List<QueryDocumentSnapshot> docs, String category) {

        if (docs.isEmpty) {
          return VoidEmptyState(
            message: "NO KNOWLEDGE FOUND IN $category...",
            onAction: () => _showUploadSheet(),
            actionLabel: "BE THE FIRST TO UPLOAD",
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildNoteCard(doc.id, data, index);
          },
        );
  }

  Widget _buildNoteCard(String docId, Map<String, dynamic> data, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: DesignSystem.ghostOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(LucideIcons.fileText, color: DesignSystem.ghostOrange, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['title'] ?? "Untitled Knowledge",
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  data['subject'] ?? "General",
                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.download, color: Color(0xFF00FF88)),
            onPressed: () async {
              if (data['fileUrl'] != null) {
                final url = Uri.parse(data['fileUrl']);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cannot open file.")));
                }
              } else {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No file attached.")));
              }
            },
          ),
          if (data['authorId'] == FirebaseAuth.instance.currentUser?.uid)
            IconButton(
              icon: Icon(LucideIcons.trash2, color: Colors.redAccent.withOpacity(0.4), size: 20),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    backgroundColor: Colors.black,
                    title: Text("BANISH KNOWLEDGE?", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                    content: const Text("Remove this knowledge from the Archives?", style: TextStyle(color: Colors.white70)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("KEEP")),
                      TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("BANISH", style: TextStyle(color: Colors.redAccent))),
                    ],
                  ),
                );
                if (confirmed == true) {
                   await FirebaseFirestore.instance.collection('notes').doc(docId).delete();
                }
              },
            ),
        ],
      ),
    ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.1, end: 0);
  }

  void _showUploadSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const UploadNotesSheet(),
    );
  }
}

