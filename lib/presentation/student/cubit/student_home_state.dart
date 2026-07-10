import 'package:equatable/equatable.dart';

import '../../../domain/core/failure.dart';
import '../../../domain/entities/presence.dart';
import '../../../domain/entities/seat.dart';
import '../../../domain/entities/slot.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/usecases/get_student_memberships.dart';

/// State for student home cubit.
class StudentHomeState extends Equatable {
  const StudentHomeState({
    this.status = StudentHomeStatus.initial,
    this.failure,
    this.user,
    this.memberships = const [],
    this.assignedSeat,
    this.todayPresence,
    this.isCheckedIn = false,
    this.isProfilePromptDismissed = false,
    this.canShowExploreLibraries = true,
    this.hasUnregisteredMemberships = false,
    this.isSyncBannerDismissed = false,
    this.documentStatus = DocumentVerificationStatus.none,
  });

  final StudentHomeStatus status;
  final Failure? failure;
  final User? user;
  final List<StudentMembershipInfo> memberships;
  final Seat? assignedSeat;
  final Presence? todayPresence;
  final bool isCheckedIn;

  /// Whether user has dismissed profile completion prompt.
  final bool isProfilePromptDismissed;

  /// Whether explore libraries tile should be shown.
  /// False if any active membership's owner has showOtherLibraries=false.
  final bool canShowExploreLibraries;

  /// Whether there are unregistered memberships that can be synced.
  final bool hasUnregisteredMemberships;

  /// Whether the sync banner has been dismissed.
  final bool isSyncBannerDismissed;

  /// Current verification status of student's identity documents.
  final DocumentVerificationStatus documentStatus;

  bool get isLoading => status == StudentHomeStatus.loading;
  bool get isSuccess => status == StudentHomeStatus.success;
  bool get isFailure => status == StudentHomeStatus.failure;

  /// Whether profile completion prompt should be shown.
  bool get shouldShowProfilePrompt {
    if (user == null) return false;
    if (isProfilePromptDismissed) return false;
    return !user!.isProfileComplete;
  }

  /// Check if user has any memberships.
  bool get hasMemberships => memberships.isNotEmpty;

  /// Get morning slot membership if exists.
  StudentMembershipInfo? get morningMembership =>
      memberships.cast<StudentMembershipInfo?>().firstWhere(
        (m) => m?.membership.slot == Slot.morning,
        orElse: () => null,
      );

  /// Get evening slot membership if exists.
  StudentMembershipInfo? get eveningMembership =>
      memberships.cast<StudentMembershipInfo?>().firstWhere(
        (m) => m?.membership.slot == Slot.evening,
        orElse: () => null,
      );

  /// Check if any membership is pending payment.
  bool get hasPendingPayment => memberships.any((m) => m.isPendingPayment);

  /// Check if any membership is active.
  bool get hasActiveMembership => memberships.any((m) => m.isActive);

  /// Get the first active membership (for My Library card).
  StudentMembershipInfo? get activeMembership => memberships
      .cast<StudentMembershipInfo?>()
      .firstWhere((m) => m?.isActive == true, orElse: () => null);

  /// Get all active memberships (for My Library section).
  List<StudentMembershipInfo> get activeMemberships =>
      memberships.where((m) => m.isActive).toList();

  /// Get library ID from first membership.
  String? get libraryId =>
      memberships.isNotEmpty ? memberships.first.membership.libraryId : null;

  StudentHomeState copyWith({
    StudentHomeStatus? status,
    Failure? failure,
    User? user,
    List<StudentMembershipInfo>? memberships,
    Seat? assignedSeat,
    Presence? todayPresence,
    bool? isCheckedIn,
    bool? isProfilePromptDismissed,
    bool? canShowExploreLibraries,
    bool? hasUnregisteredMemberships,
    bool? isSyncBannerDismissed,
    DocumentVerificationStatus? documentStatus,
    bool clearFailure = false,
  }) {
    return StudentHomeState(
      status: status ?? this.status,
      failure: clearFailure ? null : (failure ?? this.failure),
      user: user ?? this.user,
      memberships: memberships ?? this.memberships,
      assignedSeat: assignedSeat ?? this.assignedSeat,
      todayPresence: todayPresence ?? this.todayPresence,
      isCheckedIn: isCheckedIn ?? this.isCheckedIn,
      isProfilePromptDismissed:
          isProfilePromptDismissed ?? this.isProfilePromptDismissed,
      canShowExploreLibraries:
          canShowExploreLibraries ?? this.canShowExploreLibraries,
      hasUnregisteredMemberships:
          hasUnregisteredMemberships ?? this.hasUnregisteredMemberships,
      isSyncBannerDismissed:
          isSyncBannerDismissed ?? this.isSyncBannerDismissed,
      documentStatus: documentStatus ?? this.documentStatus,
    );
  }

  @override
  List<Object?> get props => [
    status,
    failure,
    user,
    memberships,
    assignedSeat,
    todayPresence,
    isCheckedIn,
    isProfilePromptDismissed,
    canShowExploreLibraries,
    hasUnregisteredMemberships,
    isSyncBannerDismissed,
    documentStatus,
  ];
}

/// Status for student home screen.
enum StudentHomeStatus { initial, loading, success, failure }

/// Verification status of student identity documents.
/// Drives the contextual button label in the membership card.
enum DocumentVerificationStatus {
  /// No documents uploaded yet.
  none,

  /// At least one document uploaded but not all approved.
  pending,

  /// All uploaded documents are approved.
  verified,
}
