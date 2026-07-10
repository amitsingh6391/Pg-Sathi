import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/services/analytics_service.dart';
import '../core/core.dart';
import '../entities/invoice.dart';
import '../entities/library.dart';
import '../entities/membership.dart';
import '../entities/slot.dart';
import '../entities/user.dart';
import '../repositories/invoice_repository.dart';
import '../repositories/library_repository.dart';
import '../repositories/membership_repository.dart';
import '../repositories/slot_repository.dart';
import '../repositories/user_repository.dart';

/// Use case for generating an invoice after successful payment.
/// Invoice is only generated if it doesn't already exist for the membership and month.
class GenerateInvoice implements UseCase<Invoice, GenerateInvoiceParams> {
  const GenerateInvoice({
    required this.invoiceRepository,
    required this.membershipRepository,
    required this.libraryRepository,
    required this.userRepository,
    required this.slotRepository,
    required this.analyticsService,
  });

  final InvoiceRepository invoiceRepository;
  final MembershipRepository membershipRepository;
  final LibraryRepository libraryRepository;
  final UserRepository userRepository;
  final SlotRepository slotRepository;
  final AnalyticsService analyticsService;

  @override
  Future<Either<Failure, Invoice>> call(GenerateInvoiceParams params) async {
    final billingMonth = _getBillingMonth(params.paymentDate);

    // Check if invoice already exists for this specific payment
    // This prevents duplicate invoices for the same payment
    // But allows multiple invoices for different payments (e.g., partial + completion)
    final existingResult = await invoiceRepository.getInvoiceByPaymentId(
      params.paymentId,
    );

    return existingResult.fold((failure) => Left(failure), (
      existingInvoice,
    ) async {
      // Return existing invoice if found (same payment, don't duplicate)
      if (existingInvoice != null) {
        return Right(existingInvoice);
      }

      // Fetch membership details
      final membershipResult = await membershipRepository.getMembershipById(
        params.membershipId,
      );
      return membershipResult.fold((failure) => Left(failure), (
        membership,
      ) async {
        // Fetch library details
        final libraryResult = await libraryRepository.getLibraryById(
          membership.libraryId,
        );
        return libraryResult.fold((failure) => Left(failure), (library) async {
          if (library == null) {
            return Left(ValidationFailure(message: 'Library not found'));
          }

          // Fetch student details (use phone number if userId is null)
          if (membership.userId != null) {
            final studentResult = await userRepository.getUserById(
              membership.userId!,
            );
            return studentResult.fold((failure) => Left(failure), (
              studentUser,
            ) async {
              // Continue with invoice generation
              return await _generateInvoiceWithStudent(
                membership: membership,
                library: library,
                student: studentUser,
                billingMonth: billingMonth,
                paymentId: params.paymentId,
                paymentDate: params.paymentDate,
                amountPaid: params.amountPaid,
                currency: params.currency,
              );
            });
          } else {
            // For unregistered students, use phone number as identifier
            // Use studentName if available, otherwise fallback to phone number
            final studentName =
                membership.studentName ?? membership.phoneNumber;
            final student = User(
              id: membership.phoneNumber, // Use phone as temporary ID
              phone: membership.phoneNumber,
              name: studentName,
              email: '',
              role: UserRole.student,
              isProfileComplete:
                  membership.studentName != null &&
                  membership.studentName!.isNotEmpty,
            );

            // Continue with invoice generation
            return await _generateInvoiceWithStudent(
              membership: membership,
              library: library,
              student: student,
              billingMonth: billingMonth,
              paymentId: params.paymentId,
              paymentDate: params.paymentDate,
              amountPaid: params.amountPaid,
              currency: params.currency,
            );
          }
        });
      });
    });
  }

  Future<Either<Failure, Invoice>> _generateInvoiceWithStudent({
    required Membership membership,
    required Library library,
    required User student,
    required String billingMonth,
    required String paymentId,
    required DateTime paymentDate,
    required double amountPaid,
    required String currency,
  }) async {
    // Fetch owner details
    final ownerResult = await userRepository.getUserById(library.ownerId);
    return ownerResult.fold((failure) => Left(failure), (owner) async {
      // Generate invoice number
      final invoiceNumberResult = await invoiceRepository.generateInvoiceNumber(
        library.id,
      );
      return invoiceNumberResult.fold((failure) => Left(failure), (
        invoiceNumber,
      ) async {
        // Get session timing and slot name (async - fetches custom slot if needed)
        final slotInfoResult = await _getSlotInfo(
          membership.slotId,
          membership.slot,
          library.id,
        );
        return slotInfoResult.fold((failure) => Left(failure), (
          slotInfo,
        ) async {
          // Create invoice
          final invoice = _createInvoice(
            membership: membership,
            library: library,
            student: student,
            owner: owner,
            invoiceNumber: invoiceNumber,
            billingMonth: billingMonth,
            paymentId: paymentId,
            paymentDate: paymentDate,
            amountPaid: amountPaid,
            currency: currency,
            slotName: slotInfo['name']!,
            sessionTiming: slotInfo['timing']!,
          );

          // Save invoice
          final result = await invoiceRepository.createInvoice(invoice);
          
          // Track invoice generation on success
          result.fold(
            (_) => null, // Don't track on failure
            (savedInvoice) => analyticsService.trackInvoiceGenerated(
              invoiceId: savedInvoice.id,
              invoiceType: _getInvoiceType(membership, amountPaid),
              amount: amountPaid,
              additionalParams: {
                'billing_month': billingMonth,
                'plan_type': membership.plan.name,
                'payment_method': membership.paymentMethod?.name ?? 'unknown',
              },
            ),
          );
          
          return result;
        });
      });
    });
  }

  String _getBillingMonth(DateTime date) {
    return DateFormat('yyyy-MM').format(date);
  }

  Invoice _createInvoice({
    required Membership membership,
    required Library library,
    required User student,
    required User owner,
    required String invoiceNumber,
    required String billingMonth,
    required String paymentId,
    required DateTime paymentDate,
    required double amountPaid,
    required String currency,
    required String slotName,
    required String sessionTiming,
  }) {
    return Invoice(
      id: const Uuid().v4(),
      invoiceNumber: invoiceNumber,
      libraryId: library.id,
      libraryName: library.name,
      libraryAddress: library.fullAddress ?? library.location,
      libraryLogoUrl: owner.avatarUrl,
      ownerId: library.ownerId,
      ownerName: owner.displayName,
      ownerContact: owner.phone,
      studentId: student.id,
      // Use name directly for invoices (not displayName which has special logic)
      // For unregistered students, this will be the studentName from membership
      // For registered students, this will be their actual name
      studentName: student.name.isNotEmpty ? student.name : student.displayName,
      studentPhone: student.phone,
      membershipId: membership.id,
      seatNumber: membership.assignedSeatId ?? 'N/A',
      slotName: slotName, // Custom slot name or Morning/Evening
      slot: membership.slot ?? Slot.morning, // Keep for backward compatibility
      sessionTiming: sessionTiming,
      billingMonth: billingMonth,
      amountPaid: amountPaid,
      currency: currency,
      paymentId: paymentId,
      paymentDate: paymentDate,
      generatedAt: DateTime.now(),
      expiryDate: membership.endDate,
    );
  }

  Future<Either<Failure, Map<String, String>>> _getSlotInfo(
    String? slotId,
    Slot? legacySlot,
    String libraryId,
  ) async {
    // If custom slot ID is provided, fetch the slot and use its name and display time
    if (slotId != null && slotId.isNotEmpty) {
      final slotResult = await slotRepository.getSlotById(libraryId, slotId);
      return slotResult.fold((failure) => Left(failure), (slot) {
        if (slot != null) {
          return Right({
            'name': slot.name,
            'timing': slot.displayTime,
          });
        }
        // Fallback if slot not found
        return const Right({
          'name': 'Custom Slot',
          'timing': 'Not assigned',
        });
      });
    }

    // For legacy slots, use predefined timing
    if (legacySlot != null) {
      switch (legacySlot) {
        case Slot.morning:
          return const Right({
            'name': 'Morning',
            'timing': '6:00 AM – 2:00 PM',
          });
        case Slot.evening:
          return const Right({
            'name': 'Evening',
            'timing': '2:00 PM – 10:00 PM',
          });
      }
    }

    // Fallback if no slot information
    return const Right({
      'name': 'Not assigned',
      'timing': 'Not assigned',
    });
  }

  /// Determines invoice type based on payment details.
  String _getInvoiceType(Membership membership, double amountPaid) {
    if (membership.paymentBreakdown != null) {
      final breakdown = membership.paymentBreakdown!;
      if (amountPaid < breakdown.totalAmount) {
        return 'partial_payment';
      } else {
        return 'full_payment';
      }
    }
    return 'standard';
  }
}

/// Parameters for GenerateInvoice use case.
class GenerateInvoiceParams extends Equatable {
  const GenerateInvoiceParams({
    required this.membershipId,
    required this.paymentId,
    required this.paymentDate,
    required this.amountPaid,
    required this.currency,
  });

  final String membershipId;
  final String paymentId;
  final DateTime paymentDate;
  final double amountPaid;
  final String currency;

  @override
  List<Object?> get props => [
    membershipId,
    paymentId,
    paymentDate,
    amountPaid,
    currency,
  ];
}

/// Validation failure for invoice generation.
class ValidationFailure extends Failure {
  const ValidationFailure({super.message});
}
