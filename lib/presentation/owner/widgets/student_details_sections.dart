import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:unicons/unicons.dart';
import 'dart:io';

import '../../../core/di/injection_container.dart';
import '../../../data/services/invoice_pdf_service.dart';
import '../../../domain/entities/invoice.dart';
import '../../../domain/entities/student_document.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/repositories/student_document_repository.dart';
import '../../../domain/usecases/approve_student_document.dart';
import '../cubit/student_details_cubit.dart';
import '../../core/app_ui_constants.dart';

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
    _iconRotation = Tween<double>(
      begin: 0,
      end: 0.5,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
        color: AppUIConstants.surfaceMuted.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
        border: Border.all(color: AppUIConstants.border),
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
                      color: AppUIConstants.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      widget.icon,
                      size: 20,
                      color: AppUIConstants.primaryLight,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title, style: AppUIConstants.headingSm),
                        if (widget.itemCount > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${widget.itemCount} ${widget.itemCount == 1 ? 'item' : 'items'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppUIConstants.textSecondary,
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
                      color: AppUIConstants.textSecondary,
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
      if (student.name.isNotEmpty) (UniconsLine.user, 'Name', student.name),
      (UniconsLine.phone, 'Phone', student.phone),
      if (student.email?.isNotEmpty ?? false)
        (UniconsLine.envelope, 'Email', student.email!),
      if (student.address?.isNotEmpty ?? false)
        (UniconsLine.map_marker, 'Address', student.address!),
      if (student.gender?.isNotEmpty ?? false)
        (UniconsLine.users_alt, 'Gender', student.gender!),
    ];

    return _CollapsibleSection(
      title: 'Contact & Profile',
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
                Icon(icon, size: 18, color: AppUIConstants.textTertiary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppUIConstants.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppUIConstants.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!isLast)
            Divider(height: 1, thickness: 0.5, color: AppUIConstants.border),
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
      title: 'Rent & Payments',
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
                      color: AppUIConstants.textTertiary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No rent payments yet',
                      style: TextStyle(color: AppUIConstants.textSecondary),
                    ),
                  ],
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  for (var i = 0; i < invoices.take(5).length; i++)
                    _InvoiceItem(
                      invoice: invoices[i],
                      isLast: i == invoices.take(5).length - 1,
                    ),
                ],
              ),
            ),
    );
  }
}

class _InvoiceItem extends StatelessWidget {
  const _InvoiceItem({required this.invoice, this.isLast = false});

  final Invoice invoice;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline rail
          SizedBox(
            width: 22,
            child: Column(
              children: [
                const SizedBox(height: 16),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppUIConstants.success,
                    boxShadow: [
                      BoxShadow(
                        color: AppUIConstants.success.withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: AppUIConstants.border),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppUIConstants.surface,
                borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
                border: Border.all(color: AppUIConstants.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invoice.invoiceNumber,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppUIConstants.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          invoice.billingMonth,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppUIConstants.textSecondary,
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
                          color: AppUIConstants.success,
                        ),
                      ),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () => _downloadInvoice(context, invoice),
                        child: const Icon(
                          UniconsLine.download_alt,
                          size: 18,
                          color: AppUIConstants.primaryLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
            backgroundColor: AppUIConstants.error,
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
                      color: AppUIConstants.textTertiary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No documents uploaded',
                      style: TextStyle(color: AppUIConstants.textSecondary),
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
                    foregroundColor: AppUIConstants.primaryLight,
                    side: BorderSide(color: AppUIConstants.border),
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
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    final path = file?.path;

    if (file != null && path != null) {
      await cubit.uploadNewDocument(
        studentId: studentId,
        filePath: path,
        fileName: file.name,
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
        color: AppUIConstants.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: document.isApproved
              ? AppUIConstants.success.withValues(alpha: 0.4)
              : document.isPending
              ? AppUIConstants.primaryLight.withValues(alpha: 0.4)
              : AppUIConstants.error.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: document.isApproved
                  ? AppUIConstants.success.withValues(alpha: 0.1)
                  : document.isPending
                  ? AppUIConstants.primaryLight.withValues(alpha: 0.1)
                  : AppUIConstants.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isPdf ? UniconsLine.file_alt : UniconsLine.image,
              size: 18,
              color: document.isApproved
                  ? AppUIConstants.success
                  : document.isPending
                  ? AppUIConstants.primaryLight
                  : AppUIConstants.error,
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
                    color: AppUIConstants.textPrimary,
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
                        ? AppUIConstants.success
                        : document.isPending
                        ? AppUIConstants.primaryLight
                        : AppUIConstants.error,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            color: AppUIConstants.surfaceMuted,
            icon: Icon(
              UniconsLine.ellipsis_v,
              size: 18,
              color: AppUIConstants.textSecondary,
            ),
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
                    Icon(
                      UniconsLine.eye,
                      size: 18,
                      color: AppUIConstants.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'View',
                      style: TextStyle(color: AppUIConstants.textPrimary),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(
                      UniconsLine.share_alt,
                      size: 18,
                      color: AppUIConstants.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Share',
                      style: TextStyle(color: AppUIConstants.textPrimary),
                    ),
                  ],
                ),
              ),
              if (document.isPending) ...[
                const PopupMenuItem(
                  value: 'approve',
                  child: Row(
                    children: [
                      Icon(
                        UniconsLine.check_circle,
                        size: 18,
                        color: AppUIConstants.success,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Approve',
                        style: TextStyle(color: AppUIConstants.success),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'reject',
                  child: Row(
                    children: [
                      Icon(
                        UniconsLine.times_circle,
                        size: 18,
                        color: AppUIConstants.error,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Reject',
                        style: TextStyle(color: AppUIConstants.error),
                      ),
                    ],
                  ),
                ),
              ],
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      UniconsLine.trash_alt,
                      size: 18,
                      color: AppUIConstants.error,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Delete',
                      style: TextStyle(color: AppUIConstants.error),
                    ),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to open: $e')));
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
            backgroundColor: AppUIConstants.error,
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
      final ownerId = userResult.fold(
        (_) => null,
        (user) => user?.ownerAccountId,
      );
      if (ownerId == null) throw Exception('Failed to get current user');

      final result = await approveUseCase(
        ApproveStudentDocumentParams(
          documentId: document.id,
          approvedBy: ownerId,
        ),
      );

      result.fold(
        (failure) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(failure.message ?? 'Failed'),
                backgroundColor: AppUIConstants.error,
              ),
            );
          }
        },
        (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Document approved'),
                backgroundColor: AppUIConstants.success,
              ),
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
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: AppUIConstants.error,
          ),
        );
      }
    }
  }

  Future<void> _rejectDocument(BuildContext context) async {
    try {
      final repository = sl<StudentDocumentRepository>();
      final authRepo = sl<AuthRepository>();
      final userResult = await authRepo.getCurrentUser();
      final ownerId = userResult.fold(
        (_) => null,
        (user) => user?.ownerAccountId,
      );
      if (ownerId == null) throw Exception('Failed to get current user');

      final result = await repository.rejectDocument(
        documentId: document.id,
        rejectedBy: ownerId,
      );

      result.fold(
        (failure) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(failure.message ?? 'Failed'),
                backgroundColor: AppUIConstants.error,
              ),
            );
          }
        },
        (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Document rejected'),
                backgroundColor: AppUIConstants.primary,
              ),
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
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: AppUIConstants.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteDocument(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppUIConstants.surface,
        title: const Text('Delete Document', style: AppUIConstants.headingMd),
        content: const Text(
          'Are you sure you want to delete this document?',
          style: AppUIConstants.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppUIConstants.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppUIConstants.error),
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
          const SnackBar(
            content: Text('Document deleted'),
            backgroundColor: AppUIConstants.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: AppUIConstants.error,
          ),
        );
      }
    }
  }
}
