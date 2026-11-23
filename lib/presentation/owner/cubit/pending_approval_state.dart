import 'package:equatable/equatable.dart';

import '../../../domain/entities/membership.dart';

enum PendingApprovalStatus { initial, loading, loaded, error }

/// State for the owner's list of resident bed requests.
class PendingApprovalState extends Equatable {
  const PendingApprovalState({
    this.status = PendingApprovalStatus.initial,
    this.memberships = const [],
    this.userNames = const {},
    this.slotNames = const {},
    this.slotPrices = const {},
    this.processingIds = const {},
    this.errorMessage,
    this.infoMessage,
  });

  final PendingApprovalStatus status;
  final List<Membership> memberships;
  final Map<String, String> userNames;
  final Map<String, String> slotNames;
  final Map<String, double> slotPrices;

  /// Membership ids with an approve/reject in flight (disable their buttons).
  final Set<String> processingIds;
  final String? errorMessage;

  /// One-shot success message (e.g. "Request approved").
  final String? infoMessage;

  bool get isLoading => status == PendingApprovalStatus.loading;

  PendingApprovalState copyWith({
    PendingApprovalStatus? status,
    List<Membership>? memberships,
    Map<String, String>? userNames,
    Map<String, String>? slotNames,
    Map<String, double>? slotPrices,
    Set<String>? processingIds,
    String? errorMessage,
    String? infoMessage,
  }) {
    return PendingApprovalState(
      status: status ?? this.status,
      memberships: memberships ?? this.memberships,
      userNames: userNames ?? this.userNames,
      slotNames: slotNames ?? this.slotNames,
      slotPrices: slotPrices ?? this.slotPrices,
      processingIds: processingIds ?? this.processingIds,
      errorMessage: errorMessage,
      infoMessage: infoMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    memberships,
    userNames,
    slotNames,
    slotPrices,
    processingIds,
    errorMessage,
    infoMessage,
  ];
}
