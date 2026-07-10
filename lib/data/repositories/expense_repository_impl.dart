import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';

import '../../domain/core/failure.dart';
import '../../domain/entities/expense.dart';
import '../../domain/repositories/expense_repository.dart';
import '../mappers/expense_mapper.dart';
import '../models/expense_dto.dart';
import '../utils/firebase_error_handler.dart';

/// Firebase implementation of ExpenseRepository.
class ExpenseRepositoryImpl implements ExpenseRepository {
  ExpenseRepositoryImpl({required this.firestore});

  final FirebaseFirestore firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      firestore.collection(ExpenseDto.collectionName);

  @override
  Future<Either<Failure, Expense>> addExpense(Expense expense) async {
    return FirebaseErrorHandler.guard(() async {
      final dto = ExpenseMapper.toDto(expense);
      await _collection.doc(expense.id).set(dto.toFirestore());
      return expense;
    });
  }

  @override
  Future<Either<Failure, List<Expense>>> getExpenses({
    required String libraryId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      Query<Map<String, dynamic>> query =
          _collection.where('libraryId', isEqualTo: libraryId);

      if (startDate != null) {
        query = query.where(
          'date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }
      if (endDate != null) {
        query = query.where(
          'date',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
      }

      final snapshot = await query.orderBy('date', descending: true).get();

      return snapshot.docs
          .map((doc) => ExpenseMapper.toEntity(ExpenseDto.fromFirestore(doc)))
          .toList();
    });
  }

  @override
  Future<Either<Failure, void>> deleteExpense(String expenseId) async {
    return FirebaseErrorHandler.guard(() async {
      await _collection.doc(expenseId).delete();
    });
  }
}
