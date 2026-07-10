import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';

import '../../domain/core/failure.dart';
import '../../domain/entities/membership.dart';
import '../../domain/entities/payment.dart';
import '../../domain/entities/slot.dart';
import '../../domain/failures/membership_failures.dart';
import '../../domain/repositories/membership_repository.dart';
import '../mappers/membership_mapper.dart';
import '../models/membership_dto.dart';
import '../utils/firebase_error_handler.dart';

/// Firebase implementation of MembershipRepository.
/// Handles both active and pending payment statuses for reservations.
class MembershipRepositoryImpl implements MembershipRepository {
  MembershipRepositoryImpl({required this.firestore});

  final FirebaseFirestore firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      firestore.collection(MembershipDto.collectionName);

  /// Statuses that indicate a seat is actively occupied or reserved.
  /// Used for seat availability checks and validation.
  static const _occupiedStatuses = [
    MembershipStatus.active,
    MembershipStatus.pendingPayment,
  ];

  @override
  Future<Either<Failure, Membership>> createMembership(
    Membership membership,
  ) async {
    return FirebaseErrorHandler.guard(() async {
      final dto = MembershipMapper.toDto(membership);
      await _collection.doc(membership.id).set(dto.toFirestore());
      return membership;
    });
  }

  @override
  Future<Either<Failure, Membership>> getMembershipById(
    String membershipId,
  ) async {
    return FirebaseErrorHandler.guard(() async {
      final doc = await _collection.doc(membershipId).get();
      if (!doc.exists) {
        throw const MembershipNotFoundFailure();
      }
      final dto = MembershipDto.fromFirestore(doc);
      return MembershipMapper.toEntity(dto);
    });
  }

  @override
  Future<Either<Failure, Membership?>> getActiveMembershipByUserAndLibrary({
    required String userId,
    required String libraryId,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      // Get memberships for user+library, filter for active/pending in memory
      final query = await _collection
          .where('userId', isEqualTo: userId)
          .where('libraryId', isEqualTo: libraryId)
          .get();

      final memberships = query.docs
          .map(
            (doc) =>
                MembershipMapper.toEntity(MembershipDto.fromFirestore(doc)),
          )
          .where((m) => _occupiedStatuses.contains(m.status))
          .toList();

      if (memberships.isEmpty) {
        return null;
      }

      return memberships.first;
    });
  }

  @override
  Future<Either<Failure, Membership?>> getActiveMembershipByUserLibraryAndSlot({
    required String userId,
    required String libraryId,
    required Slot slot,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      // Get memberships for user+library+slot, filter for active in memory
      final query = await _collection
          .where('userId', isEqualTo: userId)
          .where('libraryId', isEqualTo: libraryId)
          .where('slot', isEqualTo: slot.name)
          .get();

      final memberships = query.docs
          .map(
            (doc) =>
                MembershipMapper.toEntity(MembershipDto.fromFirestore(doc)),
          )
          .where((m) => m.status == MembershipStatus.active)
          .toList();

      if (memberships.isEmpty) {
        return null;
      }

      return memberships.first;
    });
  }

  @override
  Future<Either<Failure, List<Membership>>>
  getActiveMembershipsByUserAndLibrary({
    required String userId,
    required String libraryId,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      final query = await _collection
          .where('userId', isEqualTo: userId)
          .where('libraryId', isEqualTo: libraryId)
          .get();

      return query.docs
          .map(
            (doc) =>
                MembershipMapper.toEntity(MembershipDto.fromFirestore(doc)),
          )
          .where((m) => m.status == MembershipStatus.active)
          .toList();
    });
  }

  @override
  Future<Either<Failure, List<Membership>>> getMembershipsByUserId(
    String userId,
  ) async {
    return FirebaseErrorHandler.guard(() async {
      final query = await _collection.where('userId', isEqualTo: userId).get();
      return query.docs
          .map(
            (doc) =>
                MembershipMapper.toEntity(MembershipDto.fromFirestore(doc)),
          )
          .toList();
    });
  }

  @override
  Future<Either<Failure, List<Membership>>> getMembershipsByLibraryId(
    String libraryId,
  ) async {
    return FirebaseErrorHandler.guard(() async {
      final query = await _collection
          .where('libraryId', isEqualTo: libraryId)
          .get();
      return query.docs
          .map(
            (doc) =>
                MembershipMapper.toEntity(MembershipDto.fromFirestore(doc)),
          )
          .toList();
    });
  }

  @override
  Future<Either<Failure, List<Membership>>> getActiveMembershipsForLibrary(
    String libraryId,
  ) async {
    return FirebaseErrorHandler.guard(() async {
      // Get all memberships for library, filter active in memory
      final query = await _collection
          .where('libraryId', isEqualTo: libraryId)
          .get();

      return query.docs
          .map(
            (doc) =>
                MembershipMapper.toEntity(MembershipDto.fromFirestore(doc)),
          )
          .where((m) => m.status == MembershipStatus.active)
          .toList();
    });
  }

  @override
  Future<Either<Failure, List<Membership>>>
  getActiveAndReservedMembershipsForLibrary(String libraryId) async {
    return FirebaseErrorHandler.guard(() async {
      // OPTIMIZED: Filter by status at database level using whereIn
      // Only fetch active + pendingPayment (occupied/reserved seats).
      // Expired memberships are handled separately by getExpiredMembershipsWithSeatsForLibrary.
      // Firestore whereIn supports up to 10 values, we only need 2
      final statusValues = _occupiedStatuses.map((s) => s.name).toList();

      final query = await _collection
          .where('libraryId', isEqualTo: libraryId)
          .where('status', whereIn: statusValues)
          .get();

      return query.docs
          .map(
            (doc) =>
                MembershipMapper.toEntity(MembershipDto.fromFirestore(doc)),
          )
          .toList();
    });
  }

  @override
  Future<Either<Failure, bool>> isSeatSlotOccupied({
    required String libraryId,
    required String seatId,
    required Slot slot,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      // PG beds are not time-slot based. A bed is unavailable if any active
      // or pending stay already uses it, regardless of legacy slot value.
      final query = await _collection
          .where('libraryId', isEqualTo: libraryId)
          .where('assignedSeatId', isEqualTo: seatId)
          .get();

      final hasOccupancy = query.docs
          .map(
            (doc) =>
                MembershipMapper.toEntity(MembershipDto.fromFirestore(doc)),
          )
          .any((m) => _occupiedStatuses.contains(m.status));

      return hasOccupancy;
    });
  }

  @override
  Future<Either<Failure, Membership?>> getMembershipBySeatAndSlot({
    required String libraryId,
    required String seatId,
    required Slot slot,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      final query = await _collection
          .where('libraryId', isEqualTo: libraryId)
          .where('assignedSeatId', isEqualTo: seatId)
          .get();

      final memberships = query.docs
          .map(
            (doc) =>
                MembershipMapper.toEntity(MembershipDto.fromFirestore(doc)),
          )
          .where((m) => m.slot == slot && _occupiedStatuses.contains(m.status))
          .toList();

      if (memberships.isEmpty) {
        return null;
      }
      return memberships.first;
    });
  }

  @override
  Future<Either<Failure, List<Membership>>> getMembershipsBySeatId({
    required String libraryId,
    required String seatId,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      final query = await _collection
          .where('libraryId', isEqualTo: libraryId)
          .where('assignedSeatId', isEqualTo: seatId)
          .get();

      return query.docs
          .map(
            (doc) =>
                MembershipMapper.toEntity(MembershipDto.fromFirestore(doc)),
          )
          .where((m) => _occupiedStatuses.contains(m.status))
          .toList();
    });
  }

  @override
  Future<Either<Failure, Membership>> updateMembership(
    Membership membership,
  ) async {
    return FirebaseErrorHandler.guard(() async {
      final dto = MembershipMapper.toDto(membership);
      await _collection.doc(membership.id).update(dto.toFirestore());
      return membership;
    });
  }

  @override
  Future<Either<Failure, List<Membership>>> getExpiredMemberships(
    DateTime currentDate,
  ) async {
    return FirebaseErrorHandler.guard(() async {
      // Normalize to start-of-day so memberships expiring today stay valid.
      final startOfDay = DateTime(
        currentDate.year,
        currentDate.month,
        currentDate.day,
      );

      final query = await _collection
          .where('status', isEqualTo: MembershipStatus.active.name)
          .get();

      return query.docs
          .map(
            (doc) =>
                MembershipMapper.toEntity(MembershipDto.fromFirestore(doc)),
          )
          .where((membership) => membership.endDate.isBefore(startOfDay))
          .toList();
    });
  }

  @override
  Future<Either<Failure, List<Membership>>> getExpiredReservations(
    DateTime currentTime,
    Duration reservationDuration,
  ) async {
    return FirebaseErrorHandler.guard(() async {
      // Get pending payment memberships
      final query = await _collection
          .where('status', isEqualTo: MembershipStatus.pendingPayment.name)
          .get();

      // Filter by createdAt + duration < currentTime
      return query.docs
          .map(
            (doc) =>
                MembershipMapper.toEntity(MembershipDto.fromFirestore(doc)),
          )
          .where((m) {
            if (m.createdAt == null) return false;
            final expiryTime = m.createdAt!.add(reservationDuration);
            return currentTime.isAfter(expiryTime);
          })
          .toList();
    });
  }

  @override
  Future<Either<Failure, void>> batchUpdateMembershipStatus(
    List<Membership> memberships,
  ) async {
    return FirebaseErrorHandler.guard(() async {
      final batch = firestore.batch();

      for (final membership in memberships) {
        final dto = MembershipMapper.toDto(membership);
        batch.update(_collection.doc(membership.id), dto.toFirestore());
      }

      await batch.commit();
    });
  }

  @override
  Future<Either<Failure, List<Membership>>>
  getExpiredMembershipsWithSeatsForLibrary({
    required String libraryId,
    required DateTime currentDate,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      // Get expired memberships (status = expired) OR active memberships with endDate < currentDate
      // that still have assigned seats
      final query = await _collection
          .where('libraryId', isEqualTo: libraryId)
          .get();

      return query.docs
          .map(
            (doc) =>
                MembershipMapper.toEntity(MembershipDto.fromFirestore(doc)),
          )
          .where((m) {
            // Must have assigned seat
            if (m.assignedSeatId == null || m.assignedSeatId!.isEmpty) {
              return false;
            }
            // Normalize dates to compare only date part (ignoring time)
            // A membership ending today should still be valid for the full day
            final currentDateOnly = DateTime(
              currentDate.year,
              currentDate.month,
              currentDate.day,
            );
            final endDateOnly = DateTime(
              m.endDate.year,
              m.endDate.month,
              m.endDate.day,
            );
            // Must be expired (status = expired OR endDate < currentDate)
            return m.status == MembershipStatus.expired ||
                (m.status == MembershipStatus.active &&
                    currentDateOnly.isAfter(endDateOnly));
          })
          .toList();
    });
  }

  @override
  Future<Either<Failure, List<Membership>>> getExpiringMemberships({
    required String libraryId,
    required DateTime currentDate,
    required int daysThreshold,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      // Get active memberships for the library
      final query = await _collection
          .where('libraryId', isEqualTo: libraryId)
          .where('status', isEqualTo: MembershipStatus.active.name)
          .get();

      // Filter memberships expiring within threshold
      // Use daysRemaining to match the logic used in isExpiringSoon
      return query.docs
          .map(
            (doc) =>
                MembershipMapper.toEntity(MembershipDto.fromFirestore(doc)),
          )
          .where((m) {
            // Membership expires within threshold: daysRemaining > 0 and <= daysThreshold
            // This matches the logic in isExpiringSoon (daysRemaining <= 7 && daysRemaining > 0)
            final daysRemaining = m.daysRemaining(currentDate);
            return daysRemaining > 0 && daysRemaining <= daysThreshold;
          })
          .toList();
    });
  }

  @override
  Future<Either<Failure, List<Membership>>> getUnregisteredMembershipsByPhone(
    String phoneNumber,
  ) async {
    return FirebaseErrorHandler.guard(() async {
      // Query memberships by phone number where userId is null
      // Note: Firestore doesn't support querying for null directly,
      // so we query by phoneNumber and filter in memory
      final query = await _collection
          .where('phoneNumber', isEqualTo: phoneNumber)
          .get();

      return query.docs
          .map(
            (doc) =>
                MembershipMapper.toEntity(MembershipDto.fromFirestore(doc)),
          )
          .where((m) => m.userId == null) // Filter unregistered memberships
          .toList();
    });
  }

  @override
  Future<Either<Failure, List<Membership>>> getMembershipsByPhoneNumber(
    String phoneNumber,
  ) async {
    return FirebaseErrorHandler.guard(() async {
      final query = await _collection
          .where('phoneNumber', isEqualTo: phoneNumber)
          .get();

      return query.docs
          .map(
            (doc) =>
                MembershipMapper.toEntity(MembershipDto.fromFirestore(doc)),
          )
          .toList();
    });
  }

  @override
  Future<Either<Failure, List<Membership>>> getPendingApprovalMemberships(
    String libraryId,
  ) async {
    return FirebaseErrorHandler.guard(() async {
      // Get memberships with pendingPayment status for this library
      final query = await _collection
          .where('libraryId', isEqualTo: libraryId)
          .where('status', isEqualTo: MembershipStatus.pendingPayment.name)
          .get();

      // Filter for cash/UPI payments with pending payment status
      return query.docs
          .map(
            (doc) =>
                MembershipMapper.toEntity(MembershipDto.fromFirestore(doc)),
          )
          .where((m) {
            // Must be cash or UPI payment with pending status
            final isCashOrUpi =
                m.paymentMethod == PaymentMode.cash ||
                m.paymentMethod == PaymentMode.upi;
            final isPending =
                m.paymentStatus == MembershipPaymentStatus.pending;
            return isCashOrUpi && isPending;
          })
          .toList();
    });
  }

  @override
  Future<Either<Failure, void>> batchLinkMembershipsToUser({
    required String phoneNumber,
    required String userId,
  }) async {
    // Get all unregistered memberships for this phone number
    final unregisteredResult = await getUnregisteredMembershipsByPhone(
      phoneNumber,
    );

    return unregisteredResult.fold((failure) => Left(failure), (
      memberships,
    ) async {
      if (memberships.isEmpty) {
        return const Right(null);
      }

      // Update all memberships to link userId
      return FirebaseErrorHandler.guard(() async {
        final batch = firestore.batch();
        for (final membership in memberships) {
          final updatedMembership = membership.linkToUser(userId);
          final dto = MembershipMapper.toDto(updatedMembership);
          batch.update(_collection.doc(membership.id), dto.toFirestore());
        }

        await batch.commit();
      });
    });
  }

  @override
  Future<Either<Failure, void>> deleteMembership(String membershipId) async {
    return FirebaseErrorHandler.guard(() async {
      await _collection.doc(membershipId).delete();
    });
  }

  @override
  Future<Either<Failure, Map<String, int>>>
  getActiveMembershipCountsByLibrary() async {
    return FirebaseErrorHandler.guard(() async {
      final snapshot = await _collection
          .where('status', isEqualTo: 'active')
          .get();

      final counts = <String, int>{};
      for (final doc in snapshot.docs) {
        final libraryId = doc.data()['libraryId'] as String?;
        if (libraryId != null) {
          counts[libraryId] = (counts[libraryId] ?? 0) + 1;
        }
      }
      return counts;
    });
  }
}
