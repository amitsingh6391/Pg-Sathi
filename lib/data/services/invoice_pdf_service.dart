import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../core/utils/file_download_helper.dart';
import '../../core/utils/whatsapp_launcher.dart';
import '../../domain/entities/invoice.dart';

/// Service for generating and handling invoice PDFs.
class InvoicePdfService {
  const InvoicePdfService();

  /// Policy disclaimer rendered in the receipt footer.
  /// Kept as a constant so the wording stays consistent across receipts and
  /// is trivial to update in one place if the policy changes.
  static const String _nonRefundableNotice =
      'Note: Fees once paid are non-refundable.';

  /// Converts Unicode characters to ASCII equivalents for PDF compatibility.
  /// Replaces rupee symbol (₹) with "Rs." and en-dash (–) with hyphen (-).
  String _sanitizeForPdf(String text) {
    return text
        .replaceAll('₹', 'Rs.') // Replace rupee symbol
        .replaceAll('–', '-'); // Replace en-dash with hyphen
  }

  /// Fetches the library logo image bytes from URL.
  /// Returns null if URL is missing or fetch fails -- PDF renders without logo gracefully.
  Future<pw.ImageProvider?> _fetchLogoImage(String? logoUrl) async {
    if (logoUrl == null || logoUrl.isEmpty) return null;

    try {
      final response = await http.get(Uri.parse(logoUrl));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return pw.MemoryImage(response.bodyBytes);
      }
    } catch (e) {
      debugPrint('InvoicePdfService: Failed to fetch logo image: $e');
    }
    return null;
  }

  /// Generates a PDF for the invoice and returns the file path (mobile) or bytes (web).
  Future<String> generatePdf(Invoice invoice) async {
    final logoImage = await _fetchLogoImage(invoice.libraryLogoUrl);
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) => _buildPage(invoice, logoImage),
      ),
    );

    if (kIsWeb) {
      // Web: Return a temporary path (not used, but needed for compatibility)
      // The actual download will use bytes directly
      return 'web_temp/${invoice.pdfFileName}';
    } else {
      // Mobile: Save to temporary directory
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${invoice.pdfFileName}');
      final bytes = await pdf.save();
      await file.writeAsBytes(bytes);
      return file.path;
    }
  }

  /// Generates PDF bytes for the invoice.
  Future<Uint8List> generatePdfBytes(Invoice invoice) async {
    final logoImage = await _fetchLogoImage(invoice.libraryLogoUrl);
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) => _buildPage(invoice, logoImage),
      ),
    );

    return pdf.save();
  }

  /// Generates PDF and opens it (mobile) or downloads it (web).
  Future<void> generateAndOpen(Invoice invoice) async {
    if (kIsWeb) {
      // Web: Download the file directly
      final bytes = await generatePdfBytes(invoice);
      await FileDownloadHelper.downloadAndOpenFile(
        bytes: bytes,
        fileName: invoice.pdfFileName,
        mimeType: 'application/pdf',
      );
    } else {
      // Mobile: Save and open
      final path = await generatePdf(invoice);
      await OpenFilex.open(path);
    }
  }

  /// Generates PDF and shares it.
  /// [shareOrigin] is needed for iPad to determine share sheet origin.
  Future<void> generateAndShare(Invoice invoice, {Rect? shareOrigin}) async {
    if (kIsWeb) {
      // Web: Use bytes directly
      final bytes = await generatePdfBytes(invoice);
      await FileDownloadHelper.downloadFile(
        bytes: bytes,
        fileName: invoice.pdfFileName,
        mimeType: 'application/pdf',
      );
    } else {
      // Mobile: Use file path
      final path = await generatePdf(invoice);
      await Share.shareXFiles(
        [XFile(path)],
        subject: 'Invoice - ${invoice.formattedBillingMonth}',
        sharePositionOrigin: shareOrigin,
      );
    }
  }

  /// Opens WhatsApp with a pre-filled payment confirmation message.
  /// No PDF attachment — simple and reliable on both Android and iOS.
  /// Users can download the PDF separately if needed.
  Future<void> shareToWhatsApp(Invoice invoice, {Rect? shareOrigin}) async {
    final phone = invoice.studentPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final phoneWithCode =
        phone.startsWith('91') ? phone : '91$phone';

    final message =
        '🎉 Hello ${invoice.studentName}!\n\n'
        'Your seat has been successfully booked. '
        'You can now enjoy all library facilities. 📚\n\n'
        '🧾 *Payment Details*\n'
        '━━━━━━━━━━━━━━━━\n'
        '📅 Month: ${invoice.formattedBillingMonth}\n'
        '💰 Amount Paid: ₹${invoice.amountPaid}\n'
        '🪑 Seat: ${invoice.seatNumber}\n'
        '━━━━━━━━━━━━━━━━\n\n'
        'Please keep this receipt for your records.\n'
        'Feel free to contact us for any assistance. 🙏';

    final launched = await WhatsAppLauncher.launch(
      phone: phoneWithCode,
      message: message,
    );

    if (!launched) {
      throw Exception('Could not open WhatsApp. Is it installed?');
    }
  }

  pw.Widget _buildPage(Invoice invoice, pw.ImageProvider? logoImage) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final timeFormat = DateFormat('hh:mm a');

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Header with optional library logo
        _buildHeader(invoice, logoImage),
        pw.SizedBox(height: 30),

        // Invoice Details
        _buildInvoiceDetails(invoice, dateFormat),
        pw.SizedBox(height: 24),

        // Divider
        pw.Container(height: 1, color: PdfColors.grey300),
        pw.SizedBox(height: 24),

        // Student Details
        _buildStudentDetails(invoice, dateFormat),
        pw.SizedBox(height: 24),

        // Payment Summary
        _buildPaymentSummary(invoice, dateFormat, timeFormat),
        pw.Spacer(),

        // Divider
        pw.Container(height: 1, color: PdfColors.grey300),
        pw.SizedBox(height: 24),

        // Footer
        _buildFooter(invoice),
      ],
    );
  }

  pw.Widget _buildHeader(Invoice invoice, pw.ImageProvider? logoImage) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Library logo (owner's profile pic)
        if (logoImage != null) ...[
          pw.Container(
            width: 56,
            height: 56,
            decoration: pw.BoxDecoration(
              shape: pw.BoxShape.circle,
              border: pw.Border.all(color: PdfColors.grey300, width: 1),
            ),
            child: pw.ClipOval(
              child: pw.Image(logoImage, fit: pw.BoxFit.cover),
            ),
          ),
          pw.SizedBox(width: 14),
        ],
        // Library name, address, and badge
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                invoice.libraryName,
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey800,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                invoice.libraryAddress,
                style: const pw.TextStyle(
                  fontSize: 11,
                  color: PdfColors.grey600,
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  'FEES RECEIPT',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildInvoiceDetails(Invoice invoice, DateFormat dateFormat) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildLabelValue('Invoice No.', invoice.invoiceNumber),
            pw.SizedBox(height: 8),
            _buildLabelValue('Billing Month', invoice.formattedBillingMonth),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            _buildLabelValue('Date', dateFormat.format(invoice.generatedAt)),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildStudentDetails(Invoice invoice, DateFormat dateFormat) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey200),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'MEMBER DETAILS',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey600,
              letterSpacing: 1,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildLabelValue('Name', invoice.studentName),
                    pw.SizedBox(height: 8),
                    _buildLabelValue('Phone', invoice.studentPhone),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildLabelValue('Seat No.', invoice.seatNumber),
                    pw.SizedBox(height: 8),
                    _buildLabelValue(
                      'Slot',
                      _sanitizeForPdf(invoice.slotName ?? invoice.slot.displayName),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          _buildLabelValue(
            'Session Timing',
            _sanitizeForPdf(invoice.sessionTiming),
          ),
          pw.SizedBox(height: 8),
          _buildLabelValue(
            'Membership Expires',
            dateFormat.format(invoice.expiryDate),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPaymentSummary(
    Invoice invoice,
    DateFormat dateFormat,
    DateFormat timeFormat,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.green100),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'PAYMENT SUMMARY',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey600,
              letterSpacing: 1,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildLabelValue('Payment ID', invoice.paymentId),
                  pw.SizedBox(height: 8),
                  _buildLabelValue(
                    'Payment Date',
                    '${dateFormat.format(invoice.paymentDate)} at ${timeFormat.format(invoice.paymentDate)}',
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Amount Paid',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    _sanitizeForPdf(invoice.formattedAmount),
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: pw.BoxDecoration(
              color: PdfColors.green100,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              'PAID',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(Invoice invoice) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Owner',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  invoice.ownerName,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey800,
                  ),
                ),
                pw.Text(
                  invoice.ownerContact,
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Center(
          child: pw.Text(
            _nonRefundableNotice,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Center(
          child: pw.Text(
            'This is a system generated receipt and does not require a signature.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildLabelValue(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          _sanitizeForPdf(value),
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800,
          ),
        ),
      ],
    );
  }
}
