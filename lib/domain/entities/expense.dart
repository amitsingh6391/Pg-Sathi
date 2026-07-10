import 'package:equatable/equatable.dart';

/// Expense categories for library operations.
enum ExpenseCategory {
  rent,
  electricity,
  salary,
  maintenance,
  supplies,
  internet,
  other;

  String get displayName {
    switch (this) {
      case rent:
        return 'Rent';
      case electricity:
        return 'Electricity';
      case salary:
        return 'Salary';
      case maintenance:
        return 'Maintenance';
      case supplies:
        return 'Supplies';
      case internet:
        return 'Internet';
      case other:
        return 'Other';
    }
  }
}

/// Represents an expense entry for a library.
class Expense extends Equatable {
  const Expense({
    required this.id,
    required this.libraryId,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    this.description,
    this.createdAt,
  });

  final String id;
  final String libraryId;
  final String title;
  final double amount;
  final ExpenseCategory category;
  final DateTime date;
  final String? description;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [
    id,
    libraryId,
    title,
    amount,
    category,
    date,
    description,
    createdAt,
  ];
}
