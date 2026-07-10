import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';

import '../../domain/core/failure.dart';
import '../../domain/entities/payment.dart';
import '../../domain/failures/payment_failures.dart';
import '../../domain/repositories/payment_repository.dart';
import '../mappers/payment_mapper.dart';
import '../models/payment_dto.dart';
import '../utils/firebase_error_handler.dart';

/// Firebase implementation of PaymentRepository.
class PaymentRepositoryImpl implements PaymentRepository {
  PaymentRepositoryImpl({required this.firestore});

  final FirebaseFirestore firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      firestore.collection(PaymentDto.collectionName);

  @override
  Future<Either<Failure, Payment>> createPayment(Payment payment) async {
    return FirebaseErrorHandler.guard(() async {
      final dto = PaymentMapper.toDto(payment);
      await _collection.doc(payment.id).set(dto.toFirestore());
      return payment;
    });
  }

  @override
  Future<Either<Failure, Payment>> getPaymentById(String paymentId) async {
    return FirebaseErrorHandler.guard(() async {
      final doc = await _collection.doc(paymentId).get();
      if (!doc.exists) {
        throw const PaymentNotFoundFailure();
      }
      final dto = PaymentDto.fromFirestore(doc);
      return PaymentMapper.toEntity(dto);
    });
  }

  @override
  Future<Either<Failure, Payment?>> getPaymentByMembershipId(
    String membershipId,
  ) async {
    return FirebaseErrorHandler.guard(() async {
      final query = await _collection
          .where('membershipId', isEqualTo: membershipId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return null;
      }

      final dto = PaymentDto.fromFirestore(query.docs.first);
      return PaymentMapper.toEntity(dto);
    });
  }

  @override
  Future<Either<Failure, List<Payment>>> getPaymentsByMembershipId(
    String membershipId,
  ) async {
    return FirebaseErrorHandler.guard(() async {
      final query = await _collection
          .where('membershipId', isEqualTo: membershipId)
          .get();

      final payments = query.docs
          .map((doc) => PaymentMapper.toEntity(PaymentDto.fromFirestore(doc)))
          .toList();

      // Sort by created date ascending (oldest first) for cumulative calculation
      payments.sort((a, b) {
        if (a.createdAt == null && b.createdAt == null) return 0;
        if (a.createdAt == null) return 1;
        if (b.createdAt == null) return -1;
        return a.createdAt!.compareTo(b.createdAt!);
      });

      return payments;
    });
  }

  @override
  Future<Either<Failure, Payment?>> getPendingPaymentByMembershipId(
    String membershipId,
  ) async {
    return FirebaseErrorHandler.guard(() async {
      final query = await _collection
          .where('membershipId', isEqualTo: membershipId)
          .where('status', isEqualTo: PaymentStatus.initiated.name)
          .get();

      if (query.docs.isEmpty) {
        return null;
      }

      final dto = PaymentDto.fromFirestore(query.docs.first);
      return PaymentMapper.toEntity(dto);
    });
  }

  @override
  Future<Either<Failure, Payment>> updatePayment(Payment payment) async {
    return FirebaseErrorHandler.guard(() async {
      final dto = PaymentMapper.toDto(payment);
      await _collection.doc(payment.id).update(dto.toFirestore());
      return payment;
    });
  }

  @override
  Future<Either<Failure, List<Payment>>> getExpiredPendingPayments(
    DateTime currentTime,
  ) async {
    return FirebaseErrorHandler.guard(() async {
      // Get initiated payments, filter expired in memory to avoid index
      final query = await _collection
          .where('status', isEqualTo: PaymentStatus.initiated.name)
          .get();

      final payments = query.docs
          .map((doc) => PaymentMapper.toEntity(PaymentDto.fromFirestore(doc)))
          .where((payment) => payment.isExpired(currentTime))
          .toList();

      return payments;
    });
  }

  @override
  Future<Either<Failure, List<Payment>>> getPendingCashPayments(
    String libraryId,
  ) async {
    return FirebaseErrorHandler.guard(() async {
      // Query for cash payments with initiated status
      final query = await _collection
          .where('libraryId', isEqualTo: libraryId)
          .where('mode', isEqualTo: PaymentMode.cash.name)
          .where('status', isEqualTo: PaymentStatus.initiated.name)
          .get();

      final payments = query.docs
          .map((doc) => PaymentMapper.toEntity(PaymentDto.fromFirestore(doc)))
          .toList();

      // Sort by created date descending
      payments.sort((a, b) {
        if (a.createdAt == null && b.createdAt == null) return 0;
        if (a.createdAt == null) return 1;
        if (b.createdAt == null) return -1;
        return b.createdAt!.compareTo(a.createdAt!);
      });

      return payments;
    });
  }

  @override
  Future<Either<Failure, List<Payment>>> getPendingApprovalPayments(
    String libraryId,
  ) async {
    return FirebaseErrorHandler.guard(() async {
      // Query for initiated payments (cash or UPI)
      final query = await _collection
          .where('libraryId', isEqualTo: libraryId)
          .where('status', isEqualTo: PaymentStatus.initiated.name)
          .get();

      // Filter in memory: cash or (UPI with studentMarkedPaidAt)
      final payments = query.docs
          .map((doc) => PaymentMapper.toEntity(PaymentDto.fromFirestore(doc)))
          .where(
            (payment) =>
                payment.mode == PaymentMode.cash ||
                (payment.mode == PaymentMode.upi &&
                    payment.studentMarkedPaidAt != null),
          )
          .toList();

      // Sort by created date descending
      payments.sort((a, b) {
        if (a.createdAt == null && b.createdAt == null) return 0;
        if (a.createdAt == null) return 1;
        if (b.createdAt == null) return -1;
        return b.createdAt!.compareTo(a.createdAt!);
      });

      return payments;
    });
  }

  @override
  Future<Either<Failure, List<Payment>>> getCompletedPayments({
    required String libraryId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      // Query for successful payments
      Query<Map<String, dynamic>> query = _collection
          .where('libraryId', isEqualTo: libraryId)
          .where('status', isEqualTo: PaymentStatus.success.name);

      // Apply date filters using updatedAt (completion time)
      if (startDate != null) {
        query = query.where(
          'updatedAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }
      if (endDate != null) {
        query = query.where(
          'updatedAt',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
      }

      final querySnapshot = await query.get();

      // Filter out refunded payments from revenue calculations
      return querySnapshot.docs
          .map((doc) => PaymentMapper.toEntity(PaymentDto.fromFirestore(doc)))
          .where((payment) => !payment.isRefunded)
          .toList();
    });
  }

  @override
  Future<Either<Failure, List<Payment>>> getPaymentsByLibraryId(
    String libraryId,
  ) async {
    return FirebaseErrorHandler.guard(() async {
      final querySnapshot = await _collection
          .where('libraryId', isEqualTo: libraryId)
          .get();

      return querySnapshot.docs
          .map((doc) => PaymentMapper.toEntity(PaymentDto.fromFirestore(doc)))
          .toList();
    });
  }

  @override
  Future<Either<Failure, void>> deletePayment(String paymentId) async {
    return FirebaseErrorHandler.guard(() async {
      await _collection.doc(paymentId).delete();
    });
  }
}
