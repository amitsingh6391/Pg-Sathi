import 'package:cloud_firestore/cloud_firestore.dart';

/// Data Transfer Object for Expense entity.
class ExpenseDto {
  const ExpenseDto({
    required this.id,
    required this.libraryId,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    this.description,
    this.createdAt,
  });

  static const collectionName = 'expenses';

  final String id;
  final String libraryId;
  final String title;
  final double amount;
  final String category;
  final Timestamp date;
  final String? description;
  final Timestamp? createdAt;

  factory ExpenseDto.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ExpenseDto(
      id: doc.id,
      libraryId: data['libraryId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      category: data['category'] as String? ?? 'other',
      date: data['date'] as Timestamp? ?? Timestamp.now(),
      description: data['description'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'libraryId': libraryId,
      'title': title,
      'amount': amount,
      'category': category,
      'date': date,
      'description': description,
      'createdAt': createdAt,
    };
  }
}
