import 'package:flutter/material.dart';
import '../services/seed_service.dart';
import '../services/cleanup_service.dart';
import 'package:google_fonts/google_fonts.dart';

class GodModeScreen extends StatefulWidget {
  const GodModeScreen({super.key});

  @override
  State<GodModeScreen> createState() => _GodModeScreenState();
}

class _GodModeScreenState extends State<GodModeScreen> {
  final TextEditingController _banController = TextEditingController();
  
  @override
  void dispose() {
    _banController.dispose();
    super.dispose();
  }

  void _executeUser() {
    final uid = _banController.text.trim();
    if (uid.isEmpty) return;
    
    // In real app: Update Firestore users/$uid { isBanned: true }
    // Or call a secure Cloud Function (if we move away from Spark plan)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('THE EXECUTIONER HAS STRUCK: $uid IS BANNED.', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red,
      )
    );
    _banController.clear();
  }

  @override
  Widget build(BuildContext context) {
    // Hidden Admin area, high contrast, red accents
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('OMNISCIENCE (GOD MODE)', style: TextStyle(color: Colors.red, letterSpacing: 4, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.black,
          centerTitle: true,
          bottom: const TabBar(
            indicatorColor: Colors.red,
            labelColor: Colors.red,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(icon: Icon(Icons.masks), text: 'DE-ANONYMIZE'),
              Tab(icon: Icon(Icons.remove_red_eye), text: 'GHOST-VIEW'),
              Tab(icon: Icon(Icons.dangerous), text: 'EXECUTIONER'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildDeAnonymizeTab(),
            _buildGhostViewTab(),
            _buildExecutionerTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildDeAnonymizeTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('WISPR AUTHORS:', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ListTile(
          tileColor: Colors.red.withOpacity(0.1),
          title: const Text('"Anyone know why the lib smells like ozone today?"'),
          subtitle: const Text('Real Identity: Alex Ghost (UID: 101)', style: TextStyle(color: Colors.red)),
          trailing: const Icon(Icons.search, color: Colors.red),
        ),
        const SizedBox(height: 8),
        ListTile(
          tileColor: Colors.red.withOpacity(0.1),
          title: const Text('"Professor G is definitely an alien."'),
          subtitle: const Text('Real Identity: Sam Specter (UID: 102)', style: TextStyle(color: Colors.red)),
          trailing: const Icon(Icons.search, color: Colors.red),
        ),
      ],
    );
  }

  Widget _buildGhostViewTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('ACTIVE SÉANCES:', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Card(
          color: Colors.black,
          shape: Border.all(color: Colors.red.withOpacity(0.5)),
          child: ExpansionTile(
            title: const Text('SÃ©ance 9X2A - 5 Messages Exchanged', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Participants: 101 vs 202', style: TextStyle(color: Colors.grey)),
            iconColor: Colors.red,
            childrenPadding: const EdgeInsets.all(16),
            children: const [
              Align(alignment: Alignment.centerRight, child: Text('101: Hey', style: TextStyle(color: Colors.grey))),
              Align(alignment: Alignment.centerLeft, child: Text('202: Who is this?', style: TextStyle(color: Colors.grey))),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildExecutionerTab() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.gavel, size: 100, color: Colors.red),
          const SizedBox(height: 32),
          const Text('PERMANENT ACCOUNT DELETION', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          TextField(
            controller: _banController,
            decoration: InputDecoration(
              hintText: 'Enter UID to wipe from existence...',
              filled: true,
              fillColor: Colors.grey.shade900,
              border: OutlineInputBorder(borderSide: BorderSide.none),
            ),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _executeUser,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
            ),
            child: const Text('EXECUTE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 24)),
          ),
          const SizedBox(height: 64),
          const Divider(color: Colors.red, thickness: 0.5),
          const SizedBox(height: 32),
          const Text('SYSTEM LEVEL RESET', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 2)),
          const SizedBox(height: 16),
          Text(
            'Purges all Firestore collections and wipes every file from Firebase Storage. Use this to reset the Free Plan limits.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: Colors.white24, fontSize: 10),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _confirmNuke(context),
            icon: const Icon(Icons.auto_delete, color: Colors.black),
            label: const Text('NUKE THE VOID', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, letterSpacing: 1)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmNuke(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text('TOTAL ANNIHILATION?', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text('This will wipe all users, wisprs, chats, and EVERY file from storage. This is irreversible.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('CANCEL', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () => Navigator.pop(c, true), 
            child: const Text('DO IT', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator(color: Colors.red)),
      );

      try {
        await CleanupService.systemReset();
        await SeedService.nukeAllData();
        
        if (mounted) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("THE VOID HAS BEEN PURGED."), backgroundColor: Colors.red));
        }
      } catch (e) {
        if (mounted) {
           Navigator.pop(context); // Close loading
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("NUKE FAILED: $e"), backgroundColor: Colors.orange));
        }
      }
    }
  }
}

