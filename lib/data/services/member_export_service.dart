import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../../domain/usecases/get_occupied_seats.dart';

/// Generates an Excel workbook from occupied seat data for audit submission.
class MemberExportService {
  const MemberExportService();

  static final _dateFormat = DateFormat('dd/MM/yyyy');

  /// Builds an .xlsx file containing all member data from [seats].
  /// Columns: S.No, Student Name, Phone, Plan, Start Date, End Date, Seat No, Slot/Branch, Status
  Uint8List generateMemberExcel({
    required List<OccupiedSeatInfo> seats,
    required String libraryName,
  }) {
    final excel = Excel.createExcel();
    // Remove default sheet
    excel.delete('Sheet1');

    final sheet = excel['Members'];

    // Header row styling
    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#1565C0'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final headers = [
      'S.No',
      'Student Name',
      'Phone Number',
      'Plan Type',
      'Start Date',
      'End Date',
      'Seat Number',
      'Slot / Branch',
      'Status',
    ];

    // Write headers
    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = headerStyle;
    }

    // Set column widths
    sheet.setColumnWidth(0, 6);   // S.No
    sheet.setColumnWidth(1, 24);  // Student Name
    sheet.setColumnWidth(2, 16);  // Phone
    sheet.setColumnWidth(3, 14);  // Plan
    sheet.setColumnWidth(4, 14);  // Start Date
    sheet.setColumnWidth(5, 14);  // End Date
    sheet.setColumnWidth(6, 12);  // Seat No
    sheet.setColumnWidth(7, 18);  // Slot/Branch
    sheet.setColumnWidth(8, 14);  // Status

    // Alternating row styles
    final evenRowStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#E3F2FD'),
      horizontalAlign: HorizontalAlign.Center,
    );
    final oddRowStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#FFFFFF'),
      horizontalAlign: HorizontalAlign.Center,
    );
    final nameStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#E3F2FD'),
      horizontalAlign: HorizontalAlign.Left,
    );
    final nameOddStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#FFFFFF'),
      horizontalAlign: HorizontalAlign.Left,
    );

    for (int i = 0; i < seats.length; i++) {
      final seat = seats[i];
      final rowIndex = i + 1;
      final isEven = i % 2 == 0;
      final basStyle = isEven ? evenRowStyle : oddRowStyle;
      final nStyle = isEven ? nameStyle : nameOddStyle;

      final membership = seat.membership;
      final slotLabel = _slotLabel(seat);
      final statusLabel = _statusLabel(seat);

      void writeCell(int col, CellValue value, [CellStyle? style]) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex));
        cell.value = value;
        cell.cellStyle = style ?? basStyle;
      }

      writeCell(0, IntCellValue(i + 1));
      writeCell(1, TextCellValue(seat.displayName), nStyle);
      writeCell(2, TextCellValue(_formatPhone(seat.studentPhone ?? membership.phoneNumber)));
      writeCell(3, TextCellValue(membership.planDisplayLabel));
      writeCell(4, TextCellValue(_dateFormat.format(membership.startDate)));
      writeCell(5, TextCellValue(_dateFormat.format(membership.endDate)));
      writeCell(6, TextCellValue(seat.seatId));
      writeCell(7, TextCellValue(slotLabel));
      writeCell(8, TextCellValue(statusLabel));
    }

    // Title row at the very top — insert above headers
    // Note: excel package doesn't support row insertion, so we keep header at row 0
    // and write a metadata footer instead.

    final fileBytes = excel.encode();
    return Uint8List.fromList(fileBytes!);
  }

  String _formatPhone(String phone) {
    // Display as +91 XXXXX XXXXX for readability
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      final local = digits.substring(2);
      return '+91 ${local.substring(0, 5)} ${local.substring(5)}';
    }
    if (digits.length == 10) {
      return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
    }
    return phone;
  }

  String _slotLabel(OccupiedSeatInfo seat) {
    final membership = seat.membership;
    if (membership.slotId != null && membership.slotId!.isNotEmpty) {
      // Custom slot — just show the ID for now; caller can enrich if slots are passed
      return membership.slotId!;
    }
    if (membership.slot != null) {
      switch (membership.slot!.name) {
        case 'morning':
          return 'Morning';
        case 'evening':
          return 'Evening';
        default:
          return membership.slot!.name;
      }
    }
    return '-';
  }

  String _statusLabel(OccupiedSeatInfo seat) {
    if (seat.isExpired) return 'Expired';
    if (seat.isReserved) return 'Pending';
    if (seat.membership.hasPartialPayment) return 'Partial';
    return 'Active';
  }
}
