import 'package:dartz/dartz.dart' hide State;
import 'package:material_ui/material_ui.dart';
import 'package:pg_manager/presentation/core/app_ui_constants.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/core/failure.dart';
import '../../../domain/entities/notice.dart';
import '../../../domain/entities/library.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/repositories/library_repository.dart';
import '../../../domain/repositories/user_repository.dart';
import '../../../domain/repositories/notice_repository.dart';
import '../widgets/notice_details/notice_details_parts.dart';
import '../widgets/pdf_viewer_screen.dart';

/// Notice details, shared by students and the owner.
class StudentNoticeDetailsScreen extends StatefulWidget {
  const StudentNoticeDetailsScreen({
    super.key,
    required this.notice,
    required this.studentId,
    this.studentName,
    this.isOwnerView = false,
    this.onDelete,
  });

  final Notice notice;
  final String studentId;
  final String? studentName;
  final bool isOwnerView;
  final VoidCallback? onDelete;

  @override
  State<StudentNoticeDetailsScreen> createState() =>
      _StudentNoticeDetailsScreenState();
}

class _StudentNoticeDetailsScreenState
    extends State<StudentNoticeDetailsScreen> {
  Library? _library;
  String? _ownerName;

  @override
  void initState() {
    super.initState();
    _loadLibraryInfo();
    if (!widget.isOwnerView) _incrementViewCount();
  }

  Future<void> _incrementViewCount() async {
    try {
      final noticeRepo = sl<NoticeRepository>();
      await noticeRepo.incrementViewCount(
        noticeId: widget.notice.id,
        userId: widget.studentId,
      );
    } catch (e) {
      // Silent fail - view count is not critical
    }
  }

  Future<void> _loadLibraryInfo() async {
    try {
      final libraryRepo = sl<LibraryRepository>();
      final userRepo = sl<UserRepository>();

      // Fetch library + owner in parallel instead of sequentially
      final results = await Future.wait([
        libraryRepo.getLibraryById(widget.notice.libraryId),
        userRepo.getUserById(widget.notice.ownerId),
      ]);

      final libResult = results[0] as Either<Failure, Library?>;
      libResult.fold((_) {}, (lib) {
        if (lib != null && mounted) {
          setState(() {
            _library = lib;
          });
        }
      });

      final userResult = results[1] as Either<Failure, User?>;
      userResult.fold((_) {}, (user) {
        if (user != null && mounted) {
          setState(() {
            _ownerName = user.name;
          });
        }
      });
    } catch (e) {
      // Silent fail - library info is not critical
    }
  }

  String _getDisplayName() {
    if (_library != null && _library!.name.isNotEmpty) {
      return _library!.name;
    }
    if (_ownerName != null && _ownerName!.isNotEmpty) {
      return _ownerName!;
    }
    return 'PG Notice';
  }

  @override
  Widget build(BuildContext context) {
    final notice = widget.notice;
    final images = notice.attachments
        .where((a) => a.fileType == AttachmentType.image)
        .map((a) => a.url)
        .toList();
    final pdfs = notice.attachments
        .where((a) => a.fileType == AttachmentType.pdf)
        .toList();
    final hasFiles = pdfs.isNotEmpty || notice.externalLinks.isNotEmpty;

    return Scaffold(
      backgroundColor: AppUIConstants.background,
      appBar: AppBar(
        backgroundColor: AppUIConstants.surface,
        foregroundColor: AppUIConstants.textPrimary,
        centerTitle: false,
        title: const Text(
          'Notice',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (widget.isOwnerView && widget.onDelete != null)
            PopupMenuButton<void>(
              icon: const Icon(Icons.more_vert_rounded),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
              ),
              itemBuilder: (_) => [
                PopupMenuItem(
                  onTap: widget.onDelete,
                  child: const Row(
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: AppUIConstants.error,
                      ),
                      SizedBox(width: AppUIConstants.spacingMd),
                      Text(
                        'Delete notice',
                        style: TextStyle(color: AppUIConstants.error),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(
          top: AppUIConstants.spacingLg,
          bottom: AppUIConstants.spacing2Xl,
        ),
        children: [
          NoticeSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NoticeAuthorHeader(
                  name: _getDisplayName(),
                  library: _library,
                  postedAt:
                      notice.publishedAt ??
                      notice.scheduledFor ??
                      notice.createdAt,
                ),
                const SizedBox(height: AppUIConstants.spacingLg),
                SelectableText(
                  notice.description,
                  style: AppUIConstants.bodyLg.copyWith(
                    fontWeight: FontWeight.w400,
                    height: 1.6,
                  ),
                ),
                if (images.isNotEmpty) ...[
                  const SizedBox(height: AppUIConstants.spacingLg),
                  NoticeImageGallery(urls: images),
                ],
              ],
            ),
          ),
          if (hasFiles)
            NoticeSectionCard(
              title: 'Attachments',
              child: Column(
                children: [
                  ...pdfs.map(
                    (pdf) => NoticeFileTile(
                      icon: Icons.picture_as_pdf_outlined,
                      color: AppUIConstants.error,
                      title: pdf.fileName,
                      subtitle: pdf.fileSizeFormatted,
                      onTap: () => _openPdf(pdf),
                    ),
                  ),
                  ...notice.externalLinks.map(
                    (link) => NoticeFileTile(
                      icon: Icons.link_rounded,
                      color: AppUIConstants.accent,
                      title: link.title,
                      subtitle: Uri.tryParse(link.url)?.host,
                      trailing: Icons.open_in_new_rounded,
                      onTap: () => _launchUrl(link.url),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _openPdf(NoticeAttachment pdf) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PdfViewerScreen(pdfUrl: pdf.url, fileName: pdf.fileName),
      ),
    );
  }

  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
