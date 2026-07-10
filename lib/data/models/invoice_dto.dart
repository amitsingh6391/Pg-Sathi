import 'package:cloud_firestore/cloud_firestore.dart';

/// Data Transfer Object for Invoice entity.
class InvoiceDto {
  const InvoiceDto({
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
  final String invoiceNumber;
  final String libraryId;
  final String libraryName;
  final String libraryAddress;
  final String? libraryLogoUrl;
  final String ownerId;
  final String ownerName;
  final String ownerContact;
  final String studentId;
  final String studentName;
  final String studentPhone;
  final String membershipId;
  final String seatNumber;
  final String slot;
  final String? slotName;
  final String sessionTiming;
  final String billingMonth;
  final double amountPaid;
  final String currency;
  final String paymentId;
  final Timestamp paymentDate;
  final Timestamp generatedAt;
  final Timestamp expiryDate;

  factory InvoiceDto.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return InvoiceDto(
      id: doc.id,
      invoiceNumber: data['invoiceNumber'] as String,
      libraryId: data['libraryId'] as String,
      libraryName: data['libraryName'] as String,
      libraryAddress: data['libraryAddress'] as String? ?? '',
      libraryLogoUrl: data['libraryLogoUrl'] as String?,
      ownerId: data['ownerId'] as String,
      ownerName: data['ownerName'] as String,
      ownerContact: data['ownerContact'] as String? ?? '',
      studentId: data['studentId'] as String,
      studentName: data['studentName'] as String,
      studentPhone: data['studentPhone'] as String? ?? '',
      membershipId: data['membershipId'] as String,
      seatNumber: data['seatNumber'] as String,
      slot: data['slot'] as String,
      slotName: data['slotName'] as String?,
      sessionTiming: data['sessionTiming'] as String,
      billingMonth: data['billingMonth'] as String,
      amountPaid: (data['amountPaid'] as num).toDouble(),
      currency: data['currency'] as String,
      paymentId: data['paymentId'] as String,
      paymentDate: data['paymentDate'] as Timestamp,
      generatedAt: data['generatedAt'] as Timestamp,
      expiryDate:
          data['expiryDate'] as Timestamp? ??
          data['generatedAt'] as Timestamp, // Fallback for old invoices
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'invoiceNumber': invoiceNumber,
      'libraryId': libraryId,
      'libraryName': libraryName,
      'libraryAddress': libraryAddress,
      if (libraryLogoUrl != null) 'libraryLogoUrl': libraryLogoUrl,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'ownerContact': ownerContact,
      'studentId': studentId,
      'studentName': studentName,
      'studentPhone': studentPhone,
      'membershipId': membershipId,
      'seatNumber': seatNumber,
      'slot': slot,
      'slotName': slotName,
      'sessionTiming': sessionTiming,
      'billingMonth': billingMonth,
      'amountPaid': amountPaid,
      'currency': currency,
      'paymentId': paymentId,
      'paymentDate': paymentDate,
      'generatedAt': generatedAt,
      'expiryDate': expiryDate,
    };
  }

  static const String collectionName = 'invoices';
}
