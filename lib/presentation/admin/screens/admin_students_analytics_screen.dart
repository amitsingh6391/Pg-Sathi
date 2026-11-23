import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/di/injection_container.dart';
import '../../../domain/entities/membership.dart';
import '../../../domain/entities/library.dart';
import '../../../domain/repositories/membership_repository.dart';
import '../../../domain/repositories/library_repository.dart';
import '../../core/app_ui_constants.dart';
import '../../core/widgets/premium_kit.dart';
import '../utils/admin_contact_helper.dart';

/// Admin screen showing all students grouped by library.
/// Modern UI with bulk WhatsApp messaging and message customization.
class AdminStudentsAnalyticsScreen extends StatefulWidget {
  const AdminStudentsAnalyticsScreen({super.key});

  @override
  State<AdminStudentsAnalyticsScreen> createState() =>
      _AdminStudentsAnalyticsScreenState();
}

class _AdminStudentsAnalyticsScreenState
    extends State<AdminStudentsAnalyticsScreen> {
  Map<String, Library> _libraryCache = {};
  Map<String, int> _studentCountsByLibrary = {};
  final Map<String, List<Membership>> _studentsByLibrary = {};
  final Set<String> _loadingStudentsForLibraries = {};
  final Set<String> _expandedLibraries = {};
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  // Bulk messaging state
  bool _isSendingBulk = false;
  int _bulkProgress = 0;
  int _bulkTotal = 0;
  String? _customMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final membershipRepo = sl<MembershipRepository>();
      final libraryRepo = sl<LibraryRepository>();

      // 2 bulk reads total (libraries + all active memberships) instead of
      // 1 + N individual per-library membership queries.
      // For 30 libraries this saves ~29 Firestore reads.
      final results = await Future.wait([
        libraryRepo.getAllCompletedLibraries(),
        membershipRepo.getActiveMembershipCountsByLibrary(),
      ]);

      final librariesResult = results[0] as dynamic;
      final countsResult = results[1] as dynamic;

      String? errorMsg;
      List<Library>? libraries;
      Map<String, int>? membershipCounts;

      librariesResult.fold(
        (failure) => errorMsg = failure.message ?? 'Failed to load PGs',
        (data) => libraries = data as List<Library>,
      );
      countsResult.fold(
        (failure) =>
            errorMsg ??= failure.message ?? 'Failed to load stay counts',
        (data) => membershipCounts = data as Map<String, int>,
      );

      if (libraries == null) {
        if (mounted) {
          setState(() {
            _error = errorMsg ?? 'Failed to load data';
            _isLoading = false;
          });
        }
        return;
      }

      if (libraries!.isEmpty) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      final libraryMap = <String, Library>{};
      for (final library in libraries!) {
        libraryMap[library.id] = library;
      }

      // Use bulk counts or fall back to empty map
      final countsMap = <String, int>{};
      for (final library in libraries!) {
        countsMap[library.id] = membershipCounts?[library.id] ?? 0;
      }

      if (mounted) {
        setState(() {
          _libraryCache = libraryMap;
          _studentCountsByLibrary = countsMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadStudentsForLibrary(String libraryId) async {
    if (_studentsByLibrary.containsKey(libraryId) ||
        _loadingStudentsForLibraries.contains(libraryId)) {
      return;
    }

    if (!mounted) return;

    setState(() {
      _loadingStudentsForLibraries.add(libraryId);
    });

    try {
      final membershipRepo = sl<MembershipRepository>();
      const timeoutDuration = Duration(seconds: 5);

      final result = await membershipRepo
          .getMembershipsByLibraryId(libraryId)
          .timeout(timeoutDuration);

      if (mounted) {
        result.fold(
          (failure) {
            debugPrint('Failed to load tenants: ${failure.message}');
            setState(() {
              _loadingStudentsForLibraries.remove(libraryId);
              _studentsByLibrary[libraryId] = [];
            });
          },
          (memberships) {
            setState(() {
              _studentsByLibrary[libraryId] = memberships;
              _loadingStudentsForLibraries.remove(libraryId);
            });
          },
        );
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Error loading tenants: $e');
        setState(() {
          _loadingStudentsForLibraries.remove(libraryId);
          _studentsByLibrary[libraryId] = [];
        });
      }
    }
  }

  void _toggleLibraryExpansion(String libraryId) {
    setState(() {
      if (_expandedLibraries.contains(libraryId)) {
        _expandedLibraries.remove(libraryId);
      } else {
        _expandedLibraries.add(libraryId);
        _loadStudentsForLibrary(libraryId);
      }
    });
  }

  List<MapEntry<String, Library>> get _filteredLibraries {
    if (_searchQuery.isEmpty) {
      return _libraryCache.entries.toList();
    }

    final query = _searchQuery.toLowerCase();
    return _libraryCache.entries.where((entry) {
      final library = entry.value;
      final students = _studentsByLibrary[entry.key];
      final areaMatch =
          library.area != null && library.area!.toLowerCase().contains(query);

      if (students == null) {
        return library.name.toLowerCase().contains(query) || areaMatch;
      }

      return library.name.toLowerCase().contains(query) ||
          areaMatch ||
          students.any((s) {
            final nameMatch =
                s.studentName != null &&
                s.studentName!.toLowerCase().contains(query);
            return nameMatch || s.phoneNumber.toLowerCase().contains(query);
          });
    }).toList();
  }

  List<Membership> get _allStudents {
    final students = <Membership>[];
    for (final entry in _studentsByLibrary.entries) {
      students.addAll(entry.value);
    }
    return students;
  }

  Future<void> _showMessageCustomizationDialog() async {
    final controller = TextEditingController(
      text:
          _customMessage ??
          '''Hi {name}! 👋

Your PG *{library}* uses our official app to manage stays and bed bookings.

📱 *Download the app now:*
• Android: ${AppConstants.playStoreUrl}
• iOS: ${AppConstants.appStoreUrl}

Manage your stay, book beds, and make payments - all in one place!

Thank you! 📚''',
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit_note, color: AppUIConstants.primaryLight),
            SizedBox(width: 8),
            Text('Customize Message'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Available placeholders: {name}, {library} (PG name)',
                style: AppUIConstants.caption.copyWith(
                  color: AppUIConstants.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 12,
                decoration: InputDecoration(
                  hintText: 'Enter your message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: AppUIConstants.surfaceMuted,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppUIConstants.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _customMessage = result;
      });
    }
  }

  Future<void> _sendBulkWhatsApp() async {
    final allStudents = _allStudents;
    if (allStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No residents found'),
          backgroundColor: AppUIConstants.warning,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send WhatsApp to All Residents?'),
        content: Text(
          'This will send WhatsApp messages to ${allStudents.length} residents one by one. You\'ll need to confirm each message in WhatsApp.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppUIConstants.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Start Sending'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isSendingBulk = true;
      _bulkProgress = 0;
      _bulkTotal = allStudents.length;
    });

    for (var i = 0; i < allStudents.length; i++) {
      if (!mounted) break;

      final student = allStudents[i];
      final library = _libraryCache[student.libraryId];

      if (library == null) continue;

      final message =
          _customMessage ??
          AdminContactHelper.generateAppDownloadMessage(
            studentName: student.studentName ?? 'Student',
            libraryName: library.name,
          );

      // Replace placeholders
      final processedMessage = message
          .replaceAll('{name}', student.studentName ?? 'Student')
          .replaceAll('{library}', library.name);

      await AdminContactHelper.sendWhatsApp(
        phone: student.phoneNumber,
        message: processedMessage,
      );

      // Small delay between messages
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        setState(() {
          _bulkProgress = i + 1;
        });
      }
    }

    if (mounted) {
      setState(() {
        _isSendingBulk = false;
        _bulkProgress = 0;
        _bulkTotal = 0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sent WhatsApp to $_bulkTotal residents'),
          backgroundColor: AppUIConstants.success,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      appBar: AppBar(
        title: const Text(
          'Residents Management',
          style: AppUIConstants.headingSm,
        ),
        backgroundColor: AppUIConstants.background,
        foregroundColor: AppUIConstants.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: _isSendingBulk
          ? null
          : FloatingActionButton.extended(
              onPressed: _sendBulkWhatsApp,
              backgroundColor: AppUIConstants.primary,
              icon: const Icon(Icons.send_rounded, color: Colors.white),
              label: const Text(
                'Message all residents',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
      body: _isLoading
          ? const _StudentsSkeleton()
          : _error != null
          ? _buildErrorView()
          : _buildContent(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppUIConstants.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: AppUIConstants.textSecondary,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Failed to load data',
              style: AppUIConstants.bodyMd,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppUIConstants.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    final totalResidents = _studentCountsByLibrary.values.fold<int>(
      0,
      (sum, count) => sum + count,
    );
    final avg = _libraryCache.isEmpty
        ? 0
        : (totalResidents / _libraryCache.length).round();

    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
      borderSide: BorderSide(color: c),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hero KPI
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppUIConstants.surface,
            border: Border.all(color: AppUIConstants.border),
            borderRadius: BorderRadius.circular(AppUIConstants.radiusXl),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ACTIVE RESIDENTS',
                style: TextStyle(
                  color: AppUIConstants.textSecondary,
                  fontSize: 11.5,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$totalResidents',
                style: const TextStyle(
                  color: AppUIConstants.textPrimary,
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'across ${_libraryCache.length} PGs',
                style: const TextStyle(
                  color: AppUIConstants.textSecondary,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: PremiumStatTile(
                icon: Icons.apartment_rounded,
                label: 'PGs',
                value: '${_libraryCache.length}',
                color: AppUIConstants.primaryLight,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PremiumStatTile(
                icon: Icons.groups_rounded,
                label: 'Avg / PG',
                value: '$avg',
                color: AppUIConstants.primaryLight,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PremiumStatTile(
                icon: Icons.mark_chat_read_rounded,
                label: 'Loaded',
                value: '${_allStudents.length}',
                color: AppUIConstants.primaryLight,
              ),
            ),
          ],
        ),
        const PremiumSectionHeader('Search & messaging'),
        TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value),
          style: AppUIConstants.bodyMd,
          cursorColor: AppUIConstants.primaryLight,
          decoration: InputDecoration(
            hintText: 'Search PGs or residents...',
            hintStyle: AppUIConstants.bodyMd.copyWith(
              color: AppUIConstants.textTertiary,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppUIConstants.textTertiary,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppUIConstants.textSecondary,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: border(AppUIConstants.border),
            enabledBorder: border(AppUIConstants.border),
            focusedBorder: border(AppUIConstants.primaryLight),
            filled: true,
            fillColor: AppUIConstants.surface,
          ),
        ),
        const SizedBox(height: 12),
        PremiumCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          onTap: _showMessageCustomizationDialog,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppUIConstants.primarySoft,
                  borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  size: 18,
                  color: AppUIConstants.primaryLight,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _customMessage != null
                          ? 'Custom message set'
                          : 'Customize WhatsApp message',
                      style: AppUIConstants.bodyMd.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _customMessage != null
                          ? 'Tap to edit'
                          : 'Using the default app download message',
                      style: AppUIConstants.caption,
                    ),
                  ],
                ),
              ),
              if (_customMessage != null)
                const PremiumStatusPill(
                  'Custom',
                  color: AppUIConstants.primaryLight,
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppUIConstants.textTertiary,
                ),
            ],
          ),
        ),
        if (_isSendingBulk) ...[
          const SizedBox(height: 12),
          PremiumCard(
            child: Column(
              children: [
                Row(
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppUIConstants.primaryLight,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Sending WhatsApp messages...',
                        style: AppUIConstants.bodyMd.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '$_bulkProgress/$_bulkTotal',
                      style: AppUIConstants.bodyMd.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppUIConstants.primaryLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(
                    AppUIConstants.radiusFull,
                  ),
                  child: LinearProgressIndicator(
                    value: _bulkTotal > 0 ? _bulkProgress / _bulkTotal : 0,
                    minHeight: 6,
                    backgroundColor: AppUIConstants.surfaceMuted,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppUIConstants.primaryLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        PremiumSectionHeader(_searchQuery.isEmpty ? 'PGs' : 'Results'),
      ],
    );
  }

  Widget _buildContent() {
    final filteredLibraries = _filteredLibraries;
    final maxCount = _studentCountsByLibrary.values.fold<int>(
      0,
      (m, c) => c > m ? c : m,
    );

    return RefreshIndicator(
      color: AppUIConstants.primaryLight,
      backgroundColor: AppUIConstants.surface,
      onRefresh: _loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: [
          _buildHeaderSection(),
          if (filteredLibraries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: const BoxDecoration(
                        color: AppUIConstants.surfaceMuted,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.search_off_rounded,
                        size: 34,
                        color: AppUIConstants.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _searchQuery.isEmpty
                          ? 'No PGs found'
                          : 'No results found',
                      style: AppUIConstants.bodyLg,
                    ),
                    if (_searchQuery.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Try a different PG, resident or phone',
                          style: AppUIConstants.bodySm,
                        ),
                      ),
                  ],
                ),
              ),
            )
          else
            for (final entry in filteredLibraries)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _LibraryCard(
                  library: entry.value,
                  studentCount: _studentCountsByLibrary[entry.key] ?? 0,
                  maxCount: maxCount,
                  students: _studentsByLibrary[entry.key],
                  isLoading: _loadingStudentsForLibraries.contains(entry.key),
                  isExpanded: _expandedLibraries.contains(entry.key),
                  searchQuery: _searchQuery,
                  customMessage: _customMessage,
                  onExpand: () => _toggleLibraryExpansion(entry.key),
                  onSendAll: () => _sendWhatsAppToLibrary(
                    entry.key,
                    entry.value,
                    _studentsByLibrary[entry.key] ?? [],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _sendWhatsAppToLibrary(
    String libraryId,
    Library library,
    List<Membership> students,
  ) async {
    if (students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No residents in this PG'),
          backgroundColor: AppUIConstants.warning,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send WhatsApp to All Residents?'),
        content: Text(
          'This will send WhatsApp messages to ${students.length} residents in ${library.name} one by one.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppUIConstants.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    for (var i = 0; i < students.length; i++) {
      if (!mounted) break;

      final student = students[i];
      final message =
          _customMessage ??
          AdminContactHelper.generateAppDownloadMessage(
            studentName: student.studentName ?? 'Student',
            libraryName: library.name,
          );

      final processedMessage = message
          .replaceAll('{name}', student.studentName ?? 'Student')
          .replaceAll('{library}', library.name);

      await AdminContactHelper.sendWhatsApp(
        phone: student.phoneNumber,
        message: processedMessage,
      );

      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sent WhatsApp to ${students.length} residents'),
          backgroundColor: AppUIConstants.success,
        ),
      );
    }
  }
}

class _StudentsSkeleton extends StatefulWidget {
  const _StudentsSkeleton();

  @override
  State<_StudentsSkeleton> createState() => _StudentsSkeletonState();
}

class _StudentsSkeletonState extends State<_StudentsSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _bone(double h) => Container(
    height: h,
    decoration: BoxDecoration(
      color: AppUIConstants.surfaceMuted,
      borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_c),
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _bone(120),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _bone(96)),
              const SizedBox(width: 12),
              Expanded(child: _bone(96)),
              const SizedBox(width: 12),
              Expanded(child: _bone(96)),
            ],
          ),
          const SizedBox(height: 24),
          _bone(52),
          const SizedBox(height: 12),
          _bone(72),
          const SizedBox(height: 12),
          _bone(72),
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.color,
    required this.onTap,
    this.tooltip,
    this.size = 18,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: AppUIConstants.surfaceMuted,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(
              icon,
              color: color == AppUIConstants.error
                  ? AppUIConstants.error
                  : AppUIConstants.primaryLight,
              size: size,
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryCard extends StatelessWidget {
  const _LibraryCard({
    required this.library,
    required this.studentCount,
    this.maxCount = 0,
    this.students,
    required this.isLoading,
    required this.isExpanded,
    this.searchQuery = '',
    this.customMessage,
    required this.onExpand,
    required this.onSendAll,
  });

  final Library library;
  final int studentCount;
  final int maxCount;
  final List<Membership>? students;
  final bool isLoading;
  final bool isExpanded;
  final String searchQuery;
  final String? customMessage;
  final VoidCallback onExpand;
  final VoidCallback onSendAll;

  Future<void> _callOwner(BuildContext context) async {
    if (library.ownerPhone == null || library.ownerPhone!.isEmpty) {
      return;
    }

    final success = await AdminContactHelper.callOwner(library.ownerPhone!);

    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open phone dialer'),
          backgroundColor: AppUIConstants.error,
        ),
      );
    }
  }

  List<Membership> get _filteredStudents {
    if (students == null) return [];
    if (searchQuery.isEmpty) return students!;

    final query = searchQuery.toLowerCase();
    return students!.where((s) {
      return s.studentName?.toLowerCase().contains(query) ??
          false || s.phoneNumber.toLowerCase().contains(query);
    }).toList();
  }

  Widget _panelMessage(String text) => Padding(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: Text(
        text,
        style: AppUIConstants.bodySm.copyWith(
          color: AppUIConstants.textTertiary,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final filteredStudents = _filteredStudents;
    final hasPhone =
        library.ownerPhone != null && library.ownerPhone!.isNotEmpty;

    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: onExpand,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppUIConstants.primarySoft,
                          borderRadius: BorderRadius.circular(
                            AppUIConstants.radiusSm,
                          ),
                        ),
                        child: const Icon(
                          Icons.apartment_rounded,
                          color: AppUIConstants.primaryLight,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              library.name,
                              style: AppUIConstants.bodyLg.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (library.area != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_rounded,
                                    size: 12,
                                    color: AppUIConstants.textTertiary,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      library.area!,
                                      style: AppUIConstants.caption,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (hasPhone) ...[
                        _IconAction(
                          icon: Icons.phone_rounded,
                          color: AppUIConstants.primaryLight,
                          tooltip: 'Call owner',
                          onTap: () => _callOwner(context),
                        ),
                        const SizedBox(width: 8),
                      ],
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppUIConstants.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        '$studentCount',
                        style: AppUIConstants.statValue.copyWith(
                          color: AppUIConstants.primaryLight,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('residents', style: AppUIConstants.caption),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(
                      AppUIConstants.radiusFull,
                    ),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(
                        begin: 0,
                        end: maxCount > 0 ? studentCount / maxCount : 0,
                      ),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, _) => LinearProgressIndicator(
                        value: v,
                        minHeight: 5,
                        backgroundColor: AppUIConstants.surfaceMuted,
                        valueColor: const AlwaysStoppedAnimation(
                          AppUIConstants.primaryLight,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: !isExpanded
                ? const SizedBox(width: double.infinity)
                : Column(
                    children: [
                      const Divider(height: 1, color: AppUIConstants.divider),
                      if (isLoading)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppUIConstants.primaryLight,
                            ),
                          ),
                        )
                      else if (students == null)
                        _panelMessage('Tap to load residents')
                      else if (filteredStudents.isEmpty)
                        _panelMessage('No residents found')
                      else ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: onSendAll,
                              icon: const Icon(Icons.send_rounded, size: 18),
                              label: Text(
                                'Message all (${filteredStudents.length})',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppUIConstants.primaryLight,
                                side: const BorderSide(
                                  color: AppUIConstants.primaryLight,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                        ...filteredStudents.map(
                          (membership) => _StudentCard(
                            membership: membership,
                            libraryName: library.name,
                            customMessage: customMessage,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({
    required this.membership,
    required this.libraryName,
    this.customMessage,
  });

  final Membership membership;
  final String libraryName;
  final String? customMessage;

  Future<void> _sendWhatsApp(BuildContext context) async {
    final message =
        customMessage ??
        AdminContactHelper.generateAppDownloadMessage(
          studentName: membership.studentName ?? 'Student',
          libraryName: libraryName,
        );

    final processedMessage = message
        .replaceAll('{name}', membership.studentName ?? 'Student')
        .replaceAll('{library}', libraryName);

    final success = await AdminContactHelper.sendWhatsApp(
      phone: membership.phoneNumber,
      message: processedMessage,
    );

    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open WhatsApp'),
          backgroundColor: AppUIConstants.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = membership.studentName;
    final initial = (name != null && name.isNotEmpty)
        ? name[0].toUpperCase()
        : '?';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppUIConstants.divider)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppUIConstants.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: Text(
              initial,
              style: const TextStyle(
                color: AppUIConstants.primaryLight,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name ?? 'Unknown Resident',
                  style: AppUIConstants.bodyMd.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  membership.phoneNumber,
                  style: AppUIConstants.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _StatusChip(status: membership.status),
          const SizedBox(width: 8),
          _IconAction(
            icon: Icons.send_rounded,
            color: AppUIConstants.primaryLight,
            size: 16,
            tooltip: 'Send WhatsApp',
            onTap: () => _sendWhatsApp(context),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final MembershipStatus status;

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status) {
      case MembershipStatus.active:
        color = AppUIConstants.success;
        label = 'Active';
      case MembershipStatus.pendingPayment:
        color = AppUIConstants.warning;
        label = 'Pending';
      case MembershipStatus.pendingApproval:
        color = AppUIConstants.warning;
        label = 'Requested';
      case MembershipStatus.expired:
        color = AppUIConstants.textTertiary;
        label = 'Expired';
      case MembershipStatus.cancelled:
        color = AppUIConstants.error;
        label = 'Cancelled';
      case MembershipStatus.suspended:
        color = AppUIConstants.error;
        label = 'Suspended';
    }

    return PremiumStatusPill(label, color: color);
  }
}
