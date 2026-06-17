import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../utils/design_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/user_deletion_service.dart';
import '../widgets/ghost_theme.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _realNameController = TextEditingController();
  bool _isSavingName = false;
  String _selectedTheme = 'Neon Cyberpunk'; 
  bool _notificationsEnabled = true;
  bool _confessionTimeBased = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        _nameController.text = data['name'] ?? '';
        _realNameController.text = data['realName'] ?? '';
        _confessionTimeBased = data['confessionTimeBased'] ?? false;
      }
    }
    if (mounted) {
      setState(() {
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      });
    }
  }

  Future<void> _updateIdentity() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSavingName = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'name': _nameController.text.trim(),
        'realName': _realNameController.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("IDENTITY MANIFESTED."), backgroundColor: Color(0xFF00FF88))
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("MANIFESTATION FAILED: $e"), backgroundColor: Colors.redAccent)
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingName = false);
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    if (mounted) {
      setState(() => _notificationsEnabled = value);
    }
  }

  Future<void> _toggleConfessionTimeBased(bool value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'confessionTimeBased': value,
      });
      if (mounted) {
        setState(() => _confessionTimeBased = value);
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    final currentTheme = GhostTheme.of(context)?.themeMode ?? AppThemeMode.ghosted;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "SETTINGS",
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: DesignSystem.responsiveWidth(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
          Text(
            "THEME SELECTION",
            style: GoogleFonts.outfit(color: DesignSystem.astralCyan, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2),
          ),
          const SizedBox(height: 16),
          _buildThemeOption(context, "Ghosted", LucideIcons.ghost, AppThemeMode.ghosted),
          _buildThemeOption(context, "Cosmic", LucideIcons.zap, AppThemeMode.cosmic),
          _buildThemeOption(context, "Aurora", LucideIcons.eyeOff, AppThemeMode.aurora),
          _buildThemeOption(context, "Comic", LucideIcons.palette, AppThemeMode.comic),
          
          const SizedBox(height: 40),
          Text(
            "ACCOUNT",
            style: GoogleFonts.outfit(color: DesignSystem.astralCyan, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(LucideIcons.mail, color: Colors.white54),
            title: Text("Email", style: GoogleFonts.inter(color: Colors.white70)),
            subtitle: Text(FirebaseAuth.instance.currentUser?.email ?? "Unknown", style: GoogleFonts.inter(color: Colors.white38)),
          ),
          const Divider(color: Colors.white10),
          const SizedBox(height: 16),
          Text(
            "UPDATE IDENTITY",
            style: GoogleFonts.outfit(color: DesignSystem.astralCyan, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2),
          ),
          const SizedBox(height: 16),
          _buildIdentityField(_realNameController, "Real Name", LucideIcons.user),
          const SizedBox(height: 12),
          _buildIdentityField(_nameController, "Alias / Ghost Name", LucideIcons.ghost),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton.icon(
              onPressed: _isSavingName ? null : _updateIdentity,
              icon: _isSavingName 
                ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : const Icon(LucideIcons.save, size: 14),
              label: Text("SAVE IDENTITY", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignSystem.ghostOrange,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const Divider(color: Colors.white10),
           ListTile(
             contentPadding: EdgeInsets.zero,
             leading: Icon(LucideIcons.bell, color: _notificationsEnabled ? DesignSystem.spectralGreen : Colors.white24),
             title: Text("Spectral Resonance", style: GoogleFonts.inter(color: Colors.white70)),
             subtitle: Text("Haptic echoes and visual pulses for void activity", style: GoogleFonts.inter(color: Colors.white24, fontSize: 10)),
             trailing: Switch(
               value: _notificationsEnabled,
               onChanged: _toggleNotifications,
               activeColor: DesignSystem.spectralGreen,
             ),
           ),
           ListTile(
             contentPadding: EdgeInsets.zero,
             leading: Icon(LucideIcons.clock, color: _confessionTimeBased ? DesignSystem.spectralGreen : Colors.white24),
             title: Text("Time-based Confessions", style: GoogleFonts.inter(color: Colors.white70)),
             subtitle: Text("Auto-delete your confessions after 24 hours (default: Off/Permanent)", style: GoogleFonts.inter(color: Colors.white24, fontSize: 10)),
             trailing: Switch(
               value: _confessionTimeBased,
               onChanged: _toggleConfessionTimeBased,
               activeColor: DesignSystem.spectralGreen,
             ),
           ),

          const SizedBox(height: 60),
          Center(
            child: TextButton.icon(
              onPressed: () => _confirmAccountDeletion(context),
              icon: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 16),
              label: Text(
                "BANISH SOUL (DELETE ACCOUNT)",
                style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              backgroundColor: Colors.redAccent.withOpacity(0.05),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.redAccent, width: 0.5)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              "WARNING: THIS ACTION IS IRREVERSIBLE. ALL WHISPER RECORDS AND SPECTRAL DATA WILL BE PERMANENTLY WIPED FROM THE VOID.",
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.white12, fontSize: 8, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
     ),
    );
  }

  void _confirmAccountDeletion(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F0F0F),
        title: Text("BANISH YOUR SOUL?", style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.w900, letterSpacing: 1)),
        content: const Text(
          "This will instantly erase all your Whispers, Messages, and Essence from our servers. You will be severed from the Void forever.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("REMAIN")),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              _performNuke(context);
            }, 
            child: const Text("BANISH", style: TextStyle(color: Colors.redAccent))
          ),
        ],
      ),
    );
  }

  Future<void> _performNuke(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.redAccent)),
    );

    try {
      await UserDeletionService.nukeUser();
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("YOUR ESSENCE HAS BEEN PURGED."), backgroundColor: Colors.black));
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        if (e.toString().contains('requires-recent-login')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.redAccent,
              content: Text("SECURITY PROTOCOL: Please log out and back in to verify your soul before deletion."),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("PURGE FAILED: $e"), backgroundColor: Colors.redAccent));
        }
      }
    }
  }

  Widget _buildIdentityField(TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
        prefixIcon: Icon(icon, color: DesignSystem.ghostOrange.withOpacity(0.5), size: 18),
        filled: true,
        fillColor: Colors.white.withOpacity(0.02),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildThemeOption(BuildContext context, String title, IconData icon, AppThemeMode mode) {
    final ghostTheme = GhostTheme.of(context);
    final isSelected = ghostTheme?.themeMode == mode;
    
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: isSelected ? DesignSystem.ghostOrange : Colors.white24),
      title: Text(
        title,
        style: GoogleFonts.inter(color: isSelected ? Colors.white : Colors.white54, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
      ),
      trailing: isSelected ? const Icon(LucideIcons.checkCircle, color: DesignSystem.ghostOrange) : null,
      onTap: () {
        ghostTheme?.onThemeChanged(mode);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("SPIRIT EVOLVED: $title manifested."), 
          backgroundColor: DesignSystem.getThemeColor(mode), 
          duration: const Duration(seconds: 1)
        ));
      },
    );
  }
}

