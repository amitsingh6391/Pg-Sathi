import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:pg_manager/domain/entities/user.dart';
import 'package:pg_manager/domain/repositories/user_session_repository.dart';

/// Service for tracking user app sessions.
/// Automatically starts, updates, and ends sessions based on app lifecycle.
class UserSessionService {
  UserSessionService(this._sessionRepository);

  final UserSessionRepository _sessionRepository;

  String? _currentSessionId;
  Timer? _updateTimer;
  AppLifecycleListener? _lifecycleListener;

  /// Starts tracking a new session for the user.
  Future<void> startSession({
    required String userId,
    required UserRole role,
    String? deviceId,
  }) async {
    // End any existing session first
    await endSession();

    final result = await _sessionRepository.startSession(
      userId: userId,
      role: role,
      deviceId: deviceId,
    );

    result.fold(
      (failure) {
        // Log error but don't throw
        debugPrint('Failed to start session: $failure');
      },
      (session) {
        _currentSessionId = session.id;
        _startPeriodicUpdate();
        _setupLifecycleListener();
      },
    );
  }

  /// Ends the current session.
  Future<void> endSession() async {
    if (_currentSessionId == null) return;

    _stopPeriodicUpdate();
    _lifecycleListener?.dispose();
    _lifecycleListener = null;

    await _sessionRepository.endSession(_currentSessionId!);
    _currentSessionId = null;
  }

  /// Updates last active time for the current session.
  Future<void> updateLastActive() async {
    if (_currentSessionId == null) return;

    await _sessionRepository.updateLastActive(_currentSessionId!);
  }

  /// Disposes resources.
  void dispose() {
    _stopPeriodicUpdate();
    _lifecycleListener?.dispose();
  }

  // ============================================================
  // Private Methods
  // ============================================================

  void _startPeriodicUpdate() {
    _stopPeriodicUpdate();
    // Update last active every 30 seconds
    _updateTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => updateLastActive(),
    );
  }

  void _stopPeriodicUpdate() {
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  void _setupLifecycleListener() {
    _lifecycleListener = AppLifecycleListener(
      onStateChange: (state) {
        switch (state) {
          case AppLifecycleState.resumed:
            // App came to foreground - update last active
            updateLastActive();
          case AppLifecycleState.paused:
          case AppLifecycleState.detached:
          case AppLifecycleState.inactive:
            // App going to background - end session
            endSession();
          case AppLifecycleState.hidden:
            // Do nothing
            break;
        }
      },
    );
  }
}
