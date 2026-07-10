import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:unicons/unicons.dart';
import 'dart:io';

import '../../../core/di/injection_container.dart';
import '../../../data/services/invoice_pdf_service.dart';
import '../../../domain/entities/attendance.dart';
import '../../../domain/entities/invoice.dart';
import '../../../domain/entities/student_document.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/repositories/student_document_repository.dart';
import '../../../domain/usecases/approve_student_document.dart';
import '../cubit/student_details_cubit.dart';

/// Base collapsible section widget
class _CollapsibleSection extends StatefulWidget {
  const _CollapsibleSection({
    required this.title,
    required this.icon,
    required this.child,
    required this.itemCount,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final int itemCount;

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _controller;
  late Animation<double> _iconRotation;

  @override
  void initState() {
    super.initState();
    _isExpanded = true;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _iconRotation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (_isExpanded) _controller.value = 1;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() => _isExpanded = !_isExpanded);
              _isExpanded ? _controller.forward() : _controller.reverse();
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      widget.icon,
                      size: 20,
                      color: const Color(0xFF6366F1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                          ),
                        ),
                        if (widget.itemCount > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${widget.itemCount} ${widget.itemCount == 1 ? 'item' : 'items'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  RotationTransition(
                    turns: _iconRotation,
                    child: Icon(
                      UniconsLine.angle_down,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: widget.child,
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
//  PROFILE SECTION
// =============================================================================

class StudentProfileSection extends StatelessWidget {
  const StudentProfileSection({super.key, required this.student});

  final User student;

  @override
  Widget build(BuildContext context) {
    final fields = [
      if (student.name.isNotEmpty)
        (UniconsLine.user, 'Name', student.name),
      (UniconsLine.phone, 'Phone', student.phone),
      if (student.email?.isNotEmpty ?? false)
        (UniconsLine.envelope, 'Email', student.email!),
      if (student.examPreparingFor?.isNotEmpty ?? false)
        (UniconsLine.book_open, 'Preparing For', student.examPreparingFor!),
      if (student.address?.isNotEmpty ?? false)
        (UniconsLine.map_marker, 'Address', student.address!),
      if (student.gender?.isNotEmpty ?? false)
        (UniconsLine.users_alt, 'Gender', student.gender!),
    ];

    return _CollapsibleSection(
      title: 'Profile Information',
      icon: UniconsLine.user_circle,
      itemCount: fields.length,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          children: fields.map((field) {
            final isLast = field == fields.last;
            return _InfoRow(
              icon: field.$1,
              label: field.$2,
              value: field.$3,
              isLast: isLast,
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 18, color: Colors.grey.shade500),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!isLast)
            Divider(
              height: 1,
              thickness: 0.5,
              color: Colors.grey.shade200,
            ),
        ],
      ),
    );
  }
}

// =============================================================================
//  ATTENDANCE SECTION
// =============================================================================

class StudentAttendanceSection extends StatelessWidget {
  const StudentAttendanceSection({
    super.key,
    required this.todayAttendance,
    required this.attendanceHistory,
  });

  final Attendance? todayAttendance;
  final List<Attendance> attendanceHistory;

  @override
  Widget build(BuildContext context) {
    final totalDays = attendanceHistory.length;
    final rate = totalDays > 0 ? (totalDays / 30 * 100).clamp(0, 100) : 0.0;
    final isActive = todayAttendance?.checkOutTime == null &&
        todayAttendance?.checkInTime != null;

    return _CollapsibleSection(
      title: 'Attendance',
      icon: UniconsLine.calendar_alt,
      itemCount: totalDays,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          children: [
            // Stats
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: UniconsLine.clock,
                    label: 'Total Days',
                    value: '$totalDays',
                    color: const Color(0xFF6366F1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: UniconsLine.chart_line,
                    label: 'Rate',
                    value: '${rate.toStringAsFixed(0)}%',
                    color: const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Today's attendance
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF10B981).withValues(alpha: 0.1)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActive
                      ? const Color(0xFF10B981).withValues(alpha: 0.3)
                      : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isActive ? UniconsLine.check_circle : UniconsLine.clock,
                    color: isActive
                        ? const Color(0xFF10B981)
                        : Colors.grey.shade600,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Today',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          todayAttendance?.checkInTime != null
                              ? 'In: ${DateFormat('h:mm a').format(todayAttendance!.checkInTime!)}'
                              : 'Not checked in',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            UniconsLine.circle,
                            size: 8,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'ACTIVE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
//  INVOICES SECTION
// =============================================================================

class StudentInvoicesSection extends StatelessWidget {
  const StudentInvoicesSection({super.key, required this.invoices});

  final List<Invoice> invoices;

  @override
  Widget build(BuildContext context) {
    return _CollapsibleSection(
      title: 'Invoices & Payments',
      icon: UniconsLine.receipt,
      itemCount: invoices.length,
      child: invoices.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      UniconsLine.file_search_alt,
                      size: 40,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No invoices found',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: invoices
                    .take(5)
                    .map((inv) => _InvoiceItem(invoice: inv))
                    .toList(),
              ),
            ),
    );
  }
}

class _InvoiceItem extends StatelessWidget {
  const _InvoiceItem({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              UniconsLine.check,
              size: 18,
              color: Color(0xFF10B981),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invoice.invoiceNumber,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  invoice.billingMonth,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${invoice.amountPaid.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF10B981),
                ),
              ),
              const SizedBox(height: 4),
              InkWell(
                onTap: () => _downloadInvoice(context, invoice),
                child: Icon(
                  UniconsLine.download_alt,
                  size: 18,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _downloadInvoice(BuildContext context, Invoice invoice) async {
    // Capture render box BEFORE any async gap for iOS sharePositionOrigin
    final box = context.findRenderObject() as RenderBox?;
    final shareOrigin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : Rect.zero;

    // Show loading indicator
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Text('Generating invoice...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );
    }

    try {
      final pdfService = InvoicePdfService();
      final pdfFilePath = await pdfService.generatePdf(invoice);

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        final result = await OpenFilex.open(pdfFilePath);
        if (result.type != ResultType.done && context.mounted) {
          // Fallback to share if open fails
          await Share.shareXFiles(
            [XFile(pdfFilePath)],
            subject: 'Invoice ${invoice.invoiceNumber}',
            sharePositionOrigin: shareOrigin,
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// =============================================================================
//  DOCUMENTS SECTION
// =============================================================================

class StudentDocumentsSection extends StatelessWidget {
  const StudentDocumentsSection({
    super.key,
    required this.documents,
    required this.studentId,
    required this.libraryId,
  });

  final List<StudentDocument> documents;
  final String studentId;
  final String libraryId;

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<StudentDetailsCubit>();
    final canUpload = cubit.state.canUploadMore;

    return _CollapsibleSection(
      title: 'Documents',
      icon: UniconsLine.folder_open,
      itemCount: documents.length,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          children: [
            if (documents.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      UniconsLine.file_question,
                      size: 40,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No documents uploaded',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              )
            else
              ...documents.map(
                (doc) => _DocumentItem(
                  document: doc,
                  studentId: studentId,
                  libraryId: libraryId,
                ),
              ),
            if (canUpload) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: cubit.state.isUploading
                      ? null
                      : () => _pickDocument(context, cubit),
                  icon: cubit.state.isUploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(UniconsLine.upload, size: 18),
                  label: Text(
                    cubit.state.isUploading
                        ? 'Uploading...'
                        : 'Upload Document (${documents.length}/2)',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6366F1),
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickDocument(
    BuildContext context,
    StudentDetailsCubit cubit,
  ) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );

    if (result != null && result.files.single.path != null) {
      await cubit.uploadNewDocument(
        studentId: studentId,
        filePath: result.files.single.path!,
        fileName: result.files.single.name,
        libraryId: libraryId,
      );
    }
  }
}

class _DocumentItem extends StatelessWidget {
  const _DocumentItem({
    required this.document,
    required this.studentId,
    required this.libraryId,
  });

  final StudentDocument document;
  final String studentId;
  final String libraryId;

  @override
  Widget build(BuildContext context) {
    final isPdf = document.fileType == StudentDocumentType.pdf;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: document.isApproved
              ? Colors.green.shade200
              : document.isPending
                  ? Colors.orange.shade200
                  : Colors.red.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: document.isApproved
                  ? Colors.green.withValues(alpha: 0.1)
                  : document.isPending
                      ? Colors.orange.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isPdf ? UniconsLine.file_alt : UniconsLine.image,
              size: 18,
              color: document.isApproved
                  ? Colors.green
                  : document.isPending
                      ? Colors.orange
                      : Colors.red,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.fileName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  document.approvalStatus.displayName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: document.isApproved
                        ? Colors.green
                        : document.isPending
                            ? Colors.orange
                            : Colors.red,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(UniconsLine.ellipsis_v, size: 18, color: Colors.grey.shade600),
            onSelected: (value) {
              switch (value) {
                case 'view':
                  _viewDocument(context);
                  break;
                case 'share':
                  _shareDocument(context);
                  break;
                case 'approve':
                  _approveDocument(context);
                  break;
                case 'reject':
                  _rejectDocument(context);
                  break;
                case 'delete':
                  _deleteDocument(context);
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'view',
                child: Row(
                  children: [
                    Icon(UniconsLine.eye, size: 18, color: Colors.grey.shade700),
                    const SizedBox(width: 12),
                    const Text('View'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(UniconsLine.share_alt, size: 18, color: Colors.grey.shade700),
                    const SizedBox(width: 12),
                    const Text('Share'),
                  ],
                ),
              ),
              if (document.isPending) ...[
                const PopupMenuItem(
                  value: 'approve',
                  child: Row(
                    children: [
                      Icon(UniconsLine.check_circle, size: 18, color: Colors.green),
                      SizedBox(width: 12),
                      Text('Approve', style: TextStyle(color: Colors.green)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'reject',
                  child: Row(
                    children: [
                      Icon(UniconsLine.times_circle, size: 18, color: Colors.red),
                      SizedBox(width: 12),
                      Text('Reject', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(UniconsLine.trash_alt, size: 18, color: Colors.red.shade700),
                    const SizedBox(width: 12),
                    Text('Delete', style: TextStyle(color: Colors.red.shade700)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _viewDocument(BuildContext context) async {
    try {
      final response = await http.get(Uri.parse(document.downloadUrl));
      final tempDir = await getTemporaryDirectory();
      final ext = document.fileType == StudentDocumentType.pdf ? 'pdf' : 'jpg';
      final file = File('${tempDir.path}/doc_${document.id}.$ext');
      await file.writeAsBytes(response.bodyBytes);
      await OpenFilex.open(file.path);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open: $e')),
        );
      }
    }
  }

  Future<void> _shareDocument(BuildContext context) async {
    // Capture render box BEFORE any async gap for iOS sharePositionOrigin
    final box = context.findRenderObject() as RenderBox?;
    final shareOrigin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : Rect.zero;

    // Show loading indicator
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Text('Preparing document...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );
    }

    try {
      final response = await http.get(Uri.parse(document.downloadUrl));
      if (response.statusCode != 200) {
        throw Exception('Download failed (${response.statusCode})');
      }
      final tempDir = await getTemporaryDirectory();
      final ext = document.fileType == StudentDocumentType.pdf ? 'pdf' : 'jpg';
      final file = File('${tempDir.path}/doc_${document.id}.$ext');
      await file.writeAsBytes(response.bodyBytes);

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      await Share.shareXFiles(
        [XFile(file.path)],
        text: document.fileName,
        sharePositionOrigin: shareOrigin,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _approveDocument(BuildContext context) async {
    try {
      final approveUseCase = sl<ApproveStudentDocument>();
      final authRepo = sl<AuthRepository>();
      final userResult = await authRepo.getCurrentUser();
      final ownerId = userResult.fold((_) => null, (user) => user?.id);
      if (ownerId == null) throw Exception('Failed to get current user');

      final result = await approveUseCase(ApproveStudentDocumentParams(
        documentId: document.id,
        approvedBy: ownerId,
      ));

      result.fold(
        (failure) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(failure.message ?? 'Failed'), backgroundColor: Colors.red),
            );
          }
        },
        (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Document approved'), backgroundColor: Colors.green),
            );
            context.read<StudentDetailsCubit>().refresh(
              studentId: studentId,
              libraryId: libraryId,
            );
          }
        },
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rejectDocument(BuildContext context) async {
    try {
      final repository = sl<StudentDocumentRepository>();
      final authRepo = sl<AuthRepository>();
      final userResult = await authRepo.getCurrentUser();
      final ownerId = userResult.fold((_) => null, (user) => user?.id);
      if (ownerId == null) throw Exception('Failed to get current user');

      final result = await repository.rejectDocument(
        documentId: document.id,
        rejectedBy: ownerId,
      );

      result.fold(
        (failure) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(failure.message ?? 'Failed'), backgroundColor: Colors.red),
            );
          }
        },
        (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Document rejected'), backgroundColor: Colors.orange),
            );
            context.read<StudentDetailsCubit>().refresh(
              studentId: studentId,
              libraryId: libraryId,
            );
          }
        },
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteDocument(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: const Text('Are you sure you want to delete this document?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await context.read<StudentDetailsCubit>().deleteDocument(
        document.id,
        studentId,
        libraryId,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document deleted'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
