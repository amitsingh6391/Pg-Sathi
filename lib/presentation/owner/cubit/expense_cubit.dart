import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/entities/expense.dart';
import '../../../domain/repositories/expense_repository.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class ExpenseState extends Equatable {
  ExpenseState({
    this.expenses = const [],
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
    this.savedSuccessfully = false,
    DateTime? selectedMonth,
  }) : selectedMonth = selectedMonth ?? DateTime(DateTime.now().year, DateTime.now().month);

  final List<Expense> expenses;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final bool savedSuccessfully;

  /// First day of the currently selected month.
  final DateTime selectedMonth;

  double get monthTotal =>
      expenses.fold<double>(0, (sum, e) => sum + e.amount);

  bool get isCurrentMonth {
    final now = DateTime.now();
    return selectedMonth.year == now.year && selectedMonth.month == now.month;
  }

  ExpenseState copyWith({
    List<Expense>? expenses,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    bool? savedSuccessfully,
    DateTime? selectedMonth,
  }) {
    return ExpenseState(
      expenses: expenses ?? this.expenses,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage,
      savedSuccessfully: savedSuccessfully ?? false,
      selectedMonth: selectedMonth ?? this.selectedMonth,
    );
  }

  @override
  List<Object?> get props => [
    expenses,
    isLoading,
    isSaving,
    errorMessage,
    savedSuccessfully,
    selectedMonth,
  ];
}

// ---------------------------------------------------------------------------
// Cubit
// ---------------------------------------------------------------------------

class ExpenseCubit extends Cubit<ExpenseState> {
  ExpenseCubit({required this.expenseRepository}) : super(ExpenseState());

  final ExpenseRepository expenseRepository;
  String? _libraryId;

  /// Loads expenses for the current selected month.
  Future<void> loadMonthExpenses(String libraryId) async {
    _libraryId = libraryId;
    await _loadForMonth(libraryId, state.selectedMonth);
  }

  /// Navigate to previous month and reload.
  Future<void> goToPreviousMonth() async {
    final prev = DateTime(
      state.selectedMonth.year,
      state.selectedMonth.month - 1,
    );
    emit(state.copyWith(selectedMonth: prev));
    if (_libraryId != null) await _loadForMonth(_libraryId!, prev);
  }

  /// Navigate to next month and reload.
  Future<void> goToNextMonth() async {
    if (state.isCurrentMonth) return;
    final next = DateTime(
      state.selectedMonth.year,
      state.selectedMonth.month + 1,
    );
    emit(state.copyWith(selectedMonth: next));
    if (_libraryId != null) await _loadForMonth(_libraryId!, next);
  }

  Future<void> _loadForMonth(String libraryId, DateTime month) async {
    emit(state.copyWith(isLoading: true));

    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    final result = await expenseRepository.getExpenses(
      libraryId: libraryId,
      startDate: monthStart,
      endDate: monthEnd,
    );

    result.fold(
      (failure) => emit(state.copyWith(
        isLoading: false,
        errorMessage: failure.message ?? 'Failed to load expenses',
      )),
      (expenses) => emit(state.copyWith(
        isLoading: false,
        expenses: expenses,
      )),
    );
  }

  /// Adds a new expense and refreshes the list.
  Future<void> addExpense({
    required String libraryId,
    required String title,
    required double amount,
    required ExpenseCategory category,
    required DateTime date,
    String? description,
  }) async {
    emit(state.copyWith(isSaving: true));

    final expense = Expense(
      id: const Uuid().v4(),
      libraryId: libraryId,
      title: title,
      amount: amount,
      category: category,
      date: date,
      description: description?.isNotEmpty == true ? description : null,
      createdAt: DateTime.now(),
    );

    final result = await expenseRepository.addExpense(expense);

    result.fold(
      (failure) => emit(state.copyWith(
        isSaving: false,
        errorMessage: failure.message ?? 'Failed to save expense',
      )),
      (_) {
        final isInSelectedMonth =
            date.year == state.selectedMonth.year &&
            date.month == state.selectedMonth.month;

        emit(state.copyWith(
          isSaving: false,
          savedSuccessfully: true,
          expenses: isInSelectedMonth
              ? [expense, ...state.expenses]
              : state.expenses,
        ));
      },
    );
  }

  /// Deletes an expense and removes from local state.
  Future<void> deleteExpense(String expenseId) async {
    final result = await expenseRepository.deleteExpense(expenseId);

    result.fold(
      (failure) => emit(state.copyWith(
        errorMessage: failure.message ?? 'Failed to delete',
      )),
      (_) => emit(state.copyWith(
        expenses: state.expenses.where((e) => e.id != expenseId).toList(),
      )),
    );
  }
}
