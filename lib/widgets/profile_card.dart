import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'package:animate_do/animate_do.dart';

class ProfileCard extends StatelessWidget {
  final UserModel user;
  final bool isTop3;
  final VoidCallback onTap;

  const ProfileCard({
    super.key,
    required this.user,
    this.isTop3 = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget card = GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: isTop3 
            ? Border.all(color: theme.colorScheme.primary, width: 2)
            : Border.all(color: Colors.grey.withOpacity(0.3)),
          boxShadow: isTop3 ? [
            BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.5),
              blurRadius: 15,
              spreadRadius: 2,
            )
          ] : [],
        ),
        child: Stack(
          children: [
            // Papaya Crown for Top 3
            if (isTop3)
              Positioned(
                top: 8,
                right: 8,
                child: Flash(
                  infinite: true,
                  duration: const Duration(seconds: 3),
                  child: Icon(Icons.workspace_premium, color: theme.colorScheme.primary, size: 30),
                ),
              ),
              
            // User info text on top of image
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  gradient: LinearGradient(
                    colors: [Colors.black, Colors.transparent],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${user.viewCount} Stalks",
                      style: TextStyle(
                        color: isTop3 ? theme.colorScheme.primary : Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return isTop3 ? Pulse(child: card) : card;
  }
}

