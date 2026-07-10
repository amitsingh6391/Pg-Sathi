import 'package:shared_preferences/shared_preferences.dart';

/// Service to track which promos an owner has seen locally.
/// Uses SharedPreferences for persistence across sessions.
class PromoSeenService {
  PromoSeenService(this._prefs);

  final SharedPreferences _prefs;

  // Keys for SharedPreferences
  static const _seenEverPrefix = 'promo_seen_ever_';
  static const _seenDatePrefix = 'promo_seen_date_';

  // In-memory session tracking (cleared on app restart)
  final Set<String> _sessionSeenPromos = {};

  /// Check if owner has ever seen this promo (for 'once' frequency)
  bool hasSeenPromoEver({
    required String promoId,
    required String ownerId,
  }) {
    final key = '$_seenEverPrefix${promoId}_$ownerId';
    return _prefs.getBool(key) ?? false;
  }

  /// Check if owner has seen this promo today (for 'daily' frequency)
  bool hasSeenPromoToday({
    required String promoId,
    required String ownerId,
  }) {
    final key = '$_seenDatePrefix${promoId}_$ownerId';
    final seenDate = _prefs.getString(key);

    if (seenDate == null) return false;

    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';

    return seenDate == todayStr;
  }

  /// Check if owner has seen this promo this session (for 'session' frequency)
  bool hasSeenPromoThisSession({
    required String promoId,
    required String ownerId,
  }) {
    final key = '${promoId}_$ownerId';
    return _sessionSeenPromos.contains(key);
  }

  /// Mark a promo as seen by the owner
  Future<void> markPromoAsSeen({
    required String promoId,
    required String ownerId,
  }) async {
    final sessionKey = '${promoId}_$ownerId';

    // Mark seen in session
    _sessionSeenPromos.add(sessionKey);

    // Mark seen ever
    final everKey = '$_seenEverPrefix${promoId}_$ownerId';
    await _prefs.setBool(everKey, true);

    // Mark seen date
    final dateKey = '$_seenDatePrefix${promoId}_$ownerId';
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';
    await _prefs.setString(dateKey, todayStr);
  }

  /// Clear all seen data (for testing or reset)
  Future<void> clearSeenData() async {
    _sessionSeenPromos.clear();

    final keys = _prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(_seenEverPrefix) ||
          key.startsWith(_seenDatePrefix)) {
        await _prefs.remove(key);
      }
    }
  }

  /// Clear session seen data only (called on logout)
  void clearSessionData() {
    _sessionSeenPromos.clear();
  }
}
