import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../entities/user.dart';
import '../failures/auth_failures.dart';
import '../repositories/auth_repository.dart';

/// Use case for updating user profile.
/// Marks profile as complete after setting required fields.
class UpdateUserProfile implements UseCase<User, UpdateUserProfileParams> {
  const UpdateUserProfile({required this.authRepository});

  final AuthRepository authRepository;

  @override
  Future<Either<Failure, User>> call(UpdateUserProfileParams params) async {
    // Validate name
    if (params.name.trim().isEmpty) {
      return const Left(
        InvalidPhoneNumberFailure(message: 'Name cannot be empty'),
      );
    }

    if (params.name.trim().length < 2) {
      return const Left(
        InvalidPhoneNumberFailure(
          message: 'Name must be at least 2 characters',
        ),
      );
    }

    return authRepository.updateUserProfile(
      userId: params.userId,
      name: params.name.trim(),
      avatarUrl: params.avatarUrl,
      examPreparingFor: params.examPreparingFor,
      isAccessCardIssued: params.isAccessCardIssued,
      address: params.address,
      gender: params.gender,
    );
  }
}

/// Parameters for UpdateUserProfile use case.
class UpdateUserProfileParams extends Equatable {
  const UpdateUserProfileParams({
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.examPreparingFor,
    this.isAccessCardIssued,
    this.address,
    this.gender,
  });

  final String userId;
  final String name;
  final String? avatarUrl;
  final String? examPreparingFor;
  final bool? isAccessCardIssued;
  final String? address;
  final String? gender;

  @override
  List<Object?> get props => [
    userId,
    name,
    avatarUrl,
    examPreparingFor,
    isAccessCardIssued,
    address,
    gender,
  ];
}
