import 'package:equatable/equatable.dart';

import '../../../domain/entities/device_session.dart';

/// States for device sessions management.
enum DeviceSessionsStatus {
  initial,
  loading,
  loaded,
  loggingOut,
  success,
  error,
}

class DeviceSessionsState extends Equatable {
  const DeviceSessionsState({
    this.status = DeviceSessionsStatus.initial,
    this.sessions = const [],
    this.errorMessage,
    this.currentDeviceId,
  });

  final DeviceSessionsStatus status;
  final List<DeviceSession> sessions;
  final String? errorMessage;
  final String? currentDeviceId;

  bool get isLoading => status == DeviceSessionsStatus.loading;
  bool get isLoaded => status == DeviceSessionsStatus.loaded;
  bool get isLoggingOut => status == DeviceSessionsStatus.loggingOut;
  bool get isError => status == DeviceSessionsStatus.error;

  int get activeSessions => sessions.where((s) => s.isActive).length;

  DeviceSessionsState copyWith({
    DeviceSessionsStatus? status,
    List<DeviceSession>? sessions,
    String? errorMessage,
    String? currentDeviceId,
  }) {
    return DeviceSessionsState(
      status: status ?? this.status,
      sessions: sessions ?? this.sessions,
      errorMessage: errorMessage ?? this.errorMessage,
      currentDeviceId: currentDeviceId ?? this.currentDeviceId,
    );
  }

  @override
  List<Object?> get props => [status, sessions, errorMessage, currentDeviceId];
}
