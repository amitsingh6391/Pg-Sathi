import 'package:dartz/dartz.dart';

import '../core/failure.dart';
import '../entities/expense.dart';

/// Repository interface for Expense aggregate.
abstract class ExpenseRepository {
  Future<Either<Failure, Expense>> addExpense(Expense expense);

  Future<Either<Failure, List<Expense>>> getExpenses({
    required String libraryId,
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<Either<Failure, void>> deleteExpense(String expenseId);
}
