import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../entities/user.dart';
import '../repositories/membership_repository.dart';
import '../repositories/user_repository.dart';
import 'get_occupied_seats.dart';

/// Use case for retrieving expired memberships with seat assignments.
/// Returns all expired memberships for a library that still have assigned seats.
/// No filtering is applied -- expired memberships stay visible until the owner
/// explicitly removes them.
class GetExpiredSeats
    implements UseCase<List<OccupiedSeatInfo>, GetExpiredSeatsParams> {
  const GetExpiredSeats({
    required this.membershipRepository,
    required this.userRepository,
  });

  final MembershipRepository membershipRepository;
  final UserRepository userRepository;

  @override
  Future<Either<Failure, List<OccupiedSeatInfo>>> call(
    GetExpiredSeatsParams params,
  ) async {
    if (params.libraryId.trim().isEmpty) {
      return const Right([]);
    }

    final result = await membershipRepository
        .getExpiredMembershipsWithSeatsForLibrary(
          libraryId: params.libraryId,
          currentDate: params.currentDate,
        );

    return result.fold((failure) => Left(failure), (memberships) async {
      final membershipsWithSeats = memberships
          .where(
            (m) => m.assignedSeatId != null && m.assignedSeatId!.isNotEmpty,
          )
          .toList();

      // Collect all userIds for batch fetch
      final userIds = membershipsWithSeats
          .where((m) => m.userId != null)
          .map((m) => m.userId!)
          .toSet()
          .toList();

      Map<String, User> usersMap = {};
      if (userIds.isNotEmpty) {
        final usersResult = await userRepository.getUsersByIds(userIds);
        usersResult.fold((_) {}, (users) {
          usersMap = users;
        });
      }

      final expiredSeats = membershipsWithSeats.map((membership) {
        String? studentName;
        String? studentPhone = membership.phoneNumber;
        String? studentAvatarUrl;

        if (membership.userId != null) {
          final user = usersMap[membership.userId];
          if (user != null) {
            studentName = user.displayName;
            studentPhone = user.phone;
            studentAvatarUrl = user.avatarUrl;
          }
        } else {
          studentName = membership.studentName;
        }

        return OccupiedSeatInfo(
          seatId: membership.assignedSeatId!,
          membership: membership,
          studentName: studentName,
          studentPhone: studentPhone,
          studentAvatarUrl: studentAvatarUrl,
        );
      }).toList();

      // Sort by expiry date (most recently expired first)
      expiredSeats.sort((a, b) {
        return b.membership.endDate.compareTo(a.membership.endDate);
      });

      return Right(expiredSeats);
    });
  }
}

/// Parameters for GetExpiredSeats use case.
class GetExpiredSeatsParams extends Equatable {
  const GetExpiredSeatsParams({
    required this.libraryId,
    required this.currentDate,
  });

  final String libraryId;
  final DateTime currentDate;

  @override
  List<Object?> get props => [libraryId, currentDate];
}
