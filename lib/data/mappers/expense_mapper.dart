import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/expense.dart';
import '../models/expense_dto.dart';

/// Mapper for Expense entity <-> ExpenseDto conversion.
class ExpenseMapper {
  const ExpenseMapper._();

  static Expense toEntity(ExpenseDto dto) {
    return Expense(
      id: dto.id,
      libraryId: dto.libraryId,
      title: dto.title,
      amount: dto.amount,
      category: _parseCategory(dto.category),
      date: dto.date.toDate(),
      description: dto.description,
      createdAt: dto.createdAt?.toDate(),
    );
  }

  static ExpenseDto toDto(Expense entity) {
    return ExpenseDto(
      id: entity.id,
      libraryId: entity.libraryId,
      title: entity.title,
      amount: entity.amount,
      category: entity.category.name,
      date: Timestamp.fromDate(entity.date),
      description: entity.description,
      createdAt: entity.createdAt != null
          ? Timestamp.fromDate(entity.createdAt!)
          : Timestamp.now(),
    );
  }

  static ExpenseCategory _parseCategory(String value) {
    return ExpenseCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ExpenseCategory.other,
    );
  }
}
