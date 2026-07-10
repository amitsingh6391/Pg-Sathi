import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

import '../../domain/core/failure.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/repositories/invoice_repository.dart';
import '../failures/data_failures.dart';
import '../mappers/invoice_mapper.dart';
import '../models/invoice_dto.dart';
import '../utils/firebase_error_handler.dart';

/// Firestore implementation of InvoiceRepository.
class InvoiceRepositoryImpl implements InvoiceRepository {
  InvoiceRepositoryImpl({required FirebaseFirestore firestore})
    : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(InvoiceDto.collectionName);

  @override
  Future<Either<Failure, Invoice>> createInvoice(Invoice invoice) async {
    try {
      final dto = InvoiceMapper.toDto(invoice);
      await _collection.doc(invoice.id).set(dto.toFirestore());
      return Right(invoice);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Invoice?>> getInvoiceById(String invoiceId) async {
    try {
      final doc = await _collection.doc(invoiceId).get();
      if (!doc.exists) {
        return const Right(null);
      }
      final invoice = InvoiceMapper.toEntity(InvoiceDto.fromFirestore(doc));
      return Right(invoice);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Invoice?>> getInvoiceByMembershipAndMonth({
    required String membershipId,
    required String billingMonth,
  }) async {
    try {
      final query = await _collection
          .where('membershipId', isEqualTo: membershipId)
          .where('billingMonth', isEqualTo: billingMonth)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return const Right(null);
      }

      final invoice = InvoiceMapper.toEntity(
        InvoiceDto.fromFirestore(query.docs.first),
      );
      return Right(invoice);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Invoice?>> getInvoiceByPaymentId(
    String paymentId,
  ) async {
    try {
      final query = await _collection
          .where('paymentId', isEqualTo: paymentId)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return const Right(null);
      }

      final invoice = InvoiceMapper.toEntity(
        InvoiceDto.fromFirestore(query.docs.first),
      );
      return Right(invoice);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Invoice>>> getInvoicesForStudent(
    String studentId,
  ) async {
    try {
      final query = await _collection
          .where('studentId', isEqualTo: studentId)
          .get();

      final invoices = query.docs
          .map((doc) => InvoiceMapper.toEntity(InvoiceDto.fromFirestore(doc)))
          .toList();

      invoices.sort((a, b) => b.generatedAt.compareTo(a.generatedAt));

      return Right(invoices);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Invoice>>> getInvoicesForOwner(
    String ownerId,
  ) async {
    try {
      final query = await _collection
          .where('ownerId', isEqualTo: ownerId)
          .get();

      final invoices = query.docs
          .map((doc) => InvoiceMapper.toEntity(InvoiceDto.fromFirestore(doc)))
          .toList();

      invoices.sort((a, b) => b.generatedAt.compareTo(a.generatedAt));

      return Right(invoices);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Invoice>>> getInvoicesForLibrary(
    String libraryId,
  ) async {
    try {
      // Try query with orderBy first (requires composite index)
      try {
        final query = await _collection
            .where('libraryId', isEqualTo: libraryId)
            .orderBy('generatedAt', descending: true)
            .get();

        final invoices = query.docs
            .map((doc) => InvoiceMapper.toEntity(InvoiceDto.fromFirestore(doc)))
            .toList();

        return Right(invoices);
      } catch (e) {
        // If index error, fall back to query without orderBy
        if (e.toString().contains('index') ||
            e.toString().contains('requires an index')) {
          if (kDebugMode) {
            print('⚠️  Index not found, using fallback query without orderBy');
          }

          // Fallback: Query without orderBy, then sort in memory
          final query = await _collection
              .where('libraryId', isEqualTo: libraryId)
              .get();

          final invoices = query.docs
              .map(
                (doc) => InvoiceMapper.toEntity(InvoiceDto.fromFirestore(doc)),
              )
              .toList();

          // Sort by generatedAt descending (newest first)
          invoices.sort((a, b) => b.generatedAt.compareTo(a.generatedAt));

          return Right(invoices);
        }
        // Re-throw if it's not an index error
        rethrow;
      }
    } catch (e) {
      // Print Firestore error which may contain index creation link (debug only)
      if (kDebugMode) {
        print('❌ Firestore Error: $e');
        if (e.toString().contains('index')) {
          print('💡 Look for the index creation link in the error above!');
          print(
            '   Or create manually: Collection=${InvoiceDto.collectionName}, Fields=libraryId(Asc)+generatedAt(Desc)',
          );
        }
      }
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> generateInvoiceNumber(
    String libraryId,
  ) async {
    try {
      // Get current year
      final now = DateTime.now();
      final year = now.year;

      // Count existing invoices for this library this year
      final startOfYear = DateTime(year, 1, 1);
      final query = await _collection
          .where('libraryId', isEqualTo: libraryId)
          .where(
            'generatedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfYear),
          )
          .get();

      final count = query.docs.length + 1;
      final invoiceNumber = 'INV-$year-${count.toString().padLeft(6, '0')}';

      return Right(invoiceNumber);
    } catch (e) {
      // Fallback to timestamp-based number
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      return Right('INV-$timestamp');
    }
  }

  @override
  Future<Either<Failure, void>> batchLinkInvoicesToUser({
    required String phoneNumber,
    required String userId,
  }) async {
    try {
      // Find all invoices where studentId is the phone number
      final query = await _collection
          .where('studentId', isEqualTo: phoneNumber)
          .get();

      if (query.docs.isEmpty) {
        return const Right(null);
      }

      // Batch update all invoices to use the new userId
      final batch = _firestore.batch();
      for (final doc in query.docs) {
        batch.update(doc.reference, {'studentId': userId});
      }

      await batch.commit();
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Invoice>>> getInvoicesByMembershipIds(
    List<String> membershipIds,
  ) async {
    try {
      if (membershipIds.isEmpty) {
        return const Right([]);
      }

      // Firestore 'in' query supports up to 10 items
      // Split into batches if needed
      final allInvoices = <Invoice>[];
      for (var i = 0; i < membershipIds.length; i += 10) {
        final batch = membershipIds.skip(i).take(10).toList();
        final query = await _collection
            .where('membershipId', whereIn: batch)
            .orderBy('generatedAt', descending: true)
            .get();

        final invoices = query.docs
            .map((doc) => InvoiceMapper.toEntity(InvoiceDto.fromFirestore(doc)))
            .toList();
        allInvoices.addAll(invoices);
      }

      // Sort by generatedAt descending (newest first)
      allInvoices.sort((a, b) => b.generatedAt.compareTo(a.generatedAt));

      return Right(allInvoices);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteInvoice(String invoiceId) async {
    return FirebaseErrorHandler.guard(() async {
      await _collection.doc(invoiceId).delete();
    });
  }

  @override
  Future<Either<Failure, Invoice>> updateInvoice(Invoice invoice) async {
    try {
      final dto = InvoiceMapper.toDto(invoice);
      await _collection.doc(invoice.id).update(dto.toFirestore());
      return Right(invoice);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
