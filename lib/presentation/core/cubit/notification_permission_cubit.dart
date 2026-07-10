import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:equatable/equatable.dart';

/// State for notification permission status.
enum NotificationPermissionStatus {
  initial,
  checking,
  granted,
  denied,
  permanentlyDenied,
}

/// State for NotificationPermissionCubit.
class NotificationPermissionState extends Equatable {
  const NotificationPermissionState({
    this.status = NotificationPermissionStatus.initial,
    this.errorMessage,
  });

  final NotificationPermissionStatus status;
  final String? errorMessage;

  bool get isGranted => status == NotificationPermissionStatus.granted;
  bool get isDenied => status == NotificationPermissionStatus.denied;
  bool get isPermanentlyDenied =>
      status == NotificationPermissionStatus.permanentlyDenied;
  bool get isChecking => status == NotificationPermissionStatus.checking;

  NotificationPermissionState copyWith({
    NotificationPermissionStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return NotificationPermissionState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, errorMessage];
}

/// Cubit for managing notification permission state.
class NotificationPermissionCubit extends Cubit<NotificationPermissionState> {
  NotificationPermissionCubit({required this.messaging})
    : super(const NotificationPermissionState()) {
    _checkPermissionStatus();
  }

  final FirebaseMessaging messaging;

  /// Checks current permission status.
  Future<void> _checkPermissionStatus() async {
    emit(state.copyWith(status: NotificationPermissionStatus.checking));

    try {
      final settings = await messaging.getNotificationSettings();
      _updateStatusFromSettings(settings);
    } catch (e) {
      emit(
        state.copyWith(
          status: NotificationPermissionStatus.denied,
          errorMessage: 'Failed to check permission: $e',
        ),
      );
    }
  }

  /// Requests notification permission.
  Future<void> requestPermission() async {
    emit(state.copyWith(status: NotificationPermissionStatus.checking));

    try {
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      _updateStatusFromSettings(settings);
    } catch (e) {
      emit(
        state.copyWith(
          status: NotificationPermissionStatus.denied,
          errorMessage: 'Failed to request permission: $e',
        ),
      );
    }
  }

  /// Updates state from notification settings.
  void _updateStatusFromSettings(NotificationSettings settings) {
    switch (settings.authorizationStatus) {
      case AuthorizationStatus.authorized:
      case AuthorizationStatus.provisional:
        emit(
          state.copyWith(
            status: NotificationPermissionStatus.granted,
            clearError: true,
          ),
        );
        break;
      case AuthorizationStatus.denied:
        emit(
          state.copyWith(
            status: NotificationPermissionStatus.denied,
            clearError: true,
          ),
        );
        break;
      case AuthorizationStatus.notDetermined:
        emit(
          state.copyWith(
            status: NotificationPermissionStatus.initial,
            clearError: true,
          ),
        );
        break;
    }
  }

  /// Refreshes permission status.
  Future<void> refresh() => _checkPermissionStatus();
}
