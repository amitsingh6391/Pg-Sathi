import 'package:equatable/equatable.dart';

import '../../../domain/entities/membership.dart';
import '../../../domain/entities/payment.dart';
import '../../../domain/entities/slot.dart';

/// Represents a single row of data parsed from Excel for bulk import.
class ImportRowData extends Equatable {
  const ImportRowData({
    required this.rowIndex,
    required this.studentName,
    required this.phone,
    required this.seatNumber,
    required this.slot,
    required this.startDate,
    required this.endDate,
    required this.amount,
    required this.plan,
    required this.paymentMode,
    this.email,
    this.validationErrors = const [],
    this.rawTiming,
    this.slotStartMinutes,
    this.slotEndMinutes,
  });

  /// Original row index in Excel (for error reporting).
  final int rowIndex;

  /// Student name.
  final String studentName;

  /// Phone number (unique identifier).
  final String phone;

  /// Seat number (e.g., "S01", "S15").
  final String seatNumber;

  /// Time slot (morning/evening) - legacy enum for backward compatibility.
  final Slot slot;

  /// Membership start date.
  final DateTime startDate;

  /// Membership end date.
  final DateTime endDate;

  /// Payment amount.
  final double amount;

  /// Membership plan type.
  final MembershipPlan plan;

  /// Payment mode.
  final PaymentMode paymentMode;

  /// Optional email.
  final String? email;

  /// List of validation errors for this row.
  final List<String> validationErrors;

  /// Raw timing string from Excel (e.g., "6am-2pm", "18:00-24:00").
  final String? rawTiming;

  /// Slot start time in minutes since midnight (e.g., 360 = 6:00 AM).
  final int? slotStartMinutes;

  /// Slot end time in minutes since midnight (e.g., 840 = 2:00 PM).
  final int? slotEndMinutes;

  /// Whether this row has validation errors.
  bool get hasErrors => validationErrors.isNotEmpty;

  /// Whether this row is valid for import.
  bool get isValid => !hasErrors;

  ImportRowData copyWith({
    int? rowIndex,
    String? studentName,
    String? phone,
    String? seatNumber,
    Slot? slot,
    DateTime? startDate,
    DateTime? endDate,
    double? amount,
    MembershipPlan? plan,
    PaymentMode? paymentMode,
    String? email,
    List<String>? validationErrors,
    String? rawTiming,
    int? slotStartMinutes,
    int? slotEndMinutes,
  }) {
    return ImportRowData(
      rowIndex: rowIndex ?? this.rowIndex,
      studentName: studentName ?? this.studentName,
      phone: phone ?? this.phone,
      seatNumber: seatNumber ?? this.seatNumber,
      slot: slot ?? this.slot,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      amount: amount ?? this.amount,
      plan: plan ?? this.plan,
      paymentMode: paymentMode ?? this.paymentMode,
      email: email ?? this.email,
      validationErrors: validationErrors ?? this.validationErrors,
      rawTiming: rawTiming ?? this.rawTiming,
      slotStartMinutes: slotStartMinutes ?? this.slotStartMinutes,
      slotEndMinutes: slotEndMinutes ?? this.slotEndMinutes,
    );
  }

  /// Display string for timing.
  String get timingDisplay {
    if (slotStartMinutes != null && slotEndMinutes != null) {
      return '${_formatMinutesToTime(slotStartMinutes!)} - ${_formatMinutesToTime(slotEndMinutes!)}';
    }
    return rawTiming ?? slot.displayName;
  }

  String _formatMinutesToTime(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  @override
  List<Object?> get props => [
        rowIndex,
        studentName,
        phone,
        seatNumber,
        slot,
        startDate,
        endDate,
        amount,
        plan,
        paymentMode,
        email,
        validationErrors,
        rawTiming,
        slotStartMinutes,
        slotEndMinutes,
      ];
}

/// Result of processing a single import row.
class ImportRowResult extends Equatable {
  const ImportRowResult({
    required this.rowIndex,
    required this.phone,
    required this.status,
    this.message,
    this.studentId,
    this.membershipId,
    this.isStudentCreated = false,
  });

  final int rowIndex;
  final String phone;
  final ImportStatus status;
  final String? message;
  final String? studentId;
  final String? membershipId;
  final bool isStudentCreated;

  @override
  List<Object?> get props => [
        rowIndex,
        phone,
        status,
        message,
        studentId,
        membershipId,
        isStudentCreated,
      ];
}

/// Status of an import row.
enum ImportStatus {
  /// Successfully imported.
  success,

  /// Skipped (e.g., seat already occupied).
  skipped,

  /// Failed to import.
  failed,
}

/// Summary of bulk import results.
class ImportSummary extends Equatable {
  const ImportSummary({
    required this.totalRows,
    required this.successCount,
    required this.skippedCount,
    required this.failedCount,
    required this.studentsCreated,
    required this.studentsReused,
    required this.results,
  });

  final int totalRows;
  final int successCount;
  final int skippedCount;
  final int failedCount;
  final int studentsCreated;
  final int studentsReused;
  final List<ImportRowResult> results;

  @override
  List<Object?> get props => [
        totalRows,
        successCount,
        skippedCount,
        failedCount,
        studentsCreated,
        studentsReused,
        results,
      ];
}
