import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/design_system.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import '../services/cloudinary_service.dart';
class UploadNotesSheet extends StatefulWidget {
  const UploadNotesSheet({super.key});

  @override
  State<UploadNotesSheet> createState() => _UploadNotesSheetState();
}

class _UploadNotesSheetState extends State<UploadNotesSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  String _selectedCategory = "CSE";
  bool _isUploading = false;

  final List<String> _categories = ["CSE", "ICT", "ENERGY", "CIVIL"];

  Uint8List? _fileBytes;
  String? _fileName;

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _fileBytes = result.files.first.bytes;
          _fileName = result.files.first.name;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error picking file: $e")));
    }
  }

  Future<void> _upload() async {
    if (_titleController.text.isEmpty || _subjectController.text.isEmpty || _fileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("COMPLETE ALL DETAILS AND SELECT A PDF.")));
      return;
    }

    // 10MB Limit Check
    if (_fileBytes!.lengthInBytes > 10 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("TOO HEAVY FOR THE VOID. LIMIT IS 10MB."), backgroundColor: Colors.redAccent));
      return;
    }

    setState(() => _isUploading = true);

    try {
      // 100-Slot Capacity Check
      final slotSnap = await FirebaseFirestore.instance
          .collection('notes')
          .where('category', isEqualTo: _selectedCategory)
          .get();
      
      if (slotSnap.docs.length >= 100) {
        throw Exception("ALL SLOTS IN $_selectedCategory ARE FULL. WAIT FOR KNOWLEDGE TO FADE.");
      }
      final url = await CloudinaryService.uploadMedia(_fileBytes!, 'notes_pdfs');

      await FirebaseFirestore.instance.collection('notes').add({
        'title': _titleController.text.trim(),
        'subject': _subjectController.text.trim(),
        'category': _selectedCategory,
        'authorId': FirebaseAuth.instance.currentUser?.uid,
        'fileUrl': url,
        'fileName': _fileName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("KNOWLEDGE UPLOADED SUCCESSFULLY."), backgroundColor: Color(0xFF00FF88))
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("UPLOAD FAILED: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 40,
        left: 24,
        right: 24,
        top: 40,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "UPLOAD KNOWLEDGE",
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 2),
          ),
          const SizedBox(height: 24),
          _buildField("TITLE / TOPIC", _titleController, "e.g., OS Architecture"),
          const SizedBox(height: 16),
          _buildField("SUBJECT", _subjectController, "e.g., Operating Systems"),
          const SizedBox(height: 24),
          Text(
            "CHOOSE DOMAIN",
            style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: _categories.map((cat) {
              final isSelected = _selectedCategory == cat;
              return GestureDetector(
                onTap: () => setState(() => _selectedCategory = cat),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? DesignSystem.ghostOrange : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSelected ? Colors.transparent : Colors.white10),
                  ),
                  child: Text(
                    cat,
                    style: GoogleFonts.outfit(
                      color: isSelected ? Colors.black : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  _fileName ?? "NO PDF SELECTED",
                  style: GoogleFonts.inter(color: _fileName != null ? const Color(0xFF00FF88) : Colors.white38, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(LucideIcons.fileText, size: 16, color: Colors.black),
                label: Text("SELECT PDF", style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF88),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isUploading ? null : _upload,
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignSystem.ghostOrange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isUploading
                  ? const CircularProgressIndicator(color: Colors.black)
                  : Text("RELEASE TO ARCHIVES", style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white12),
            filled: true,
            fillColor: Colors.white.withOpacity(0.02),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}

