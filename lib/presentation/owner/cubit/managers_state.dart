import 'package:equatable/equatable.dart';

import '../../../domain/entities/library.dart';
import '../../../domain/entities/manager_access.dart';

enum ManagersStatus { loading, loaded, saving, error }

class ManagersState extends Equatable {
  const ManagersState({
    this.status = ManagersStatus.loading,
    this.managers = const [],
    this.libraries = const [],
    this.errorMessage,
  });

  final ManagersStatus status;
  final List<ManagerAccess> managers;

  /// The owner's PGs (branches); managers are given access per branch.
  final List<Library> libraries;
  final String? errorMessage;

  ManagersState copyWith({
    ManagersStatus? status,
    List<ManagerAccess>? managers,
    List<Library>? libraries,
    String? errorMessage,
  }) {
    return ManagersState(
      status: status ?? this.status,
      managers: managers ?? this.managers,
      libraries: libraries ?? this.libraries,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, managers, libraries, errorMessage];
}
