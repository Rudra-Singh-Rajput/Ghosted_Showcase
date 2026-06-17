class AuthService {
  static bool isSuperAdmin(String? email) => false;
  static bool isOracle1(String? email) => false;
  static bool isOracle2(String? email) => false;
  static bool isSubMod(String? email) => false;
  static bool isOracle(String? email) => false;
  static bool isAuthorized(String? email) => false;
  static bool isSystemAccount(String? email) => false;
  static bool canDelete(String? email) => false;
  static bool canSeeRealNames(String? email) => false;
  static bool canSeeFullDetails(String? email) => false;

  /// Context-aware name visibility logic.
  /// [context] can be 'wispr', 'sanctuary', 'seance', 'archive', 'notification'
  static String getDisplayName({
    required String? viewerEmail,
    required String? authorRealName,
    required String? authorAlias,
    required String context,
  }) {
    if (context == 'archive') {
      return authorRealName ?? authorAlias ?? "Unknown Spirit";
    }
    if (context == 'seance') {
      return authorAlias ?? "Ghost";
    }
    return "Ghost";
  }
}
