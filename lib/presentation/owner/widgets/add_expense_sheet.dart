import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/expense.dart';
import '../../core/app_ui_constants.dart';
import '../../core/widgets/premium_kit.dart';
import '../cubit/expense_cubit.dart';

/// Bottom sheet for adding a new expense.
/// Fintech-style: oversized amount entry, category chips, accent save CTA.
class AddExpenseSheet extends StatefulWidget {
  const AddExpenseSheet({super.key, required this.libraryId});

  final String libraryId;

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  ExpenseCategory _category = ExpenseCategory.other;
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppUIConstants.primaryLight,
            onPrimary: AppUIConstants.background,
            surface: AppUIConstants.surface,
            onSurface: AppUIConstants.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      HapticFeedback.selectionClick();
      setState(() => _selectedDate = picked);
    }
  }

  void _submit() {
    HapticFeedback.lightImpact();
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) return;

    context.read<ExpenseCubit>().addExpense(
      libraryId: widget.libraryId,
      title: _titleController.text.trim(),
      amount: amount,
      category: _category,
      date: _selectedDate,
      description: _descriptionController.text.trim(),
    );
  }

  IconData _categoryIcon(ExpenseCategory c) {
    switch (c) {
      case ExpenseCategory.rent:
        return Icons.home_work_outlined;
      case ExpenseCategory.electricity:
        return Icons.bolt_rounded;
      case ExpenseCategory.salary:
        return Icons.badge_outlined;
      case ExpenseCategory.maintenance:
        return Icons.build_outlined;
      case ExpenseCategory.supplies:
        return Icons.shopping_basket_outlined;
      case ExpenseCategory.internet:
        return Icons.wifi_rounded;
      case ExpenseCategory.other:
        return Icons.more_horiz_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ExpenseCubit, ExpenseState>(
      listenWhen: (prev, curr) =>
          curr.savedSuccessfully || curr.errorMessage != null,
      listener: (context, state) {
        if (state.savedSuccessfully) {
          Navigator.of(context).pop(true);
        } else if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppUIConstants.error,
            ),
          );
        }
      },
      child: Container(
        decoration: const BoxDecoration(
          color: AppUIConstants.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppUIConstants.radiusXl),
          ),
          border: Border(top: BorderSide(color: AppUIConstants.border)),
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 10,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppUIConstants.disabled,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _buildHeader(),
                const SizedBox(height: 18),
                _buildAmountHero(),
                const SizedBox(height: 20),
                _label('Category'),
                const SizedBox(height: 10),
                _buildCategoryChips(),
                const SizedBox(height: 20),
                _label('What was it for?'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  style: AppUIConstants.bodyLg,
                  decoration: _inputDecoration('e.g. Water tank repair'),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Title is required'
                      : null,
                ),
                const SizedBox(height: 16),
                _buildDateField(),
                const SizedBox(height: 16),
                _label('Notes (optional)'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descriptionController,
                  style: AppUIConstants.bodyLg,
                  decoration: _inputDecoration('Add any additional notes...'),
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 24),
                _buildSaveButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text.toUpperCase(),
    style: AppUIConstants.caption.copyWith(letterSpacing: 0.8),
  );

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppUIConstants.surfaceMuted,
            borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
          ),
          child: const Icon(
            Icons.arrow_outward_rounded,
            color: AppUIConstants.primaryLight,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add Expense', style: AppUIConstants.headingMd),
              const SizedBox(height: 2),
              Text(
                'Track where your PG money goes',
                style: AppUIConstants.caption,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
          color: AppUIConstants.textSecondary,
        ),
      ],
    );
  }

  Widget _buildAmountHero() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppUIConstants.background,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
        border: Border.all(color: AppUIConstants.border),
      ),
      child: Column(
        children: [
          Text('AMOUNT', style: AppUIConstants.caption),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                '\u20B9',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: AppUIConstants.primaryLight,
                ),
              ),
              const SizedBox(width: 6),
              IntrinsicWidth(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 60),
                  child: TextFormField(
                    controller: _amountController,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: AppUIConstants.textPrimary,
                    ),
                    cursorColor: AppUIConstants.primaryLight,
                    decoration: const InputDecoration(
                      hintText: '0',
                      hintStyle: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: AppUIConstants.disabled,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      filled: false,
                      isDense: true,
                      errorStyle: TextStyle(color: AppUIConstants.error),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      final n = double.tryParse(v.trim());
                      if (n == null || n <= 0) return 'Enter valid amount';
                      return null;
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ExpenseCategory.values.map((c) {
        final selected = c == _category;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _category = c);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? AppUIConstants.surfaceMuted
                  : AppUIConstants.surfaceMuted,
              borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
              border: Border.all(
                color: selected
                    ? AppUIConstants.primaryLight
                    : AppUIConstants.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _categoryIcon(c),
                  size: 16,
                  color: selected
                      ? AppUIConstants.primaryLight
                      : AppUIConstants.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  c.displayName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? AppUIConstants.primaryLight
                        : AppUIConstants.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDateField() {
    final now = DateTime.now();
    final isToday =
        _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Date'),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: AppUIConstants.border),
              borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
              color: AppUIConstants.background,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 18,
                  color: AppUIConstants.primaryLight,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    DateFormat('dd MMM yyyy').format(_selectedDate),
                    style: AppUIConstants.bodyLg,
                  ),
                ),
                if (isToday)
                  const PremiumStatusPill(
                    'Today',
                    color: AppUIConstants.primaryLight,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return BlocBuilder<ExpenseCubit, ExpenseState>(
      buildWhen: (prev, curr) => prev.isSaving != curr.isSaving,
      builder: (context, state) {
        return SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: state.isSaving ? null : _submit,
            style: AppUIConstants.primaryButtonStyle.copyWith(
              minimumSize: const WidgetStatePropertyAll(Size.fromHeight(52)),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: state.isSaving
                  ? const SizedBox(
                      key: ValueKey('saving'),
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Save Expense',
                      key: ValueKey('save'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  InputDecoration _inputDecoration(String? hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppUIConstants.bodyMd.copyWith(
        color: AppUIConstants.textTertiary,
      ),
      filled: true,
      fillColor: AppUIConstants.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        borderSide: const BorderSide(color: AppUIConstants.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        borderSide: const BorderSide(color: AppUIConstants.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        borderSide: const BorderSide(
          color: AppUIConstants.primaryLight,
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}
