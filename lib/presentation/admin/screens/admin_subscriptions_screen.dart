import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/entities/library.dart';
import '../../../domain/entities/subscription.dart';
import '../../../domain/repositories/library_repository.dart';
import '../../../domain/repositories/user_repository.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/admin_cubit.dart';
import '../cubit/expiring_subscriptions_cubit.dart';
import '../widgets/subscription_cards/library_subscription_card.dart';
import '../widgets/subscription_tabs/expiring_soon_tab.dart';

/// Admin screen to view and manage all subscriptions with expiring alerts.
/// Refactored for clean architecture with <500 LOC per file.
class AdminSubscriptionsScreen extends StatefulWidget {
  const AdminSubscriptionsScreen({super.key});

  @override
  State<AdminSubscriptionsScreen> createState() =>
      _AdminSubscriptionsScreenState();
}

class _AdminSubscriptionsScreenState extends State<AdminSubscriptionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Map<String, Library> _libraryCache = {};
  final Map<String, String> _ownerNames = {};
  final Map<String, String> _ownerPhones = {};
  bool _isLoadingLibraryData = false;
  String? _customMessage;

  late final LibraryRepository _libraryRepository;
  late final UserRepository _userRepository;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _libraryRepository = sl<LibraryRepository>();
    _userRepository = sl<UserRepository>();
    
    // Load library data on initial build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AdminCubit>().state;
      if (state.allSubscriptions.isNotEmpty) {
        _loadLibraryData(state.allSubscriptions);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLibraryData(List<Subscription> subscriptions) async {
    if (_isLoadingLibraryData) return;

    final uniqueLibraryIds = subscriptions
        .map((s) => s.libraryId)
        .toSet()
        .where((id) => !_libraryCache.containsKey(id))
        .toList();

    if (uniqueLibraryIds.isEmpty) {
      // Force rebuild even if no new data to load
      if (mounted) setState(() {});
      return;
    }

    setState(() => _isLoadingLibraryData = true);

    // Fetch all libraries in parallel
    final libraryFutures = uniqueLibraryIds
        .map((id) => _libraryRepository.getLibraryById(id))
        .toList();

    final libraryResults = await Future.wait(libraryFutures);

    // Collect all libraries first
    final librariesToLoad = <String, Library>{};
    for (var i = 0; i < uniqueLibraryIds.length; i++) {
      libraryResults[i].fold(
        (_) => null,
        (library) {
          if (library != null) {
            librariesToLoad[uniqueLibraryIds[i]] = library;
          }
        },
      );
    }

    // Fetch all owner data in parallel
    final ownerFutures = librariesToLoad.values
        .map((library) => _userRepository.getUserById(library.ownerId))
        .toList();

    final ownerResults = await Future.wait(ownerFutures);

    // Update state once with all data
    if (mounted) {
      final newLibraryCache = Map<String, Library>.from(_libraryCache);
      final newOwnerNames = Map<String, String>.from(_ownerNames);
      final newOwnerPhones = Map<String, String>.from(_ownerPhones);

      int ownerIndex = 0;
      for (final entry in librariesToLoad.entries) {
        newLibraryCache[entry.key] = entry.value;
        
        ownerResults[ownerIndex].fold(
          (_) => null,
          (owner) {
            newOwnerNames[entry.value.id] = owner.displayName;
            newOwnerPhones[entry.value.id] = owner.phone;
          },
        );
        ownerIndex++;
      }

      setState(() {
        _libraryCache.addAll(newLibraryCache);
        _ownerNames.addAll(newOwnerNames);
        _ownerPhones.addAll(newOwnerPhones);
        _isLoadingLibraryData = false;
      });
    }
  }

  List<Subscription> _filterSubscriptions(List<Subscription> subs) {
    if (_searchQuery.isEmpty) return subs;

    final query = _searchQuery.toLowerCase();
    return subs.where((s) {
      final library = _libraryCache[s.libraryId];
      final libraryName = library?.name.toLowerCase() ?? '';
      final ownerName = _ownerNames[s.libraryId]?.toLowerCase() ?? '';
      final ownerPhone = _ownerPhones[s.libraryId]?.toLowerCase() ?? '';
      
      return libraryName.contains(query) ||
          ownerName.contains(query) ||
          ownerPhone.contains(query) ||
          s.id.toLowerCase().contains(query) ||
          (s.transactionId?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  void _showRejectDialog(Subscription sub) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject Subscription'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Reason for rejection:', style: AppUIConstants.bodyMd),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g., Invalid transaction',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              context.read<AdminCubit>().rejectSubscription(
                sub.id,
                controller.text.trim(),
              );
              Navigator.pop(dialogContext);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppUIConstants.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(Subscription sub) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Subscription'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to permanently delete this subscription record?',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Text('Library ID: ${sub.libraryId}', style: AppUIConstants.bodySm),
            Text('Seats: ${sub.seatCount}', style: AppUIConstants.bodySm),
            Text('Amount: ₹${sub.finalAmount}', style: AppUIConstants.bodySm),
            Text('Status: ${sub.status.name}', style: AppUIConstants.bodySm),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppUIConstants.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppUIConstants.error, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone.',
                      style: TextStyle(
                        color: AppUIConstants.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<AdminCubit>().deleteSubscription(sub.id);
              Navigator.pop(dialogContext);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppUIConstants.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ExpiringSubscriptionsCubit(
        getExpiringTrials: sl(),
      ),
      child: Scaffold(
        backgroundColor: AppUIConstants.background,
        appBar: AppBar(
          title: const Text('Subscriptions'),
          backgroundColor: AppUIConstants.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => context.read<AdminCubit>().loadDashboard(),
              tooltip: 'Refresh',
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            isScrollable: true,
            tabs: const [
              Tab(text: 'All'),
              Tab(text: 'Expiring Soon'),
              Tab(text: 'Pending'),
              Tab(text: 'Active'),
            ],
          ),
        ),
        body: BlocConsumer<AdminCubit, AdminState>(
          listener: (context, state) {
            // Always try to load library data when state changes
            if (state.allSubscriptions.isNotEmpty) {
              _loadLibraryData(state.allSubscriptions);
            }
            
            // Show error snackbar instead of replacing the whole screen
            if (state.status == AdminStateStatus.error && 
                state.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage!),
                  backgroundColor: AppUIConstants.error,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          builder: (context, state) {
            // Only show loading spinner on initial load (when no data exists)
            if (state.status == AdminStateStatus.loading && 
                state.allSubscriptions.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            // If we have data, keep showing it even during background updates
            if (state.allSubscriptions.isNotEmpty || 
                state.status == AdminStateStatus.loaded) {
              return Column(
                children: [
                  _buildSearchBar(),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildSubscriptionList(state.allSubscriptions),
                        ExpiringSoonTab(
                          allSubscriptions: state.allSubscriptions,
                          customMessage: _customMessage,
                          searchQuery: _searchQuery,
                          libraryCache: _libraryCache,
                          ownerNames: _ownerNames,
                          ownerPhones: _ownerPhones,
                        ),
                        _buildSubscriptionList(state.pendingSubscriptions),
                        _buildSubscriptionList(
                          state.allSubscriptions
                              .where((s) => s.status == SubscriptionStatus.active)
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            // Fallback for initial state
            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppUIConstants.surface,
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Search by library, owner, phone, or transaction ID...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppUIConstants.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppUIConstants.divider),
          ),
          filled: true,
          fillColor: AppUIConstants.background,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriptionList(List<Subscription> subscriptions) {
    final filtered = _filterSubscriptions(subscriptions);

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: AppUIConstants.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? 'No subscriptions found'
                  : 'No results found',
              style: AppUIConstants.bodyLg.copyWith(
                color: AppUIConstants.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    // Group subscriptions by library
    final groupedByLibrary = <String, List<Subscription>>{};
    for (final sub in filtered) {
      groupedByLibrary.putIfAbsent(sub.libraryId, () => []).add(sub);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedByLibrary.length,
      itemBuilder: (context, index) {
        final libraryId = groupedByLibrary.keys.elementAt(index);
        final librarySubs = groupedByLibrary[libraryId]!;
        final library = _libraryCache[libraryId];

        return LibrarySubscriptionCard(
          libraryId: libraryId,
          library: library,
          libraryName: library?.name ?? 'Loading...',
          subscriptions: librarySubs,
          ownerName: _ownerNames[libraryId],
          ownerPhone: _ownerPhones[libraryId],
          onApprove: (sub) =>
              context.read<AdminCubit>().approveSubscription(sub.id),
          onReject: (sub) => _showRejectDialog(sub),
          onDelete: (sub) => _showDeleteDialog(sub),
        );
      },
    );
  }
}