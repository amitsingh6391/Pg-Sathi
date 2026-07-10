import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/core/failure.dart';
import '../../../domain/usecases/get_user_device_sessions.dart';
import '../../../domain/usecases/logout_all_other_devices.dart';
import '../../../domain/usecases/logout_device_session.dart';
import 'device_sessions_state.dart';

/// Cubit for managing device sessions.
class DeviceSessionsCubit extends Cubit<DeviceSessionsState> {
  DeviceSessionsCubit({
    required this.getUserDeviceSessions,
    required this.logoutDeviceSession,
    required this.logoutAllOtherDevices,
  }) : super(const DeviceSessionsState());

  final GetUserDeviceSessions getUserDeviceSessions;
  final LogoutDeviceSession logoutDeviceSession;
  final LogoutAllOtherDevices logoutAllOtherDevices;

  /// Load all device sessions for a user.
  Future<void> loadDeviceSessions({
    required String userId,
    String? currentDeviceId,
  }) async {
    emit(
      state.copyWith(
        status: DeviceSessionsStatus.loading,
        currentDeviceId: currentDeviceId,
      ),
    );

    final result = await getUserDeviceSessions(userId);

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: DeviceSessionsStatus.error,
          errorMessage:
              (failure as Failure?)?.message ??
              'Failed to load device sessions',
        ),
      ),
      (sessions) => emit(
        state.copyWith(status: DeviceSessionsStatus.loaded, sessions: sessions),
      ),
    );
  }

  /// Logout from a specific device.
  Future<void> logout({
    required String userId,
    required String sessionId,
  }) async {
    emit(state.copyWith(status: DeviceSessionsStatus.loggingOut));

    final result = await logoutDeviceSession(
      userId: userId,
      sessionId: sessionId,
    );

    await result.fold(
      (failure) async {
        emit(
          state.copyWith(
            status: DeviceSessionsStatus.error,
            errorMessage:
                (failure as Failure?)?.message ?? 'Failed to logout device',
          ),
        );
      },
      (_) async {
        // Immediately remove the session from the list for instant UI update
        final updatedSessions = state.sessions
            .where((s) => s.id != sessionId)
            .toList();

        // Emit success state with updated sessions
        emit(
          state.copyWith(
            status: DeviceSessionsStatus.success,
            sessions: updatedSessions,
          ),
        );

        // Wait a bit for the snackbar to show, then reload silently
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Reload in background without showing loading state
        final reloadResult = await getUserDeviceSessions(userId);
        reloadResult.fold(
          (_) {}, // Ignore reload errors
          (sessions) => emit(
            state.copyWith(
              status: DeviceSessionsStatus.loaded,
              sessions: sessions,
            ),
          ),
        );
      },
    );
  }

  /// Logout from all other devices except current.
  Future<void> logoutAllOthers({
    required String userId,
    required String currentDeviceId,
  }) async {
    emit(state.copyWith(status: DeviceSessionsStatus.loggingOut));

    final result = await logoutAllOtherDevices(
      userId: userId,
      currentDeviceId: currentDeviceId,
    );

    await result.fold(
      (failure) async {
        emit(
          state.copyWith(
            status: DeviceSessionsStatus.error,
            errorMessage:
                (failure as Failure?)?.message ??
                'Failed to logout all devices',
          ),
        );
      },
      (_) async {
        // Immediately update sessions to show only current device
        final updatedSessions = state.sessions
            .where((s) => s.deviceId == currentDeviceId)
            .toList();
        
        emit(
          state.copyWith(
            status: DeviceSessionsStatus.success,
            sessions: updatedSessions,
          ),
        );

        // Wait a bit for the snackbar to show, then reload silently
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Reload in background without showing loading state
        final reloadResult = await getUserDeviceSessions(userId);
        reloadResult.fold(
          (_) {}, // Ignore reload errors
          (sessions) => emit(
            state.copyWith(
              status: DeviceSessionsStatus.loaded,
              sessions: sessions,
            ),
          ),
        );
      },
    );
  }
}
