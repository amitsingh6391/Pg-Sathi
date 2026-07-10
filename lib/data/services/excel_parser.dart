import 'dart:developer';
import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../../domain/entities/membership.dart';
import '../../domain/entities/payment.dart';
import '../../domain/entities/slot.dart';
import '../../presentation/owner/models/import_row_data.dart';

class ExcelParseResult {
  const ExcelParseResult({required this.rows, this.error});

  final List<ImportRowData> rows;
  final String? error;

  bool get hasError => error != null;
  bool get isSuccess => !hasError && rows.isNotEmpty;
}

class ExcelParser {
  static const _columnMappings = {
    'name': ['name', 'student_name', 'student name', 'studentname', 'student'],
    'phone': [
      'phone',
      'mob_no',
      'mob no',
      'mobile',
      'phone_number',
      'phone number',
      'phonenumber',
      'mobile_no',
      'mobile no',
      'contact',
    ],
    'seat': [
      'seat_no',
      'seat no',
      'seatno',
      'seat',
      'seat_number',
      'seat number',
      'seatnumber',
    ],
    'slot': [
      'timing',
      'slot',
      'time_slot',
      'time slot',
      'timeslot',
      'shift',
      'session',
    ],
    'start_date': [
      'joining_date',
      'joining date',
      'joiningdate',
      'start_date',
      'start date',
      'startdate',
      'join_date',
      'join date',
      'from',
      'from_date',
      'from date',
    ],
    'end_date': [
      'due_date',
      'due date',
      'duedate',
      'end_date',
      'end date',
      'enddate',
      'expiry_date',
      'expiry date',
      'expirydate',
      'to',
      'to_date',
      'to date',
    ],
    'amount': ['amount', 'fee', 'fees', 'price', 'payment'],
    'plan': [
      'plan',
      'membership_plan',
      'membership plan',
      'membershipplan',
      'duration',
    ],
    'payment_mode': [
      'mode',
      'payment_mode',
      'payment mode',
      'paymentmode',
      'payment_method',
      'payment method',
    ],
    'email': ['email', 'email_id', 'email id', 'emailid'],
  };

  ExcelParseResult parse(Uint8List bytes) {
    try {
      final excel = Excel.decodeBytes(bytes);

      if (excel.tables.isEmpty) {
        return const ExcelParseResult(rows: [], error: 'Excel file is empty');
      }

      final sheetData = _findValidSheet(excel);
      if (sheetData == null) {
        return const ExcelParseResult(
          rows: [],
          error: 'Could not find column headers. Required: Name, Phone',
        );
      }

      final (sheet, headerRowIndex, columnIndices) = sheetData;
      final rows = <ImportRowData>[];

      for (int i = headerRowIndex + 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        final parsedRow = _parseRow(row, i + 1, columnIndices);
        if (parsedRow != null) {
          rows.add(parsedRow);
        }
      }

      if (rows.isEmpty) {
        return const ExcelParseResult(
          rows: [],
          error: 'No valid data rows found',
        );
      }

      return ExcelParseResult(rows: rows);
    } catch (e, stack) {
      log('ExcelParser: Parse error - $e', stackTrace: stack);
      return ExcelParseResult(rows: [], error: 'Failed to parse Excel: $e');
    }
  }

  (Sheet, int, Map<String, int>)? _findValidSheet(Excel excel) {
    for (final entry in excel.tables.entries) {
      final sheet = entry.value;
      if (sheet.rows.isEmpty) continue;

      for (int i = 0; i < sheet.rows.length && i < 8; i++) {
        final indices = _detectColumns(sheet.rows[i]);
        if (indices.containsKey('name') && indices.containsKey('phone')) {
          final hasData = _hasDataRows(sheet, i);
          if (hasData) {
            return (sheet, i, indices);
          }
        }
      }
    }
    return null;
  }

  bool _hasDataRows(Sheet sheet, int headerIndex) {
    for (
      int r = headerIndex + 1;
      r < sheet.rows.length && r < headerIndex + 12;
      r++
    ) {
      final row = sheet.rows[r];
      if (row.any(
        (c) =>
            c != null &&
            c.value != null &&
            c.value.toString().trim().isNotEmpty,
      )) {
        return true;
      }
    }
    return false;
  }

  Map<String, int> _detectColumns(List<Data?> row) {
    final indices = <String, int>{};

    for (int i = 0; i < row.length; i++) {
      final cell = row[i];
      if (cell == null || cell.value == null) continue;

      var headerText = cell.value.toString().toLowerCase().trim();
      headerText = headerText.replaceAll(RegExp(r'[_\s]+'), ' ').trim();

      for (final entry in _columnMappings.entries) {
        if (indices.containsKey(entry.key)) continue;

        final matches = entry.value.any((alias) {
          final normalizedAlias = alias
              .toLowerCase()
              .replaceAll(RegExp(r'[_\s]+'), ' ')
              .trim();
          if (headerText == normalizedAlias) return true;
          if (headerText.contains(normalizedAlias) &&
              normalizedAlias.length >= 3) {
            return true;
          }
          if (normalizedAlias.contains(headerText) && headerText.length >= 3) {
            return true;
          }
          return false;
        });

        if (matches) {
          indices[entry.key] = i;
          break;
        }
      }
    }

    return indices;
  }

  ImportRowData? _parseRow(
    List<Data?> row,
    int rowIndex,
    Map<String, int> columnIndices,
  ) {
    try {
      if (row.every((cell) => cell == null || cell.value == null)) {
        return null;
      }

      String? getValue(String key) {
        final index = columnIndices[key];
        if (index == null || index >= row.length) return null;
        final cell = row[index];
        if (cell == null || cell.value == null) return null;

        final cellValue = cell.value!;
        String value;

        if (cellValue is DoubleCellValue) {
          value = cellValue.value.toStringAsFixed(0);
        } else if (cellValue is IntCellValue) {
          value = cellValue.value.toString();
        } else {
          value = cellValue.toString().trim();
        }

        if (value.toLowerCase().contains('e')) {
          try {
            final numValue = double.parse(value);
            value = numValue.toInt().toString();
          } catch (_) {}
        }

        return value;
      }

      DateTime? getDateValue(String key) {
        final index = columnIndices[key];
        if (index == null || index >= row.length) return null;
        final cell = row[index];
        if (cell == null || cell.value == null) return null;

        final cellValue = cell.value!;

        if (cellValue is DateCellValue) {
          return DateTime(cellValue.year, cellValue.month, cellValue.day);
        }

        if (cellValue is DoubleCellValue) {
          final serial = cellValue.value;
          if (serial > 0 && serial < 100000) {
            try {
              final date = DateTime(
                1899,
                12,
                30,
              ).add(Duration(days: serial.toInt()));
              if (date.year >= 1900 && date.year <= 2100) return date;
            } catch (_) {}
          }
        } else if (cellValue is IntCellValue) {
          final serial = cellValue.value.toDouble();
          if (serial > 0 && serial < 100000) {
            try {
              final date = DateTime(
                1899,
                12,
                30,
              ).add(Duration(days: serial.toInt()));
              if (date.year >= 1900 && date.year <= 2100) return date;
            } catch (_) {}
          }
        }

        final stringValue = getValue(key);
        if (stringValue == null || stringValue.isEmpty) return null;

        return _parseDate(stringValue);
      }

      final name = getValue('name') ?? '';
      final phone = _normalizePhone(getValue('phone') ?? '');
      final seatNumber = _normalizeSeatNumber(getValue('seat') ?? '');
      final rawTiming = getValue('slot') ?? '';
      final timingInfo = _parseTimingToMinutes(rawTiming);
      final slot = _parseSlot(rawTiming);

      final startDate = getDateValue('start_date');
      final endDate = getDateValue('end_date');

      final amount = _parseDouble(getValue('amount'));
      final planValue = getValue('plan');
      final plan = _parsePlan(planValue);
      final paymentMode = _parsePaymentMode(getValue('payment_mode'));
      final email = getValue('email');

      if (name.isEmpty && phone.isEmpty) return null;

      final effectiveStartDate = startDate ?? DateTime.now();
      final effectiveEndDate =
          endDate ?? _calculateEndDate(effectiveStartDate, plan);

      return ImportRowData(
        rowIndex: rowIndex,
        studentName: name,
        phone: phone,
        seatNumber: seatNumber,
        slot: slot,
        startDate: effectiveStartDate,
        endDate: effectiveEndDate,
        amount: amount,
        plan: plan,
        paymentMode: paymentMode,
        email: email,
        rawTiming: rawTiming.isNotEmpty ? rawTiming : null,
        slotStartMinutes: timingInfo?.$1,
        slotEndMinutes: timingInfo?.$2,
      );
    } catch (e) {
      log('ExcelParser: Row $rowIndex parse error - $e');
      return null;
    }
  }

  (int, int)? _parseTimingToMinutes(String timing) {
    if (timing.isEmpty) return null;

    final lower = timing.toLowerCase().replaceAll(' ', '');

    final amPmPattern = RegExp(
      r'(\d{1,2}):?(\d{0,2})?\s*(am|pm)\s*[-–to]+\s*(\d{1,2}):?(\d{0,2})?\s*(am|pm)',
      caseSensitive: false,
    );
    final amPmMatch = amPmPattern.firstMatch(lower);
    if (amPmMatch != null) {
      var startHour = int.parse(amPmMatch.group(1)!);
      final startMin = int.tryParse(amPmMatch.group(2) ?? '0') ?? 0;
      final startPeriod = amPmMatch.group(3)!;
      var endHour = int.parse(amPmMatch.group(4)!);
      final endMin = int.tryParse(amPmMatch.group(5) ?? '0') ?? 0;
      final endPeriod = amPmMatch.group(6)!;

      if (startPeriod == 'pm' && startHour != 12) startHour += 12;
      if (startPeriod == 'am' && startHour == 12) startHour = 0;
      if (endPeriod == 'pm' && endHour != 12) endHour += 12;
      if (endPeriod == 'am' && endHour == 12) endHour = 0;

      return (startHour * 60 + startMin, endHour * 60 + endMin);
    }

    final hourPattern = RegExp(
      r'(\d{1,2}):(\d{2})\s*[-–to]+\s*(\d{1,2}):(\d{2})',
    );
    final hourMatch = hourPattern.firstMatch(lower);
    if (hourMatch != null) {
      final startHour = int.parse(hourMatch.group(1)!);
      final startMin = int.parse(hourMatch.group(2)!);
      var endHour = int.parse(hourMatch.group(3)!);
      final endMin = int.parse(hourMatch.group(4)!);

      if (endHour == 24) endHour = 0;

      return (
        startHour * 60 + startMin,
        (endHour == 0 ? 24 : endHour) * 60 + endMin,
      );
    }

    final simplePattern = RegExp(r'(\d{1,2})\s*[-–to]+\s*(\d{1,2})');
    final simpleMatch = simplePattern.firstMatch(lower);
    if (simpleMatch != null) {
      var startHour = int.parse(simpleMatch.group(1)!);
      var endHour = int.parse(simpleMatch.group(2)!);

      if (endHour == 24) endHour = 0;

      return (startHour * 60, (endHour == 0 ? 24 : endHour) * 60);
    }

    return null;
  }

  String _normalizePhone(String phone) {
    if (phone.contains('E') || phone.contains('e')) {
      try {
        final numValue = double.parse(phone);
        phone = numValue.toInt().toString();
      } catch (_) {}
    }

    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');

    if (digits.length == 10) return '+91$digits';
    if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
    if (digits.length >= 11) return '+$digits';

    return digits;
  }

  String _normalizeSeatNumber(String seat) {
    final match = RegExp(r'(\d+)').firstMatch(seat);
    if (match == null) return seat;

    final num = int.tryParse(match.group(1)!) ?? 0;
    return 'B$num';
  }

  Slot _parseSlot(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('morning') ||
        lower.contains('am') ||
        lower.contains('6am')) {
      return Slot.morning;
    }
    if (lower.contains('evening') ||
        lower.contains('pm') ||
        lower.contains('2pm')) {
      return Slot.evening;
    }
    return Slot.morning;
  }

  DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;

    try {
      if (value.contains('T') &&
          (value.contains('Z') || value.contains('+') || value.contains('-'))) {
        try {
          return DateTime.parse(value);
        } catch (_) {}
      }

      final isoDatePattern = RegExp(r'^(\d{4})[/-](\d{1,2})[/-](\d{1,2})');
      final isoMatch = isoDatePattern.firstMatch(value);
      if (isoMatch != null) {
        final year = int.parse(isoMatch.group(1)!);
        final month = int.parse(isoMatch.group(2)!);
        final day = int.parse(isoMatch.group(3)!);
        try {
          return DateTime(year, month, day);
        } catch (_) {}
      }

      final serial = double.tryParse(value);
      if (serial != null && serial > 0 && serial < 100000) {
        try {
          final date = DateTime(
            1899,
            12,
            30,
          ).add(Duration(days: serial.toInt()));
          if (date.year >= 1900 && date.year <= 2100) return date;
        } catch (_) {}
      }

      final textDatePattern = RegExp(
        r'(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\s+(\d{1,2})(?:st|nd|rd|th)?(?:\s+(\d{4}))?',
        caseSensitive: false,
      );
      final textMatch = textDatePattern.firstMatch(value);
      if (textMatch != null) {
        final monthName = textMatch.group(1)!.toLowerCase();
        final day = int.parse(textMatch.group(2)!);
        final yearStr = textMatch.group(3);

        final monthMap = {
          'jan': 1,
          'feb': 2,
          'mar': 3,
          'apr': 4,
          'may': 5,
          'jun': 6,
          'jul': 7,
          'aug': 8,
          'sep': 9,
          'oct': 10,
          'nov': 11,
          'dec': 12,
        };

        final month = monthMap[monthName.substring(0, 3)];
        if (month != null) {
          var year = yearStr != null
              ? int.parse(yearStr)
              : _inferYear(month, day);

          try {
            return DateTime(year, month, day);
          } catch (_) {}
        }
      }

      final ddmmyyyyPattern = RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})');
      final ddmmMatch = ddmmyyyyPattern.firstMatch(value);
      if (ddmmMatch != null) {
        final first = int.parse(ddmmMatch.group(1)!);
        final second = int.parse(ddmmMatch.group(2)!);
        var year = int.parse(ddmmMatch.group(3)!);
        if (year < 100) year += 2000;

        if (first <= 31 && second <= 12) {
          try {
            return DateTime(year, second, first);
          } catch (_) {}
        }

        if (first <= 12 && second <= 31) {
          try {
            return DateTime(year, first, second);
          } catch (_) {}
        }
      }

      try {
        return DateTime.parse(value);
      } catch (_) {
        final cleaned = value.replaceAll(RegExp(r'[^\d]'), '');
        if (cleaned.length == 8) {
          final year = int.parse(cleaned.substring(0, 4));
          final month = int.parse(cleaned.substring(4, 6));
          final day = int.parse(cleaned.substring(6, 8));
          try {
            return DateTime(year, month, day);
          } catch (_) {}
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  int _inferYear(int month, int day) {
    final now = DateTime.now();
    final currentYearDate = DateTime(now.year, month, day);

    if (currentYearDate.isBefore(now)) return now.year + 1;

    return now.year;
  }

  DateTime _calculateEndDate(DateTime startDate, MembershipPlan plan) {
    switch (plan) {
      case MembershipPlan.daily:
        return startDate.add(const Duration(days: 1));
      case MembershipPlan.weekly:
        return startDate.add(const Duration(days: 7));
      case MembershipPlan.monthly:
        return startDate.add(const Duration(days: 30));
      case MembershipPlan.quarterly:
        return startDate.add(const Duration(days: 90));
      case MembershipPlan.yearly:
        return startDate.add(const Duration(days: 365));
    }
  }

  double _parseDouble(String? value) {
    if (value == null || value.isEmpty) return 0;
    return double.tryParse(value.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
  }

  MembershipPlan _parsePlan(String? value) {
    if (value == null || value.isEmpty) return MembershipPlan.monthly;

    final lower = value.toLowerCase().trim();

    final days = int.tryParse(lower);
    if (days != null) {
      if (days <= 7) return MembershipPlan.daily;
      if (days <= 30) return MembershipPlan.weekly;
      if (days <= 90) return MembershipPlan.monthly;
      if (days <= 180) return MembershipPlan.quarterly;
      return MembershipPlan.yearly;
    }

    if (lower.contains('daily') || lower.contains('day'))
      return MembershipPlan.daily;
    if (lower.contains('week')) return MembershipPlan.weekly;
    if (lower.contains('quarter') || lower.contains('3 month')) {
      return MembershipPlan.quarterly;
    }
    if (lower.contains('year') || lower.contains('annual'))
      return MembershipPlan.yearly;
    return MembershipPlan.monthly;
  }

  PaymentMode _parsePaymentMode(String? value) {
    if (value == null) return PaymentMode.cash;
    final lower = value.toLowerCase();
    if (lower.contains('upi') ||
        lower.contains('online') ||
        lower.contains('gpay')) {
      return PaymentMode.upi;
    }
    return PaymentMode.cash;
  }
}
