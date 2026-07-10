import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/invoice.dart';
import '../../domain/entities/slot.dart';
import '../models/invoice_dto.dart';

/// Mapper for Invoice entity <-> InvoiceDto conversion.
class InvoiceMapper {
  const InvoiceMapper._();

  static Invoice toEntity(InvoiceDto dto) {
    return Invoice(
      id: dto.id,
      invoiceNumber: dto.invoiceNumber,
      libraryId: dto.libraryId,
      libraryName: dto.libraryName,
      libraryAddress: dto.libraryAddress,
      libraryLogoUrl: dto.libraryLogoUrl,
      ownerId: dto.ownerId,
      ownerName: dto.ownerName,
      ownerContact: dto.ownerContact,
      studentId: dto.studentId,
      studentName: dto.studentName,
      studentPhone: dto.studentPhone,
      membershipId: dto.membershipId,
      seatNumber: dto.seatNumber,
      slot: _parseSlot(dto.slot),
      slotName: dto.slotName,
      sessionTiming: dto.sessionTiming,
      billingMonth: dto.billingMonth,
      amountPaid: dto.amountPaid,
      currency: dto.currency,
      paymentId: dto.paymentId,
      paymentDate: dto.paymentDate.toDate(),
      generatedAt: dto.generatedAt.toDate(),
      expiryDate: dto.expiryDate.toDate(),
    );
  }

  static InvoiceDto toDto(Invoice entity) {
    return InvoiceDto(
      id: entity.id,
      invoiceNumber: entity.invoiceNumber,
      libraryId: entity.libraryId,
      libraryName: entity.libraryName,
      libraryAddress: entity.libraryAddress,
      libraryLogoUrl: entity.libraryLogoUrl,
      ownerId: entity.ownerId,
      ownerName: entity.ownerName,
      ownerContact: entity.ownerContact,
      studentId: entity.studentId,
      studentName: entity.studentName,
      studentPhone: entity.studentPhone,
      membershipId: entity.membershipId,
      seatNumber: entity.seatNumber,
      slot: entity.slot.name,
      slotName: entity.slotName,
      sessionTiming: entity.sessionTiming,
      billingMonth: entity.billingMonth,
      amountPaid: entity.amountPaid,
      currency: entity.currency,
      paymentId: entity.paymentId,
      paymentDate: Timestamp.fromDate(entity.paymentDate),
      generatedAt: Timestamp.fromDate(entity.generatedAt),
      expiryDate: Timestamp.fromDate(entity.expiryDate),
    );
  }

  static Slot _parseSlot(String slot) {
    return Slot.values.firstWhere(
      (e) => e.name == slot,
      orElse: () => Slot.morning,
    );
  }
}
