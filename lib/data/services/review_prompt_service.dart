import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_rating_service.dart';

/// Tracks user engagement and triggers in-app review prompts at optimal moments.
///
/// Strategy:
///   1. Count positive user actions (payment, invoice download, etc.).
///   2. After [_minActionsBeforePrompt] actions, show the native review dialog.
///   3. Don't prompt again for [_cooldownDays] days.
///   4. Once the user completes a review, never prompt again.
///   5. Keep the manual "Rate Our App" button in profile as a fallback.
///
/// Call [recordPositiveAction] at delight moments. The service decides
/// internally whether to show the review prompt.
class ReviewPromptService {
  ReviewPromptService({
    required SharedPreferences sharedPreferences,
    required AppRatingService appRatingService,
  })  : _prefs = sharedPreferences,
        _ratingService = appRatingService;

  final SharedPreferences _prefs;
  final AppRatingService _ratingService;

  // =========================================================================
  // CONFIGURATION
  // =========================================================================

  /// Minimum positive actions before the first prompt.
  static const int _minActionsBeforePrompt = 5;

  /// Days to wait before showing the prompt again.
  static const int _cooldownDays = 90;

  // =========================================================================
  // PERSISTENCE KEYS
  // =========================================================================

  static const String _keyActionCount = 'review_prompt_action_count';
  static const String _keyLastPromptTimestamp = 'review_prompt_last_shown';
  static const String _keyReviewCompleted = 'review_prompt_completed';

  // =========================================================================
  // PUBLIC API
  // =========================================================================

  /// Records a positive user action and triggers a review prompt if conditions
  /// are met. Safe to call frequently — the service throttles internally.
  ///
  /// Returns `true` if a review prompt was shown.
  Future<bool> recordPositiveAction() async {
    if (kIsWeb) return false;
    if (_hasCompletedReview) return false;

    final newCount = _incrementActionCount();
    if (!_shouldPrompt(newCount)) return false;

    debugPrint('ReviewPromptService: Conditions met — requesting review');
    _markPromptShown();

    final shown = await _ratingService.requestReview();

    // The native dialog doesn't tell us if the user actually submitted,
    // but if the dialog was shown successfully, we optimistically mark it
    // complete. The OS itself will not show the dialog again if the user
    // already rated, so this prevents our own redundant attempts.
    if (shown) _markReviewCompleted();

    return shown;
  }

  /// Requests a review immediately, bypassing the action counter and cooldown.
  /// Still respects the completion flag — won't prompt if already reviewed.
  ///
  /// Use for high-signal moments where a single occurrence is enough
  /// (e.g., student's first invoice download).
  Future<bool> requestReviewOnce() async {
    if (kIsWeb) return false;
    if (_hasCompletedReview) return false;

    // Still respect the cooldown to avoid double-prompting from other triggers.
    final lastShown = _prefs.getInt(_keyLastPromptTimestamp);
    if (lastShown != null) {
      final daysSince = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(lastShown))
          .inDays;
      if (daysSince < _cooldownDays) return false;
    }

    debugPrint('ReviewPromptService: Immediate review requested');
    _markPromptShown();

    final shown = await _ratingService.requestReview();
    if (shown) _markReviewCompleted();

    return shown;
  }

  /// Whether the user has already completed a review.
  bool get _hasCompletedReview =>
      _prefs.getBool(_keyReviewCompleted) ?? false;

  // =========================================================================
  // INTERNALS
  // =========================================================================

  int _incrementActionCount() {
    final current = _prefs.getInt(_keyActionCount) ?? 0;
    final updated = current + 1;
    _prefs.setInt(_keyActionCount, updated);
    return updated;
  }

  bool _shouldPrompt(int actionCount) {
    if (actionCount < _minActionsBeforePrompt) return false;

    final lastShown = _prefs.getInt(_keyLastPromptTimestamp);
    if (lastShown != null) {
      final lastDate = DateTime.fromMillisecondsSinceEpoch(lastShown);
      final daysSince = DateTime.now().difference(lastDate).inDays;
      if (daysSince < _cooldownDays) return false;
    }

    return true;
  }

  void _markPromptShown() {
    _prefs.setInt(
      _keyLastPromptTimestamp,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  void _markReviewCompleted() {
    _prefs.setBool(_keyReviewCompleted, true);
    debugPrint('ReviewPromptService: Review marked as completed');
  }
}
