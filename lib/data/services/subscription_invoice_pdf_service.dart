import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../domain/entities/subscription.dart';

/// Company details for invoices.
class _CompanyInfo {
  static const String name = 'PG Sathi';
  static const String tagline = 'Smart Library Management Platform';
  static const String email = 'service@pgsathi.in';
  static const String phone = '+91 9548582776';
  static const String website = 'www.pgsathi.in';
}

/// Service for generating subscription invoice PDFs.
class SubscriptionInvoicePdfService {
  const SubscriptionInvoicePdfService();

  /// Sanitize text for PDF compatibility.
  String _sanitize(String text) {
    return text.replaceAll('₹', 'Rs.').replaceAll('–', '-');
  }

  /// Generate PDF file path.
  String _getFileName(Subscription sub) {
    final dateStr = DateFormat(
      'yyyy-MM',
    ).format(sub.approvedAt ?? sub.createdAt ?? DateTime.now());
    return 'Subscription_Invoice_$dateStr.pdf';
  }

  /// Generates PDF and returns file path.
  Future<String> generatePdf({
    required Subscription subscription,
    required String libraryName,
    String ownerPhone = '',
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => _buildPage(
          subscription: subscription,
          libraryName: libraryName,
          ownerPhone: ownerPhone,
        ),
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${_getFileName(subscription)}');
    final bytes = await pdf.save();
    await file.writeAsBytes(bytes);

    return file.path;
  }

  /// Generates and opens PDF.
  Future<void> generateAndOpen({
    required Subscription subscription,
    required String libraryName,
    String ownerPhone = '',
  }) async {
    final path = await generatePdf(
      subscription: subscription,
      libraryName: libraryName,
      ownerPhone: ownerPhone,
    );
    await OpenFilex.open(path);
  }

  /// Generates and shares PDF.
  Future<void> generateAndShare({
    required Subscription subscription,
    required String libraryName,
    String ownerPhone = '',
    Rect? shareOrigin,
  }) async {
    final path = await generatePdf(
      subscription: subscription,
      libraryName: libraryName,
      ownerPhone: ownerPhone,
    );

    await Share.shareXFiles(
      [XFile(path)],
      subject: 'Subscription Invoice - $libraryName',
      sharePositionOrigin: shareOrigin,
    );
  }

  /// Generates PDF bytes for printing.
  Future<Uint8List> generatePdfBytes({
    required Subscription subscription,
    required String libraryName,
    String ownerPhone = '',
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => _buildPage(
          subscription: subscription,
          libraryName: libraryName,
          ownerPhone: ownerPhone,
        ),
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildPage({
    required Subscription subscription,
    required String libraryName,
    String ownerPhone = '',
  }) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Company Header
        _buildCompanyHeader(),
        pw.SizedBox(height: 24),

        // Invoice Title & Details Row
        _buildInvoiceTitleRow(subscription, dateFormat),
        pw.SizedBox(height: 24),

        // Bill To Section
        _buildBillToSection(libraryName, ownerPhone),
        pw.SizedBox(height: 24),

        pw.Container(height: 1, color: PdfColors.grey300),
        pw.SizedBox(height: 24),

        // Plan Details
        _buildPlanDetails(subscription, dateFormat),
        pw.SizedBox(height: 24),

        // Payment Summary
        _buildPaymentSummary(subscription, dateFormat),
        pw.SizedBox(height: 40),

        pw.Container(height: 1, color: PdfColors.grey300),
        pw.SizedBox(height: 24),

        // Footer
        _buildFooter(),
      ],
    );
  }

  pw.Widget _buildCompanyHeader() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Company Info
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              _CompanyInfo.name,
              style: pw.TextStyle(
                fontSize: 26,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue800,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              _CompanyInfo.tagline,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              _CompanyInfo.email,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.Text(
              _CompanyInfo.phone,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.Text(
              _CompanyInfo.website,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          ],
        ),
        // Invoice Badge
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue50,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
            'SUBSCRIPTION\nINVOICE',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
              letterSpacing: 1,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildInvoiceTitleRow(Subscription sub, DateFormat dateFormat) {
    final invoiceDate = sub.approvedAt ?? sub.createdAt ?? DateTime.now();
    final invoiceNumber = 'INV-${sub.id.substring(0, 8).toUpperCase()}';

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Invoice Number',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey600,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                invoiceNumber,
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey800,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'Invoice Date',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey600,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                dateFormat.format(invoiceDate),
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey800,
                ),
              ),
            ],
          ),
          if (sub.transactionId != null)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Transaction ID',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  sub.transactionId!,
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey800,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  pw.Widget _buildBillToSection(String libraryName, String ownerPhone) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'BILL TO',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey500,
                    letterSpacing: 1,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  libraryName,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey800,
                  ),
                ),
                if (ownerPhone.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    ownerPhone,
                    style: const pw.TextStyle(
                      fontSize: 11,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

  pw.Widget _buildPlanDetails(Subscription sub, DateFormat dateFormat) {
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
            'SUBSCRIPTION DETAILS',
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
                    _buildLabelValue('Plan', _getPlanName(sub.planId)),
                    pw.SizedBox(height: 8),
                    _buildLabelValue('Seats', '${sub.seatCount}'),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildLabelValue(
                      'Duration',
                      '${sub.durationInMonths} month${sub.durationInMonths > 1 ? 's' : ''}',
                    ),
                    pw.SizedBox(height: 8),
                    _buildLabelValue(
                      'Base Price',
                      _sanitize(
                        'Rs.${sub.baseMonthlyPrice.toStringAsFixed(0)}/month',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          _buildLabelValue('Valid From', dateFormat.format(sub.startDate)),
          pw.SizedBox(height: 8),
          _buildLabelValue('Valid Until', dateFormat.format(sub.endDate)),
        ],
      ),
    );
  }

  pw.Widget _buildPaymentSummary(Subscription sub, DateFormat dateFormat) {
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

          // Breakdown
          _buildAmountRow(
            'Gross Amount',
            _sanitize('Rs.${sub.grossAmount.toStringAsFixed(0)}'),
          ),
          if (sub.discountPercent > 0)
            _buildAmountRow(
              'Duration Discount (${sub.discountPercent.toStringAsFixed(0)}%)',
              _sanitize('-Rs.${sub.discountAmount.toStringAsFixed(0)}'),
              isDiscount: true,
            ),
          if (sub.couponDiscount != null && sub.couponDiscount! > 0)
            _buildAmountRow(
              'Coupon Discount (${sub.couponDiscount!.toStringAsFixed(0)}%)',
              _sanitize('-Rs.${sub.couponDiscountAmount.toStringAsFixed(0)}'),
              isDiscount: true,
            ),

          pw.SizedBox(height: 8),
          pw.Container(height: 1, color: PdfColors.green200),
          pw.SizedBox(height: 8),

          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Total Paid',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey800,
                ),
              ),
              pw.Text(
                _sanitize('Rs.${sub.finalAmount.toStringAsFixed(0)}'),
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green800,
                ),
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

  pw.Widget _buildAmountRow(
    String label,
    String value, {
    bool isDiscount = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: isDiscount ? PdfColors.green700 : PdfColors.grey800,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          'Thank you for choosing ${_CompanyInfo.name}!',
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue800,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'For support, contact us at ${_CompanyInfo.email} or ${_CompanyInfo.phone}',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          _CompanyInfo.website,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 20),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 8),
          child: pw.Text(
            'This is a computer generated invoice and does not require a signature.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey400),
            textAlign: pw.TextAlign.center,
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
          _sanitize(value),
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800,
          ),
        ),
      ],
    );
  }

  String _getPlanName(String planId) {
    final planNames = {
      'tier_99': 'Starter',
      'tier_149': 'Growth',
      'tier_199': 'Professional',
      'tier_299': 'Business',
      'tier_unlimited': 'Enterprise',
    };
    return planNames[planId] ?? 'Plan';
  }
}
