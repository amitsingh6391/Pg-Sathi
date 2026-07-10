import 'package:equatable/equatable.dart';

import '../../../domain/core/failure.dart';
import '../../../domain/entities/custom_slot.dart';

/// State for slot management cubit.
class SlotManagementState extends Equatable {
  const SlotManagementState({
    this.status = SlotManagementStatus.initial,
    this.slots = const [],
    this.failure,
    this.successMessage,
  });

  final SlotManagementStatus status;
  final List<CustomSlot> slots;
  final Failure? failure;
  final String? successMessage;

  bool get isLoading => status == SlotManagementStatus.loading;
  bool get isSubmitting => status == SlotManagementStatus.submitting;
  bool get isLoaded => status == SlotManagementStatus.loaded;
  bool get hasError => status == SlotManagementStatus.error;
  bool get hasSuccess => status == SlotManagementStatus.success;

  @override
  List<Object?> get props => [status, slots, failure, successMessage];

  SlotManagementState copyWith({
    SlotManagementStatus? status,
    List<CustomSlot>? slots,
    Failure? failure,
    String? successMessage,
    bool clearFailure = false,
    bool clearSuccessMessage = false,
  }) {
    return SlotManagementState(
      status: status ?? this.status,
      slots: slots ?? this.slots,
      failure: clearFailure ? null : (failure ?? this.failure),
      successMessage: clearSuccessMessage
          ? null
          : (successMessage ?? this.successMessage),
    );
  }
}

enum SlotManagementStatus {
  initial,
  loading,
  loaded,
  submitting,
  success,
  error,
}
