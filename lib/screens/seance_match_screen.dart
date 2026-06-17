import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../models/user_model.dart';
import 'seance_chat_screen.dart'; // We'll build this next

class SeanceMatchScreen extends StatefulWidget {
  const SeanceMatchScreen({super.key});

  @override
  State<SeanceMatchScreen> createState() => _SeanceMatchScreenState();
}

class _SeanceMatchScreenState extends State<SeanceMatchScreen> {
  // Mock data: In reality we'd fetch random users not yet swiped
  final List<UserModel> _deck = [
    UserModel(
      uid: '201', 
      email: '', name: '', photoUrl: '', // HIDDEN
      bio: 'If you can beat me in Mario Kart, I buy the coffee.', 
      hobbies: ['Gaming', 'Coffee', 'Late Nights'], 
    ),
    UserModel(
      uid: '202', 
      email: '', name: '', photoUrl: '', // HIDDEN
      bio: 'Looking for someone to survive finals with.', 
      hobbies: ['Library', 'Crying', 'Pizza'], 
    ),
  ];

  int _currentIndex = 0;

  void _swipeLeft() {
    if (_currentIndex < _deck.length) {
      setState(() {
        _currentIndex++;
      });
    }
  }

  void _swipeRight() {
    if (_currentIndex < _deck.length) {
      // It's a match! (Mocking mutual swipe for demo purposes)
      final matchedUser = _deck[_currentIndex];
      
      setState(() {
        _currentIndex++;
      });

      // Navigate to Chat
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SeanceChatScreen(peerBio: matchedUser.bio),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'THE SÉANCE', 
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: theme.colorScheme.tertiary, // Cyber Pink
          )
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: _currentIndex >= _deck.length 
          ? Text("No more spirits to communicate with.", style: TextStyle(color: Colors.grey))
          : SlideInUp(
              key: ValueKey(_currentIndex),
              duration: const Duration(milliseconds: 300),
              child: _buildCard(_deck[_currentIndex], theme),
            ),
      ),
      bottomNavigationBar: _currentIndex >= _deck.length ? null : Padding(
        padding: const EdgeInsets.all(32.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            FloatingActionButton(
              heroTag: 'nope',
              onPressed: _swipeLeft,
              backgroundColor: Colors.black,
              shape: CircleBorder(side: BorderSide(color: Colors.grey, width: 2)),
              child: const Icon(Icons.close, color: Colors.grey, size: 32),
            ),
            FloatingActionButton(
              heroTag: 'yeah',
              onPressed: _swipeRight,
              backgroundColor: Colors.black,
              shape: CircleBorder(side: BorderSide(color: theme.colorScheme.tertiary, width: 2)),
              child: Icon(Icons.bolt, color: theme.colorScheme.tertiary, size: 32),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(UserModel user, ThemeData theme) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.tertiary.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.tertiary.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 5,
          )
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.psychology, size: 80, color: Colors.grey),
          const SizedBox(height: 32),
          Text(
            '"${user.bio}"',
            style: const TextStyle(fontSize: 24, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 8,
            children: user.hobbies.map((h) => Chip(
              label: Text(h),
              backgroundColor: Colors.black,
              side: BorderSide(color: theme.colorScheme.tertiary),
              labelStyle: TextStyle(color: theme.colorScheme.tertiary),
            )).toList(),
          )
        ],
      ),
    );
  }
}

