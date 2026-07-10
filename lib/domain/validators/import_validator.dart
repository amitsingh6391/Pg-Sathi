import '../entities/membership.dart';
import '../entities/payment.dart';
import '../entities/slot.dart';
import '../../presentation/owner/models/import_row_data.dart';

/// Validates import rows for business rules before bulk import.
/// 
/// Business rules validated:
/// - Required fields (name, phone, seat)
/// - Phone number format
/// - Date validity (end > start)
/// - Amount validity
/// - Seat+slot overlap detection within import batch
class ImportValidator {
  List<ImportRowData> validate(List<ImportRowData> rows) {
    final validatedRows = <ImportRowData>[];
    final seatSlotCombinations = <String, List<int>>{};

    for (final row in rows) {
      final key = _getSeatSlotKey(row);
      seatSlotCombinations.putIfAbsent(key, () => []).add(row.rowIndex);
    }

    for (final row in rows) {
      final errors = <String>[];

      if (row.studentName.isEmpty) {
        errors.add('Student name is required');
      }

      if (row.phone.isEmpty) {
        errors.add('Phone number is required');
      } else if (!_isValidPhone(row.phone)) {
        errors.add('Invalid phone number format');
      }

      if (row.seatNumber.isEmpty) {
        errors.add('Seat number is required');
      }

      if (row.endDate.isBefore(row.startDate)) {
        errors.add('End date must be after start date');
      }

      if (row.amount <= 0) {
        errors.add('Amount must be greater than 0');
      }

      final key = _getSeatSlotKey(row);
      final seatSlotRowIndices = seatSlotCombinations[key] ?? [];

      if (seatSlotRowIndices.length > 1) {
        final overlappingRows = <int>[];

        for (final otherRowIndex in seatSlotRowIndices) {
          if (otherRowIndex == row.rowIndex) continue;

          final otherRow = rows.firstWhere(
            (r) => r.rowIndex == otherRowIndex,
            orElse: () => ImportRowData(
              rowIndex: -1,
              studentName: '',
              phone: '',
              seatNumber: '',
              slot: Slot.morning,
              startDate: DateTime.now(),
              endDate: DateTime.now(),
              amount: 0,
              plan: MembershipPlan.monthly,
              paymentMode: PaymentMode.cash,
            ),
          );
          if (otherRow.rowIndex == -1) continue;

          if (row.startDate.isBefore(otherRow.endDate) &&
              row.endDate.isAfter(otherRow.startDate)) {
            overlappingRows.add(otherRowIndex);
          }
        }

        if (overlappingRows.isNotEmpty) {
          errors.add(
            'Date overlaps with another membership on same seat+slot in rows: ${[row.rowIndex, ...overlappingRows].join(', ')}',
          );
        }
      }

      validatedRows.add(row.copyWith(validationErrors: errors));
    }

    return validatedRows;
  }

  String _getSeatSlotKey(ImportRowData row) {
    if (row.slotStartMinutes != null && row.slotEndMinutes != null) {
      return '${row.seatNumber}_${row.slotStartMinutes}_${row.slotEndMinutes}';
    }

    if (row.rawTiming != null && row.rawTiming!.isNotEmpty) {
      return '${row.seatNumber}_${row.rawTiming}';
    }

    return '${row.seatNumber}_${row.slot.name}';
  }

  bool _isValidPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    return digits.length >= 10 && digits.length <= 13;
  }
}
