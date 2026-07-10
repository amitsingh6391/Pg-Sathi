import 'package:shared_preferences/shared_preferences.dart';

/// Service to track first app launch for onboarding.
class FirstLaunchService {
  static const _keyFirstLaunch = 'is_first_launch';
  static const _keyOnboardingComplete = 'onboarding_complete';

  final SharedPreferences _prefs;

  FirstLaunchService(this._prefs);

  /// Check if this is the first app launch.
  bool isFirstLaunch() {
    return _prefs.getBool(_keyFirstLaunch) ?? true;
  }

  /// Check if onboarding was completed.
  bool isOnboardingComplete() {
    return _prefs.getBool(_keyOnboardingComplete) ?? false;
  }

  /// Mark onboarding as complete.
  Future<void> markOnboardingComplete() async {
    await _prefs.setBool(_keyOnboardingComplete, true);
    await _prefs.setBool(_keyFirstLaunch, false);
  }

  /// Check if onboarding should be shown.
  /// Returns true if first launch and onboarding not completed.
  bool shouldShowOnboarding() {
    return isFirstLaunch() && !isOnboardingComplete();
  }
}
