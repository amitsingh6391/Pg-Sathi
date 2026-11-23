import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../entities/manager_access.dart';
import '../failures/user_failures.dart';
import '../repositories/manager_repository.dart';

/// Gives a 10-digit mobile number access to one of the owner's libraries.
class InviteManager implements UseCase<void, InviteManagerParams> {
  const InviteManager({required this.managerRepository});

  final ManagerRepository managerRepository;

  @override
  Future<Either<Failure, void>> call(InviteManagerParams params) async {
    final digits = params.mobile.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) {
      return const Left(
        InvalidUserDataFailure(message: 'Enter a valid 10-digit mobile number'),
      );
    }
    return managerRepository.inviteManager(
      phone: '+91$digits',
      ownerId: params.ownerId,
      libraryId: params.libraryId,
    );
  }
}

class InviteManagerParams extends Equatable {
  const InviteManagerParams({
    required this.ownerId,
    required this.libraryId,
    required this.mobile,
  });

  final String ownerId;
  final String libraryId;
  final String mobile;

  @override
  List<Object?> get props => [ownerId, libraryId, mobile];
}

class GetManagers implements UseCase<List<ManagerAccess>, String> {
  const GetManagers({required this.managerRepository});

  final ManagerRepository managerRepository;

  @override
  Future<Either<Failure, List<ManagerAccess>>> call(String ownerId) {
    return managerRepository.getManagers(ownerId);
  }
}

class RevokeManager implements UseCase<void, ManagerAccess> {
  const RevokeManager({required this.managerRepository});

  final ManagerRepository managerRepository;

  @override
  Future<Either<Failure, void>> call(ManagerAccess access) {
    return managerRepository.revokeManager(access);
  }
}
