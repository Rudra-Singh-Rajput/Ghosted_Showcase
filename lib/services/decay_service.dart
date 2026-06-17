import '../models/wispr_model.dart';

class DecayService {
  /// Initial duration for each post type
  static Duration getInitialDuration(WisprType type) {
    switch (type) {
      case WisprType.reel:
      case WisprType.voice:
        return const Duration(hours: 1);
      case WisprType.image:
      case WisprType.gif:
        return const Duration(hours: 2);
      case WisprType.text:
        return const Duration(hours: 4);
    }
  }

  /// Extension bonus for each post type when engaged
  static Duration getEngagementBonus(WisprType type) {
    return const Duration(minutes: 15);
  }

  /// Bonus for polls when enough votes are reached
  static Duration getPollBonus() {
    return const Duration(minutes: 15);
  }

  /// Calculates new expiration time after engagement
  /// Calculates new expiration time after engagement
  static DateTime extendLife(DateTime currentExpiresAt, WisprType type) {
    final bonus = getEngagementBonus(type);
    final nextExpiry = currentExpiresAt.add(bonus);
    
    // Hard Limit: No post can live longer than 7 days to protect storage
    final maxLife = DateTime.now().add(const Duration(days: 7));
    if (nextExpiry.isAfter(maxLife)) return maxLife;
    
    return nextExpiry;
  }
}
