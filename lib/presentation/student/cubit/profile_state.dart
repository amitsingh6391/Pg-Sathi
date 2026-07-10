import 'package:equatable/equatable.dart';

import '../../../domain/entities/user.dart';

/// Status of profile operations.
enum ProfileStatus { initial, saving, success, error }

/// State for ProfileCubit.
class ProfileState extends Equatable {
  const ProfileState({
    this.user,
    this.name = '',
    this.avatarUrl,
    this.examPreparingFor,
    this.isAccessCardIssued = false,
    this.address,
    this.gender,
    this.status = ProfileStatus.initial,
    this.errorMessage,
    this.isPromptDismissed = false,
  });

  final User? user;
  final String name;
  final String? avatarUrl;
  final String? examPreparingFor;
  final bool isAccessCardIssued;
  final String? address;
  final String? gender;
  final ProfileStatus status;
  final String? errorMessage;

  /// Whether the user has dismissed the profile completion prompt.
  final bool isPromptDismissed;

  /// Whether profile completion prompt should be shown.
  bool get shouldShowPrompt {
    if (user == null) return false;
    if (isPromptDismissed) return false;
    return !user!.isProfileComplete;
  }

  bool get isSaving => status == ProfileStatus.saving;
  bool get isSuccess => status == ProfileStatus.success;
  bool get isError => status == ProfileStatus.error;

  /// Whether the current name input is valid.
  bool get isNameValid => name.trim().length >= 2;

  ProfileState copyWith({
    User? user,
    String? name,
    String? avatarUrl,
    String? examPreparingFor,
    bool? isAccessCardIssued,
    String? address,
    String? gender,
    ProfileStatus? status,
    String? errorMessage,
    bool? isPromptDismissed,
  }) {
    return ProfileState(
      user: user ?? this.user,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      examPreparingFor: examPreparingFor ?? this.examPreparingFor,
      isAccessCardIssued: isAccessCardIssued ?? this.isAccessCardIssued,
      address: address ?? this.address,
      gender: gender ?? this.gender,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      isPromptDismissed: isPromptDismissed ?? this.isPromptDismissed,
    );
  }

  @override
  List<Object?> get props => [
    user,
    name,
    avatarUrl,
    examPreparingFor,
    isAccessCardIssued,
    address,
    gender,
    status,
    errorMessage,
    isPromptDismissed,
  ];
}
