/// Pure mapping from a push payload to an in-app route. Returns null
/// for unknown/malformed payloads so callers can fall back to "open
/// app at last route". Only PG notice payloads currently deep-link.
library;

class NotificationDeepLink {
  const NotificationDeepLink._();

  static const String _typeNotice = 'notice';

  /// Resolves a route path for the given push payload, or `null`
  /// if no deep link applies (unknown type, missing id, etc.).
  static String? resolve(Map<String, dynamic> data) {
    final type = _readString(data, 'type');
    if (type == null) return null;

    switch (type) {
      case _typeNotice:
        final id = _readString(data, 'notice_id');
        return id == null ? null : '/student/notices/$id';

      default:
        return null;
    }
  }

  static String? _readString(Map<String, dynamic> data, String key) {
    final raw = data[key];
    if (raw is String && raw.isNotEmpty) return raw;
    return null;
  }
}
