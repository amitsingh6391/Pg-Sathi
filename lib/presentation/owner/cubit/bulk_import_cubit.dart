import 'dart:developer';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/analytics_service.dart';
import '../../../domain/entities/custom_slot.dart';
import '../../../domain/entities/membership.dart';
import '../../../domain/entities/payment.dart';
import '../../../domain/entities/slot.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/repositories/invoice_repository.dart';
import '../../../domain/repositories/library_repository.dart';
import '../../../domain/repositories/membership_repository.dart';
import '../../../domain/repositories/payment_repository.dart';
import '../../../domain/repositories/seat_repository.dart';
import '../../../domain/repositories/slot_repository.dart';
import '../../../domain/repositories/user_repository.dart';
import '../../../domain/usecases/generate_invoice.dart';
import '../../../domain/validators/import_validator.dart';
import '../../../data/services/excel_parser.dart';
import '../models/import_row_data.dart';
import 'bulk_import_state.dart';

/// Cubit for handling bulk import of students and memberships.
///
/// Flow:
/// 1. User picks Excel file
/// 2. Parse and validate rows
/// 3. Show preview with valid/invalid rows
/// 4. User confirms import
/// 5. Process each row: create student, membership, payment, invoice
/// 6. Show summary
class BulkImportCubit extends Cubit<BulkImportState> {
  BulkImportCubit({
    required this.userRepository,
    required this.membershipRepository,
    required this.seatRepository,
    required this.slotRepository,
    required this.paymentRepository,
    required this.invoiceRepository,
    required this.libraryRepository,
    required this.generateInvoice,
    required this.analyticsService,
  }) : super(const BulkImportState());

  final UserRepository userRepository;
  final MembershipRepository membershipRepository;
  final SeatRepository seatRepository;
  final SlotRepository slotRepository;
  final PaymentRepository paymentRepository;
  final InvoiceRepository invoiceRepository;
  final LibraryRepository libraryRepository;
  final GenerateInvoice generateInvoice;
  final AnalyticsService analyticsService;

  final _excelParser = ExcelParser();
  final _validator = ImportValidator();

  String? _libraryId;
  String? _ownerId;
  List<CustomSlot> _availableSlots = [];
  final _uuid = const Uuid();

  void initialize({required String libraryId, required String ownerId}) {
    _libraryId = libraryId;
    _ownerId = ownerId;
    _loadSlots();
  }

  Future<void> _loadSlots() async {
    if (_libraryId == null) return;

    final result = await slotRepository.getSlotsByLibraryId(_libraryId!);
    result.fold(
      (failure) =>
          log('BulkImportCubit: Failed to load slots - ${failure.message}'),
      (slots) => _availableSlots = slots,
    );
  }

  Future<void> parseExcelFile(Uint8List bytes, String fileName) async {
    if (isClosed) return;
    emit(
      state.copyWith(
        status: BulkImportStatus.parsing,
        fileName: fileName,
        clearError: true,
      ),
    );

    await Future.delayed(const Duration(milliseconds: 20));

    final result = _excelParser.parse(bytes);

    if (result.hasError) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: BulkImportStatus.error,
          errorMessage: result.error,
        ),
      );
      return;
    }

    final validatedRows = _validator.validate(result.rows);
    final validRows = validatedRows.where((r) => r.isValid).toList();
    final invalidRows = validatedRows.where((r) => r.hasErrors).toList();

    if (isClosed) return;
    emit(
      state.copyWith(
        status: BulkImportStatus.preview,
        parsedRows: validatedRows,
        validRows: validRows,
        invalidRows: invalidRows,
      ),
    );
  }

  String _normalizeSeatNumber(String seat) {
    final match = RegExp(r'(\d+)').firstMatch(seat);
    if (match == null) return seat;
    final num = int.tryParse(match.group(1)!) ?? 0;
    return 'B$num';
  }

  Future<void> startImport() async {
    if (_libraryId == null || _ownerId == null) {
      emit(
        state.copyWith(
          status: BulkImportStatus.error,
          errorMessage: 'Library not initialized',
        ),
      );
      return;
    }

    if (state.validRows.isEmpty) {
      emit(
        state.copyWith(
          status: BulkImportStatus.error,
          errorMessage: 'No valid rows to import',
        ),
      );
      return;
    }

    if (isClosed) return;
    emit(
      state.copyWith(
        status: BulkImportStatus.importing,
        importProgress: 0,
        currentRowIndex: 0,
      ),
    );

    final results = <ImportRowResult>[];
    int successCount = 0;
    int skippedCount = 0;
    int failedCount = 0;
    int studentsCreated = 0;
    int studentsReused = 0;

    final totalRows = state.validRows.length;

    for (int i = 0; i < totalRows; i++) {
      final row = state.validRows[i];

      if (isClosed) return;
      emit(
        state.copyWith(currentRowIndex: i, importProgress: (i + 1) / totalRows),
      );

      final result = await _processRow(row);
      results.add(result);

      switch (result.status) {
        case ImportStatus.success:
          successCount++;
          if (result.isStudentCreated) {
            studentsCreated++;
          } else {
            studentsReused++;
          }
          break;
        case ImportStatus.skipped:
          skippedCount++;
          break;
        case ImportStatus.failed:
          failedCount++;
          break;
      }
    }

    final summary = ImportSummary(
      totalRows: totalRows,
      successCount: successCount,
      skippedCount: skippedCount,
      failedCount: failedCount,
      studentsCreated: studentsCreated,
      studentsReused: studentsReused,
      results: results,
    );

    if (isClosed) return;

    // Track successful bulk import
    if (successCount > 0) {
      analyticsService.trackBulkImportUsed(
        importType: 'students_memberships',
        recordCount: totalRows,
        success: true,
        additionalParams: {
          'success_count': successCount,
          'failed_count': failedCount,
          'skipped_count': skippedCount,
          'students_created': studentsCreated,
          'students_reused': studentsReused,
        },
      );
    }

    emit(
      state.copyWith(
        status: BulkImportStatus.complete,
        importSummary: summary,
        importProgress: 1.0,
      ),
    );
  }

  /// Processes a single import row.
  Future<ImportRowResult> _processRow(ImportRowData row) async {
    try {
      // 1. Find or create student by phone
      final studentResult = await _findOrCreateStudent(row);
      if (studentResult == null) {
        return ImportRowResult(
          rowIndex: row.rowIndex,
          phone: row.phone,
          status: ImportStatus.failed,
          message: 'Failed to create/find student',
        );
      }

      final (userId, studentCreated) = studentResult;

      // 2. Validate seat exists and get the normalized seat number
      // Note: assignedSeatId stores seat NUMBER (e.g., "S01"), NOT Firestore doc ID
      final seatNumber = await _validateAndGetSeatNumber(row.seatNumber);
      if (seatNumber == null) {
        return ImportRowResult(
          rowIndex: row.rowIndex,
          phone: row.phone,
          status: ImportStatus.failed,
          message: 'Seat ${row.seatNumber} not found in library',
          studentId: userId,
        );
      }

      // 3. Find or create slot based on timing
      final slotId = await _findOrCreateMatchingSlot(row);
      if (slotId == null) {
        return ImportRowResult(
          rowIndex: row.rowIndex,
          phone: row.phone,
          status: ImportStatus.failed,
          message:
              'Failed to find or create slot for timing: ${row.rawTiming ?? row.slot.displayName}',
        );
      }

      // 4. Check if bed is already occupied/reserved (using bed number)
      final isOccupied = await _isSeatOccupiedByNumber(seatNumber);
      if (isOccupied) {
        return ImportRowResult(
          rowIndex: row.rowIndex,
          phone: row.phone,
          status: ImportStatus.skipped,
          message: 'Bed $seatNumber already occupied',
          studentId: userId,
        );
      }

      // 5. Create membership
      // IMPORTANT: assignedSeatId stores the seat NUMBER (e.g., "S01"), NOT Firestore doc ID
      final membershipId = _uuid.v4();
      final membership = Membership(
        id: membershipId,
        userId: userId,
        studentName: row.studentName,
        libraryId: _libraryId!,
        plan: row.plan,
        startDate: row.startDate,
        endDate: row.endDate,
        status: MembershipStatus.active,
        phoneNumber: row.phone,
        assignedSeatId: seatNumber, // Use seat NUMBER, not Firestore doc ID!
        slotId: slotId,
        createdAt: DateTime.now(),
        paymentMethod: row.paymentMode,
        paymentStatus: MembershipPaymentStatus.markedPaid,
        assignedByOwner: true,
      );

      final membershipResult = await membershipRepository.createMembership(
        membership,
      );
      if (membershipResult.isLeft()) {
        return ImportRowResult(
          rowIndex: row.rowIndex,
          phone: row.phone,
          status: ImportStatus.failed,
          message:
              'Failed to create membership: ${membershipResult.fold((l) => l.message, (r) => '')}',
          studentId: userId,
        );
      }

      // 6. Create payment record
      final paymentId = DateTime.now().millisecondsSinceEpoch.toString();
      final payment = row.paymentMode == PaymentMode.upi
          ? Payment.createUpiPayment(
              id: paymentId,
              membershipId: membershipId,
              userId: userId ?? '',
              libraryId: _libraryId!,
              amount: row.amount,
            ).approveUpiPayment(_ownerId!)
          : Payment.createCashPayment(
              id: paymentId,
              membershipId: membershipId,
              userId: userId ?? '',
              libraryId: _libraryId!,
              amount: row.amount,
            ).approveCashPayment(_ownerId!);

      final paymentResult = await paymentRepository.createPayment(payment);
      if (paymentResult.isLeft()) {
        log('BulkImportCubit: Payment creation failed for row ${row.rowIndex}');
      }

      // 7. Generate invoice
      if (row.amount > 0) {
        final invoiceResult = await generateInvoice(
          GenerateInvoiceParams(
            membershipId: membershipId,
            paymentId: paymentId,
            paymentDate: DateTime.now(),
            amountPaid: row.amount,
            currency: 'INR',
          ),
        );
        if (invoiceResult.isLeft()) {
          log(
            'BulkImportCubit: Invoice generation failed for row ${row.rowIndex}',
          );
        }
      }

      return ImportRowResult(
        rowIndex: row.rowIndex,
        phone: row.phone,
        status: ImportStatus.success,
        message: 'Imported successfully',
        studentId: userId,
        membershipId: membershipId,
        isStudentCreated: studentCreated,
      );
    } catch (e, stack) {
      log(
        'BulkImportCubit: Row ${row.rowIndex} processing error - $e',
        stackTrace: stack,
      );
      return ImportRowResult(
        rowIndex: row.rowIndex,
        phone: row.phone,
        status: ImportStatus.failed,
        message: 'Error: ${e.toString()}',
      );
    }
  }

  /// Finds existing student by phone or creates a new one.
  /// Returns (userId, wasCreated) or null on error.
  /// Tries multiple phone formats to match existing users.
  Future<(String?, bool)?> _findOrCreateStudent(ImportRowData row) async {
    // Try multiple phone formats to find existing user
    // This handles cases where phone numbers might be stored in different formats
    final phoneFormats = _getPhoneFormats(row.phone);

    for (final phoneFormat in phoneFormats) {
      final existingResult = await userRepository.getUserByPhone(phoneFormat);

      final user = existingResult.fold((failure) => null, (user) => user);

      if (user != null) {
        // Existing user found - reuse it
        log(
          'BulkImportCubit: Found existing user ${user.id} with phone format: $phoneFormat',
        );
        return (user.id, false);
      }
    }

    // No user found with any format - create new
    log('BulkImportCubit: No existing user found, creating new student');
    return _createStudent(row);
  }

  /// Returns list of phone number formats to try when searching for existing users.
  /// Handles different storage formats (with/without +91, with/without +, etc.)
  List<String> _getPhoneFormats(String phone) {
    final formats = <String>[];

    // Remove all non-digits first
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');

    // Format 1: As provided (with +91 if it was there)
    formats.add(phone);

    // Format 2: With +91 prefix (if 10 digits)
    if (digits.length == 10) {
      formats.add('+91$digits');
      formats.add('91$digits');
      formats.add(digits); // Just 10 digits
    }

    // Format 3: Without +91 prefix (if 12 digits starting with 91)
    if (digits.length == 12 && digits.startsWith('91')) {
      formats.add('+$digits');
      formats.add(digits); // With 91
      formats.add(digits.substring(2)); // Without 91 (10 digits)
    }

    // Format 4: Without + prefix (if 11+ digits)
    if (digits.length >= 11 && phone.startsWith('+')) {
      formats.add(digits);
    }

    // Remove duplicates and return
    return formats.toSet().toList();
  }

  /// Creates a new student user.
  Future<(String?, bool)?> _createStudent(ImportRowData row) async {
    try {
      final userId = _uuid.v4();
      final user = User(
        id: userId,
        phone: row.phone,
        name: row.studentName,
        role: UserRole.student,
        email: row.email,
        isPhoneVerified: true, // Assume verified since owner is importing
        isProfileComplete: true,
        createdAt: DateTime.now(),
      );

      final result = await userRepository.createUser(user);

      return result.fold((failure) {
        log('BulkImportCubit: Failed to create student - ${failure.message}');
        return null;
      }, (createdUser) => (createdUser.id, true));
    } catch (e) {
      log('BulkImportCubit: Student creation error - $e');
      return null;
    }
  }

  /// Finds or creates a matching custom slot based on timing from Excel.
  /// Priority:
  /// 1. Exact timing match (same start and end time)
  /// 2. Close timing match (within 30 minutes)
  /// 3. Create new slot with the Excel timing
  Future<String?> _findOrCreateMatchingSlot(ImportRowData row) async {
    // Reload slots to ensure we have latest
    await _loadSlots();

    final startMinutes = row.slotStartMinutes;
    final endMinutes = row.slotEndMinutes;

    // If we have timing info, try to match by time
    if (startMinutes != null &&
        endMinutes != null &&
        _availableSlots.isNotEmpty) {
      // 1. Try exact match
      for (final slot in _availableSlots) {
        if (slot.isActive &&
            slot.startTime == startMinutes &&
            slot.endTime == endMinutes) {
          log('BulkImportCubit: Found exact slot match: ${slot.name}');
          return slot.id;
        }
      }

      // 2. Try close match (within 30 minutes tolerance)
      for (final slot in _availableSlots) {
        if (slot.isActive &&
            (slot.startTime - startMinutes).abs() <= 30 &&
            (slot.endTime - endMinutes).abs() <= 30) {
          log('BulkImportCubit: Found close slot match: ${slot.name}');
          return slot.id;
        }
      }

      // 3. Create new slot with the timing from Excel
      final newSlot = await _createSlotWithTiming(
        startMinutes: startMinutes,
        endMinutes: endMinutes,
        rawTiming: row.rawTiming,
      );
      if (newSlot != null) {
        _availableSlots.add(newSlot); // Cache it
        return newSlot.id;
      }
    }

    // Fallback: Match by slot name (morning/evening)
    if (_availableSlots.isNotEmpty) {
      final legacySlot = row.slot;
      final matchingSlot = _availableSlots.firstWhere(
        (s) =>
            s.isActive &&
            ((legacySlot == Slot.morning &&
                    s.name.toLowerCase().contains('morning')) ||
                (legacySlot == Slot.evening &&
                    s.name.toLowerCase().contains('evening')) ||
                s.name.toLowerCase().contains(legacySlot.name.toLowerCase())),
        orElse: () => _availableSlots.firstWhere(
          (s) => s.isActive,
          orElse: () => _availableSlots.first,
        ),
      );
      return matchingSlot.id;
    }

    return null;
  }

  /// Creates a new slot with the specified timing.
  Future<CustomSlot?> _createSlotWithTiming({
    required int startMinutes,
    required int endMinutes,
    String? rawTiming,
  }) async {
    if (_libraryId == null) return null;

    // Generate slot name based on timing
    final slotName = _generateSlotName(startMinutes, endMinutes, rawTiming);
    final slotId = _uuid.v4();

    log(
      'BulkImportCubit: Creating new slot "$slotName" ($startMinutes - $endMinutes)',
    );

    final newSlot = CustomSlot(
      id: slotId,
      libraryId: _libraryId!,
      name: slotName,
      startTime: startMinutes,
      endTime: endMinutes,
      price: 500.0, // Default price
      capacity: 100, // Default capacity
      isActive: true,
      createdAt: DateTime.now(),
    );

    final result = await slotRepository.createSlot(newSlot);
    return result.fold(
      (failure) {
        log('BulkImportCubit: Failed to create slot - ${failure.message}');
        return null;
      },
      (createdSlot) {
        log('BulkImportCubit: Successfully created slot: ${createdSlot.name}');
        return createdSlot;
      },
    );
  }

  /// Generates a human-readable slot name from timing.
  String _generateSlotName(
    int startMinutes,
    int endMinutes,
    String? rawTiming,
  ) {
    // Try to use a descriptive name based on timing
    final startHour = startMinutes ~/ 60;
    final endHour = endMinutes ~/ 60;

    // Common slot patterns
    if (startHour >= 5 && startHour <= 7 && endHour >= 12 && endHour <= 14) {
      return 'Morning Slot';
    }
    if (startHour >= 12 && startHour <= 14 && endHour >= 20 && endHour <= 22) {
      return 'Evening Slot';
    }
    if (startHour >= 5 && startHour <= 7 && endHour >= 20 && endHour <= 24) {
      return 'Full Day Slot';
    }
    if (startHour >= 18 && (endHour >= 22 || endHour <= 2)) {
      return 'Night Slot';
    }

    // Use raw timing or generate from times
    if (rawTiming != null && rawTiming.isNotEmpty) {
      return 'Slot ($rawTiming)';
    }

    return 'Slot (${_formatHour(startHour)}-${_formatHour(endHour)})';
  }

  String _formatHour(int hour) {
    if (hour == 0 || hour == 24) return '12 AM';
    if (hour == 12) return '12 PM';
    if (hour < 12) return '$hour AM';
    return '${hour - 12} PM';
  }

  /// Checks if a bed is already occupied/reserved by bed number.
  /// Note: assignedSeatId stores bed NUMBER (e.g., "B01"), NOT Firestore doc ID.
  Future<bool> _isSeatOccupiedByNumber(String seatNumber) async {
    final membershipsResult = await membershipRepository
        .getMembershipsByLibraryId(_libraryId!);

    return membershipsResult.fold(
      (failure) => false, // Assume not occupied on error
      (memberships) {
        final isOccupied = memberships.any(
          (m) =>
              m.assignedSeatId == seatNumber &&
              (m.status == MembershipStatus.active ||
                  m.status == MembershipStatus.pendingPayment),
        );
        if (isOccupied) {
          log('BulkImportCubit: Bed $seatNumber is already occupied');
        }
        return isOccupied;
      },
    );
  }

  /// Validates that a seat exists and returns the normalized seat number.
  /// Returns the seat number (e.g., "S01") if valid, null otherwise.
  /// Note: assignedSeatId stores the seat NUMBER (like "S01"), NOT the Firestore doc ID!
  Future<String?> _validateAndGetSeatNumber(String seatNumber) async {
    final seatsResult = await seatRepository.getSeatsByLibraryId(_libraryId!);

    return seatsResult.fold(
      (failure) {
        log('BulkImportCubit: Failed to get seats - ${failure.message}');
        return null;
      },
      (seats) {
        if (seats.isEmpty) {
          log('BulkImportCubit: No seats found for library $_libraryId');
          return null;
        }

        // Normalize the input seat number
        final normalizedInput = _normalizeSeatNumber(seatNumber);
        final seatNum = int.tryParse(
          seatNumber.replaceAll(RegExp(r'[^\d]'), ''),
        );

        log(
          'BulkImportCubit: Looking for seat "$seatNumber" (normalized: "$normalizedInput", num: $seatNum) in ${seats.length} seats',
        );

        // 1. Try exact match on seatNumber field
        for (final seat in seats) {
          if (seat.seatNumber == seatNumber ||
              seat.seatNumber == normalizedInput) {
            log('BulkImportCubit: Found exact seat match: ${seat.seatNumber}');
            return seat.seatNumber; // Return the seat NUMBER, not doc ID
          }
        }

        // 2. Try normalized comparison
        for (final seat in seats) {
          final normalizedSeat = _normalizeSeatNumber(seat.seatNumber);
          if (normalizedSeat == normalizedInput) {
            log(
              'BulkImportCubit: Found normalized seat match: ${seat.seatNumber}',
            );
            return seat.seatNumber; // Return the seat NUMBER, not doc ID
          }
        }

        // 3. Try by position if we have a valid seat number
        if (seatNum != null && seatNum > 0 && seatNum <= seats.length) {
          // Seats are sorted by seatNumber, so position matches
          final seat = seats[seatNum - 1];
          log(
            'BulkImportCubit: Using seat at position ${seatNum - 1}: ${seat.seatNumber}',
          );
          return seat.seatNumber; // Return the seat NUMBER, not doc ID
        }

        // 4. Try extracting number from each seat and matching
        for (final seat in seats) {
          final existingSeatNum = int.tryParse(
            seat.seatNumber.replaceAll(RegExp(r'[^\d]'), ''),
          );
          if (existingSeatNum == seatNum) {
            log(
              'BulkImportCubit: Found seat by number extraction: ${seat.seatNumber}',
            );
            return seat.seatNumber; // Return the seat NUMBER, not doc ID
          }
        }

        log('BulkImportCubit: No matching seat found for "$seatNumber"');
        return null;
      },
    );
  }

  /// Resets the cubit to initial state.
  void reset() {
    if (isClosed) return;
    emit(const BulkImportState());
  }

  /// Cleans up all imported data for the current library.
  /// Deletes: memberships, invoices, payments (but NOT the library or owner).
  Future<void> cleanupLibraryData() async {
    if (_libraryId == null || _ownerId == null) {
      log('BulkImportCubit: Cannot cleanup - library or owner not set');
      return;
    }

    emit(state.copyWith(status: BulkImportStatus.importing, clearError: true));
    log('BulkImportCubit: Starting cleanup for library $_libraryId');

    try {
      var deletedMemberships = 0;
      var deletedInvoices = 0;
      var deletedPayments = 0;

      // 1. Delete all memberships for this library
      log('BulkImportCubit: Fetching memberships...');
      final membershipsResult = await membershipRepository
          .getMembershipsByLibraryId(_libraryId!);

      await membershipsResult.fold(
        (failure) async {
          log(
            'BulkImportCubit: Failed to fetch memberships - ${failure.message}',
          );
        },
        (memberships) async {
          log(
            'BulkImportCubit: Found ${memberships.length} memberships to delete',
          );
          for (final membership in memberships) {
            final deleteResult = await membershipRepository.deleteMembership(
              membership.id,
            );
            deleteResult.fold(
              (failure) => log(
                'BulkImportCubit: Failed to delete membership ${membership.id}',
              ),
              (_) => deletedMemberships++,
            );
          }
          log('BulkImportCubit: Deleted $deletedMemberships memberships');
        },
      );

      // 2. Delete all payments for this library
      log('BulkImportCubit: Fetching payments...');
      final paymentsResult = await paymentRepository.getPaymentsByLibraryId(
        _libraryId!,
      );

      await paymentsResult.fold(
        (failure) async {
          log('BulkImportCubit: Failed to fetch payments - ${failure.message}');
        },
        (payments) async {
          log('BulkImportCubit: Found ${payments.length} payments to delete');
          for (final payment in payments) {
            final deleteResult = await paymentRepository.deletePayment(
              payment.id,
            );
            deleteResult.fold(
              (failure) => log(
                'BulkImportCubit: Failed to delete payment ${payment.id}',
              ),
              (_) => deletedPayments++,
            );
          }
          log('BulkImportCubit: Deleted $deletedPayments payments');
        },
      );

      // 3. Delete all invoices for this library
      log('BulkImportCubit: Fetching invoices for library $_libraryId...');
      final invoicesResult = await invoiceRepository.getInvoicesForLibrary(
        _libraryId!,
      );

      await invoicesResult.fold(
        (failure) async {
          log(
            'BulkImportCubit: ❌ Failed to fetch invoices - ${failure.message}',
          );
          log('BulkImportCubit: Error type: ${failure.runtimeType}');
        },
        (invoices) async {
          log('BulkImportCubit: ✅ Found ${invoices.length} invoices to delete');
          if (invoices.isEmpty) {
            log('BulkImportCubit: No invoices found for library $_libraryId');
          } else {
            for (final invoice in invoices) {
              log(
                'BulkImportCubit: Deleting invoice ${invoice.id} (${invoice.invoiceNumber})...',
              );
              final deleteResult = await invoiceRepository.deleteInvoice(
                invoice.id,
              );
              deleteResult.fold(
                (failure) {
                  log(
                    'BulkImportCubit: ❌ Failed to delete invoice ${invoice.id}: ${failure.message}',
                  );
                },
                (_) {
                  deletedInvoices++;
                  log('BulkImportCubit: ✅ Deleted invoice ${invoice.id}');
                },
              );
            }
            log(
              'BulkImportCubit: ✅ Successfully deleted $deletedInvoices out of ${invoices.length} invoices',
            );
          }
        },
      );

      log('BulkImportCubit: ✅ Cleanup complete!');
      log('  📊 Summary:');
      log('    - Memberships deleted: $deletedMemberships');
      log('    - Payments deleted: $deletedPayments');
      log('    - Invoices deleted: $deletedInvoices');

      emit(
        state.copyWith(
          status: BulkImportStatus.complete,
          importSummary: ImportSummary(
            totalRows: deletedMemberships + deletedPayments + deletedInvoices,
            successCount:
                deletedMemberships + deletedPayments + deletedInvoices,
            skippedCount: 0,
            failedCount: 0,
            studentsCreated: 0,
            studentsReused: 0,
            results: [],
          ),
        ),
      );
    } catch (e) {
      log('BulkImportCubit: Cleanup error - $e');
      emit(
        state.copyWith(
          status: BulkImportStatus.error,
          errorMessage: 'Cleanup failed: $e',
        ),
      );
    }
  }
}
