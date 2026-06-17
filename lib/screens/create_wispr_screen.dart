import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/limit_service.dart';

class CreateWisprScreen extends StatefulWidget {
  const CreateWisprScreen({super.key});

  @override
  State<CreateWisprScreen> createState() => _CreateWisprScreenState();
}

class _CreateWisprScreenState extends State<CreateWisprScreen> {
  final _textController = TextEditingController();
  final _payoffController = TextEditingController();
  final _voteGoalController = TextEditingController();
  
  bool _isPoll = false;
  final List<TextEditingController> _pollOptionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  @override
  void dispose() {
    _textController.dispose();
    _payoffController.dispose();
    _voteGoalController.dispose();
    for (var controller in _pollOptionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    // Scaffold submission logic for sending to Firestore
    if (_textController.text.trim().isEmpty) return;

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Wispr sent into the void...')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('NEW WISPR'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _submit,
            child: Text('POST', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _textController,
              maxLength: LimitService.REGULAR_CHAR_LIMIT,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: "What's the tea?",
                hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
                filled: true,
                fillColor: theme.colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                counterStyle: TextStyle(color: theme.colorScheme.primary),
              ),
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 20),
            
            SwitchListTile(
              title: const Text('Add a Poll (2 Options)', style: TextStyle(fontWeight: FontWeight.bold)),
              value: _isPoll,
              activeColor: theme.colorScheme.secondary,
              contentPadding: EdgeInsets.zero,
              onChanged: (val) {
                setState(() => _isPoll = val);
              },
            ),
            
            if (_isPoll)
              Column(
                children: [
                  ...List.generate(2, (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: TextField(
                      controller: _pollOptionControllers[index],
                      decoration: InputDecoration(
                        hintText: "Option ${index + 1}",
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  )),
                ],
              ),
            
            const SizedBox(height: 20),
            const Text('THE PAYOFF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 8),
            Text('Set a goal. If met, the tea is revealed to all.', style: TextStyle(color: Colors.grey.withOpacity(0.7), fontSize: 12)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _voteGoalController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: "Goal (e.g. 50)",
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _payoffController,
                    decoration: InputDecoration(
                      hintText: "The locked secret",
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

