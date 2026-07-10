import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Service to track and manage Firebase OTP quota usage.
/// Tracks daily Firebase OTP sends to stay within the free tier limit (10/day).
class OtpQuotaService {
  OtpQuotaService(this._firestore);

  final FirebaseFirestore _firestore;
  static const int _maxFirebaseOtpPerDay = 10;
  static const String _quotaDocId = 'daily';

  static const Duration _cacheTtl = Duration(seconds: 60);
  String? _cachedDate;
  int? _cachedCount;
  DateTime? _cacheTimestamp;

  static String _quotaDateKey() {
    final nowIst = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    final quotaDay = nowIst.subtract(const Duration(hours: 14));
    return DateFormat('yyyy-MM-dd').format(quotaDay);
  }


  Future<bool> canUseFirebaseOtp() async {
    try {
      final today = _quotaDateKey();

      // Serve from cache if fresh and same day
      if (_cachedDate == today &&
          _cachedCount != null &&
          _cacheTimestamp != null &&
          DateTime.now().difference(_cacheTimestamp!) < _cacheTtl) {
        return _cachedCount! < _maxFirebaseOtpPerDay;
      }

      final docRef = _firestore.collection('otp_stats').doc(_quotaDocId);
      final doc = await docRef.get();

      if (!doc.exists) {
        _updateCache(today, 0);
        return true;
      }

      final data = doc.data()!;
      final storedDate = data['date'] as String?;
      final count = data['count'] as int? ?? 0;

      if (storedDate != today) {
        _updateCache(today, 0);
        return true;
      }

      _updateCache(today, count);
      return count < _maxFirebaseOtpPerDay;
    } catch (e) {
      return false;
    }
  }

  /// Increments the Firebase OTP count for today.
  Future<void> incrementFirebaseOtpCount() async {
    try {
      final today = _quotaDateKey();
      final docRef = _firestore.collection('otp_stats').doc(_quotaDocId);

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);

        if (!doc.exists) {
          transaction.set(docRef, {
            'date': today,
            'count': 1,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          _updateCache(today, 1);
        } else {
          final data = doc.data()!;
          final storedDate = data['date'] as String?;
          final count = data['count'] as int? ?? 0;

          if (storedDate != today) {
            transaction.update(docRef, {
              'date': today,
              'count': 1,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            _updateCache(today, 1);
          } else {
            transaction.update(docRef, {
              'count': count + 1,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            _updateCache(today, count + 1);
          }
        }
      });
    } catch (e) {
      // Silently fail - quota tracking shouldn't block OTP send
    }
  }

  /// Gets the current Firebase OTP count for today.
  /// Serves from cache when available to skip the Firestore read.
  Future<int> getCurrentCount() async {
    try {
      final today = _quotaDateKey();

      if (_cachedDate == today &&
          _cachedCount != null &&
          _cacheTimestamp != null &&
          DateTime.now().difference(_cacheTimestamp!) < _cacheTtl) {
        return _cachedCount!;
      }

      final doc = await _firestore
          .collection('otp_stats')
          .doc(_quotaDocId)
          .get();

      if (!doc.exists) {
        _updateCache(today, 0);
        return 0;
      }

      final data = doc.data()!;
      final storedDate = data['date'] as String?;
      final count = data['count'] as int? ?? 0;

      if (storedDate != today) {
        _updateCache(today, 0);
        return 0;
      }

      _updateCache(today, count);
      return count;
    } catch (e) {
      return 0;
    }
  }

  void _updateCache(String date, int count) {
    _cachedDate = date;
    _cachedCount = count;
    _cacheTimestamp = DateTime.now();
  }
}
