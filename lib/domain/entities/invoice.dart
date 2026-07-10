import 'package:equatable/equatable.dart';

import 'slot.dart';

/// Represents a fees receipt / invoice for membership payment.
/// Immutable once generated after successful payment.
class Invoice extends Equatable {
  const Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.libraryId,
    required this.libraryName,
    required this.libraryAddress,
    this.libraryLogoUrl,
    required this.ownerId,
    required this.ownerName,
    required this.ownerContact,
    required this.studentId,
    required this.studentName,
    required this.studentPhone,
    required this.membershipId,
    required this.seatNumber,
    required this.slot,
    this.slotName,
    required this.sessionTiming,
    required this.billingMonth,
    required this.amountPaid,
    required this.currency,
    required this.paymentId,
    required this.paymentDate,
    required this.generatedAt,
    required this.expiryDate,
  });

  final String id;

  /// Human-readable invoice number (e.g., INV-2024-001234)
  final String invoiceNumber;

  // Library details
  final String libraryId;
  final String libraryName;
  final String libraryAddress;

  /// Owner's avatar URL used as library logo on invoices.
  /// Null for invoices created before this field was added.
  final String? libraryLogoUrl;

  // Owner details
  final String ownerId;
  final String ownerName;
  final String ownerContact;

  // Student details
  final String studentId;
  final String studentName;
  final String studentPhone;

  // Membership details
  final String membershipId;
  final String seatNumber;
  final Slot slot;
  final String? slotName; // Custom slot name (e.g., "Morning Batch") or null for legacy
  final String sessionTiming;

  /// Billing month in YYYY-MM format
  final String billingMonth;

  // Payment details
  final double amountPaid;
  final String currency;
  final String paymentId;
  final DateTime paymentDate;

  /// When the invoice was generated
  final DateTime generatedAt;

  /// Membership expiry date
  final DateTime expiryDate;

  /// Formatted billing month for display (e.g., "December 2024")
  String get formattedBillingMonth {
    final parts = billingMonth.split('-');
    if (parts.length != 2) return billingMonth;

    final year = parts[0];
    final month = int.tryParse(parts[1]) ?? 1;

    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[month - 1]} $year';
  }

  /// Formatted amount with currency (rounded to integer)
  String get formattedAmount {
    final roundedAmount = amountPaid.round().toInt();
    if (currency == 'INR') {
      return '₹$roundedAmount';
    }
    return '$currency $roundedAmount';
  }

  /// PDF filename format
  String get pdfFileName {
    final sanitizedName = libraryName
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(' ', '_');
    return '${sanitizedName}_Invoice_$billingMonth.pdf';
  }

  @override
  List<Object?> get props => [
    id,
    invoiceNumber,
    libraryId,
    libraryName,
    libraryAddress,
    libraryLogoUrl,
    ownerId,
    ownerName,
    ownerContact,
    studentId,
    studentName,
    studentPhone,
    membershipId,
    seatNumber,
    slot,
    slotName,
    sessionTiming,
    billingMonth,
    amountPaid,
    currency,
    paymentId,
    paymentDate,
    generatedAt,
    expiryDate,
  ];

  Invoice copyWith({
    String? id,
    String? invoiceNumber,
    String? libraryId,
    String? libraryName,
    String? libraryAddress,
    String? libraryLogoUrl,
    String? ownerId,
    String? ownerName,
    String? ownerContact,
    String? studentId,
    String? studentName,
    String? studentPhone,
    String? membershipId,
    String? seatNumber,
    Slot? slot,
    String? slotName,
    String? sessionTiming,
    String? billingMonth,
    double? amountPaid,
    String? currency,
    String? paymentId,
    DateTime? paymentDate,
    DateTime? generatedAt,
    DateTime? expiryDate,
  }) {
    return Invoice(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      libraryId: libraryId ?? this.libraryId,
      libraryName: libraryName ?? this.libraryName,
      libraryAddress: libraryAddress ?? this.libraryAddress,
      libraryLogoUrl: libraryLogoUrl ?? this.libraryLogoUrl,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      ownerContact: ownerContact ?? this.ownerContact,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentPhone: studentPhone ?? this.studentPhone,
      membershipId: membershipId ?? this.membershipId,
      seatNumber: seatNumber ?? this.seatNumber,
      slot: slot ?? this.slot,
      slotName: slotName ?? this.slotName,
      sessionTiming: sessionTiming ?? this.sessionTiming,
      billingMonth: billingMonth ?? this.billingMonth,
      amountPaid: amountPaid ?? this.amountPaid,
      currency: currency ?? this.currency,
      paymentId: paymentId ?? this.paymentId,
      paymentDate: paymentDate ?? this.paymentDate,
      generatedAt: generatedAt ?? this.generatedAt,
      expiryDate: expiryDate ?? this.expiryDate,
    );
  }
}
