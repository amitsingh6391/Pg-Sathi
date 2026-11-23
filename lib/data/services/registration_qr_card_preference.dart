import 'package:shared_preferences/shared_preferences.dart';

/// Remembers whether the owner hid the PG registration QR card on the dashboard.
class RegistrationQrCardPreference {
  RegistrationQrCardPreference(this._prefs);

  static const _keyHidden = 'pg_registration_qr_card_hidden';

  final SharedPreferences _prefs;

  bool get isHidden => _prefs.getBool(_keyHidden) ?? false;

  Future<void> setHidden(bool hidden) => _prefs.setBool(_keyHidden, hidden);
}
