import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/di/injection_container.dart';
import '../../../domain/entities/membership.dart';
import '../../../domain/entities/library.dart';
import '../../../domain/repositories/membership_repository.dart';
import '../../../domain/repositories/library_repository.dart';
import '../../core/app_ui_constants.dart';
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
        (failure) => errorMsg = failure.message ?? 'Failed to load libraries',
        (data) => libraries = data as List<Library>,
      );
      countsResult.fold(
        (failure) =>
            errorMsg ??= failure.message ?? 'Failed to load membership counts',
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
            debugPrint('Failed to load students: ${failure.message}');
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
        debugPrint('Error loading students: $e');
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
      final areaMatch = library.area != null &&
          library.area!.toLowerCase().contains(query);

      if (students == null) {
        return library.name.toLowerCase().contains(query) || areaMatch;
      }

      return library.name.toLowerCase().contains(query) ||
          areaMatch ||
          students.any(
            (s) {
              final nameMatch = s.studentName != null &&
                  s.studentName!.toLowerCase().contains(query);
              return nameMatch || s.phoneNumber.toLowerCase().contains(query);
            },
          );
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
      text: _customMessage ??
          '''Hi {name}! 👋

Your library *{library}* uses our official app to manage memberships and seat bookings.

📱 *Download the app now:*
• Android: ${AppConstants.playStoreUrl}
• iOS: ${AppConstants.appStoreUrl}

Manage your membership, book seats, and make payments - all in one place!

Thank you! 📚''',
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit_note, color: AppUIConstants.primary),
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
                'Available placeholders: {name}, {library}',
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
                  fillColor: AppUIConstants.background,
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
          content: Text('No students found'),
          backgroundColor: AppUIConstants.warning,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send WhatsApp to All Students?'),
        content: Text(
          'This will send WhatsApp messages to ${allStudents.length} students one by one. You\'ll need to confirm each message in WhatsApp.',
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

      final message = _customMessage ??
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
          content: Text('Sent WhatsApp to $_bulkTotal students'),
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
        title: const Text('Students Management'),
        backgroundColor: AppUIConstants.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
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
              icon: const Icon(Icons.send, color: Colors.white),
              label: const Text(
                'Send All WhatsApp',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
      body: Column(
        children: [
          // Search and stats bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppUIConstants.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search bar
                TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search libraries or students...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppUIConstants.divider),
                    ),
                    filled: true,
                    fillColor: AppUIConstants.background,
                  ),
                ),
                const SizedBox(height: 12),
                // Stats row
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.local_library_rounded,
                        label: 'Libraries',
                        value: '${_libraryCache.length}',
                        color: AppUIConstants.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.school_rounded,
                        label: 'Students',
                        value: '${_studentCountsByLibrary.values.fold<int>(0, (sum, count) => sum + count)}',
                        color: AppUIConstants.accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.message_rounded,
                        label: 'Total',
                        value: '${_allStudents.length}',
                        color: AppUIConstants.primary,
                      ),
                    ),
                  ],
                ),
                // Message customization button
                if (_customMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppUIConstants.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppUIConstants.primary.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.edit_note,
                                  size: 16,
                                  color: AppUIConstants.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Custom message set',
                                    style: AppUIConstants.bodySm.copyWith(
                                      color: AppUIConstants.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                TextButton(
                                  onPressed: _showMessageCustomizationDialog,
                                  child: const Text('Edit'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: OutlinedButton.icon(
                      onPressed: _showMessageCustomizationDialog,
                      icon: const Icon(Icons.edit_note, size: 18),
                      label: const Text('Customize Message'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppUIConstants.primary,
                        side: BorderSide(color: AppUIConstants.primary),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Bulk sending progress
          if (_isSendingBulk)
            Container(
              padding: const EdgeInsets.all(16),
              color: AppUIConstants.primary.withValues(alpha: 0.1),
              child: Column(
                children: [
                  Row(
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
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
                          color: AppUIConstants.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _bulkTotal > 0 ? _bulkProgress / _bulkTotal : 0,
                    backgroundColor: AppUIConstants.divider,
                    valueColor: AlwaysStoppedAnimation<Color>(AppUIConstants.primary),
                  ),
                ],
              ),
            ),
          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildErrorView()
                    : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: AppUIConstants.error,
              size: 64,
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
              icon: const Icon(Icons.refresh),
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

  Widget _buildContent() {
    final filteredLibraries = _filteredLibraries;

    if (filteredLibraries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school_outlined,
              size: 64,
              color: AppUIConstants.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? 'No libraries found'
                  : 'No results found',
              style: AppUIConstants.bodyLg.copyWith(
                color: AppUIConstants.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredLibraries.length,
        itemBuilder: (context, index) {
          final entry = filteredLibraries[index];
          final library = entry.value;
          final libraryId = entry.key;
          final studentCount = _studentCountsByLibrary[libraryId] ?? 0;
          final students = _studentsByLibrary[libraryId];
          final isLoading = _loadingStudentsForLibraries.contains(libraryId);
          final isExpanded = _expandedLibraries.contains(libraryId);

          return _LibraryCard(
            library: library,
            studentCount: studentCount,
            students: students,
            isLoading: isLoading,
            isExpanded: isExpanded,
            searchQuery: _searchQuery,
            customMessage: _customMessage,
            onExpand: () => _toggleLibraryExpansion(libraryId),
            onSendAll: () => _sendWhatsAppToLibrary(libraryId, library, students ?? []),
          );
        },
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
          content: Text('No students in this library'),
          backgroundColor: AppUIConstants.warning,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send WhatsApp to All Students?'),
        content: Text(
          'This will send WhatsApp messages to ${students.length} students in ${library.name} one by one.',
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
      final message = _customMessage ??
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
          content: Text('Sent WhatsApp to ${students.length} students'),
          backgroundColor: AppUIConstants.success,
        ),
      );
    }
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
        border: Border.all(
          color: color.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: AppUIConstants.bodyLg.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: AppUIConstants.caption.copyWith(
                    color: AppUIConstants.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryCard extends StatelessWidget {
  const _LibraryCard({
    required this.library,
    required this.studentCount,
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
      return s.studentName?.toLowerCase().contains(query) ?? false ||
          s.phoneNumber.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredStudents = _filteredStudents;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppUIConstants.divider.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Library header
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onExpand,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppUIConstants.primary.withValues(alpha: 0.05),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppUIConstants.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.local_library_rounded,
                        color: AppUIConstants.primary,
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
                                Icon(
                                  Icons.location_on_rounded,
                                  size: 12,
                                  color: AppUIConstants.textSecondary,
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
                    // Owner call button
                    if (library.ownerPhone != null &&
                        library.ownerPhone!.isNotEmpty)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _callOwner(context),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppUIConstants.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppUIConstants.primary.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Icon(
                              Icons.phone_rounded,
                              color: AppUIConstants.primary,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    if (library.ownerPhone != null &&
                        library.ownerPhone!.isNotEmpty)
                      const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppUIConstants.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppUIConstants.accent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.school_rounded,
                            size: 14,
                            color: AppUIConstants.accent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$studentCount',
                            style: AppUIConstants.bodySm.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppUIConstants.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppUIConstants.textSecondary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Students list
          if (isExpanded) ...[
            if (isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (students == null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Tap to load students',
                    style: AppUIConstants.bodySm.copyWith(
                      color: AppUIConstants.textTertiary,
                    ),
                  ),
                ),
              )
            else if (filteredStudents.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No students found',
                    style: AppUIConstants.bodySm.copyWith(
                      color: AppUIConstants.textTertiary,
                    ),
                  ),
                ),
              )
            else ...[
              // Send all button for this library
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onSendAll,
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: Text('Send WhatsApp to All (${filteredStudents.length})'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppUIConstants.primary,
                      side: BorderSide(color: AppUIConstants.primary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              // Student list
              ...filteredStudents.map(
                (membership) => _StudentCard(
                  membership: membership,
                  libraryName: library.name,
                  customMessage: customMessage,
                ),
              ),
            ],
          ],
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
    final message = customMessage ??
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AppUIConstants.divider.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppUIConstants.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.person_rounded,
              color: AppUIConstants.accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  membership.studentName ?? 'Unknown Student',
                  style: AppUIConstants.bodyMd.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.phone_rounded,
                      size: 12,
                      color: AppUIConstants.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        membership.phoneNumber,
                        style: AppUIConstants.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _StatusChip(status: membership.status),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _sendWhatsApp(context),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppUIConstants.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppUIConstants.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(
                  Icons.send_rounded,
                  color: AppUIConstants.primary,
                  size: 16,
                ),
              ),
            ),
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: AppUIConstants.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }
}
