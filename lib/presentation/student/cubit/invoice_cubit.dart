import 'dart:ui' show Rect;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/services/analytics_service.dart';
import '../../../data/services/invoice_pdf_service.dart';
import '../../../data/services/review_prompt_service.dart';
import '../../../domain/entities/invoice.dart';
import '../../../domain/usecases/delete_invoice.dart';
import '../../../domain/usecases/get_invoices_for_student.dart';
import 'invoice_state.dart';

/// Cubit for managing student invoices.
class InvoiceCubit extends Cubit<InvoiceState> {
  InvoiceCubit({
    required this.getInvoicesForStudent,
    required this.pdfService,
    required this.deleteInvoice,
    required this.analyticsService,
  }) : super(const InvoiceState());

  final GetInvoicesForStudent getInvoicesForStudent;
  final InvoicePdfService pdfService;
  final DeleteInvoice deleteInvoice;
  final AnalyticsService analyticsService;

  /// Load invoices for a student.
  Future<void> loadInvoices(String studentId) async {
    emit(state.copyWith(status: InvoiceStatus.loading));

    final result = await getInvoicesForStudent(
      GetInvoicesForStudentParams(studentId: studentId),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: InvoiceStatus.error,
          errorMessage: failure.message ?? 'Failed to load invoices',
        ),
      ),
      (invoices) => emit(
        state.copyWith(status: InvoiceStatus.loaded, invoices: invoices),
      ),
    );
  }

  /// Download and open a PDF invoice.
  Future<void> downloadInvoice(Invoice invoice) async {
    emit(
      state.copyWith(
        status: InvoiceStatus.downloading,
        downloadingInvoiceId: invoice.id,
      ),
    );

    try {
      await pdfService.generateAndOpen(invoice);
      
      // Track successful invoice download
      analyticsService.trackInvoiceDownloaded(
        invoiceId: invoice.id,
        invoiceType: 'membership',
        additionalParams: {
          'amount': invoice.amountPaid,
          'billing_month': invoice.billingMonth,
        },
      );

      sl<ReviewPromptService>().requestReviewOnce();

      emit(
        state.copyWith(
          status: InvoiceStatus.loaded,
          downloadingInvoiceId: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: InvoiceStatus.error,
          errorMessage: 'Failed to download invoice: ${e.toString()}',
          downloadingInvoiceId: null,
        ),
      );
    }
  }

  /// Share a PDF invoice.
  /// [shareOrigin] is needed for iPad to show share sheet properly.
  Future<void> shareInvoice(Invoice invoice, {Rect? shareOrigin}) async {
    emit(
      state.copyWith(
        status: InvoiceStatus.downloading,
        downloadingInvoiceId: invoice.id,
      ),
    );

    try {
      await pdfService.generateAndShare(invoice, shareOrigin: shareOrigin);
      
      // Track successful invoice share
      analyticsService.trackInvoiceShared(
        invoiceId: invoice.id,
        invoiceType: 'membership',
        shareMethod: 'system_share_sheet',
        additionalParams: {
          'amount': invoice.amountPaid,
          'billing_month': invoice.billingMonth,
        },
      );

      emit(
        state.copyWith(
          status: InvoiceStatus.loaded,
          downloadingInvoiceId: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: InvoiceStatus.error,
          errorMessage: 'Failed to share invoice: ${e.toString()}',
          downloadingInvoiceId: null,
        ),
      );
    }
  }

  /// Delete an invoice.
  Future<void> deleteInvoiceById(String invoiceId, String studentId) async {
    emit(state.copyWith(status: InvoiceStatus.loading));

    final result = await deleteInvoice(
      DeleteInvoiceParams(invoiceId: invoiceId),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: InvoiceStatus.error,
          errorMessage: failure.message ?? 'Failed to delete invoice',
        ),
      ),
      (_) {
        // Remove the deleted invoice from the list
        final updatedInvoices = state.invoices
            .where((inv) => inv.id != invoiceId)
            .toList();
        emit(
          state.copyWith(
            status: InvoiceStatus.loaded,
            invoices: updatedInvoices,
          ),
        );
      },
    );
  }
}
