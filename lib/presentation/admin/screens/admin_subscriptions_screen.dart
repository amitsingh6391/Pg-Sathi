import 'package:material_ui/material_ui.dart';
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
import '../widgets/subscription_widgets/shimmer_box.dart';

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
      libraryResults[i].fold((_) => null, (library) {
        if (library != null) {
          librariesToLoad[uniqueLibraryIds[i]] = library;
        }
      });
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

        ownerResults[ownerIndex].fold((_) => null, (owner) {
          newOwnerNames[entry.value.id] = owner.displayName;
          newOwnerPhones[entry.value.id] = owner.phone;
        });
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
        backgroundColor: AppUIConstants.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
        ),
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
        backgroundColor: AppUIConstants.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
        ),
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
            Text('PG ID: ${sub.libraryId}', style: AppUIConstants.bodySm),
            Text('Beds: ${sub.seatCount}', style: AppUIConstants.bodySm),
            Text('Amount: ₹${sub.finalAmount}', style: AppUIConstants.bodySm),
            Text('Status: ${sub.status.name}', style: AppUIConstants.bodySm),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppUIConstants.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: AppUIConstants.error,
                    size: 20,
                  ),
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

  Widget _buildSkeleton() {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 16),
      children: List.generate(5, (_) => const ShimmerCardRow()),
    );
  }

  int _countStatus(List<Subscription> subs, SubscriptionStatus status) =>
      subs.where((s) => s.status == status).length;

  Widget _buildSummaryStrip(AdminState state) {
    final all = state.allSubscriptions;
    final pending = state.pendingSubscriptions.length;
    final active = _countStatus(all, SubscriptionStatus.active);
    final expired = _countStatus(all, SubscriptionStatus.expired);
    final issues =
        _countStatus(all, SubscriptionStatus.rejected) +
        _countStatus(all, SubscriptionStatus.cancelled);

    Widget cell(String label, int n, Color c, int tab) {
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
          onTap: () => _tabController.animateTo(tab),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                Text(
                  '$n',
                  style: TextStyle(
                    color: c,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppUIConstants.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(color: AppUIConstants.border),
      ),
      child: Row(
        children: [
          cell('Total', all.length, AppUIConstants.textPrimary, 0),
          cell('Pending', pending, AppUIConstants.warning, 2),
          cell('Active', active, AppUIConstants.success, 3),
          cell('Expired', expired, AppUIConstants.textTertiary, 0),
          cell('Rejected', issues, AppUIConstants.error, 0),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ExpiringSubscriptionsCubit(getExpiringTrials: sl()),
      child: Scaffold(
        backgroundColor: AppUIConstants.background,
        appBar: AppBar(
          title: const Text(
            'Subscriptions',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          backgroundColor: AppUIConstants.background,
          foregroundColor: AppUIConstants.textPrimary,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => context.read<AdminCubit>().loadDashboard(),
              tooltip: 'Refresh',
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: AppUIConstants.primaryLight,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: AppUIConstants.primaryLight,
            unselectedLabelColor: AppUIConstants.textSecondary,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700),
            dividerColor: AppUIConstants.divider,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
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
            // Only show skeleton on initial load (when no data exists)
            if (state.status == AdminStateStatus.loading &&
                state.allSubscriptions.isEmpty) {
              return _buildSkeleton();
            }

            // If we have data, keep showing it even during background updates
            if (state.allSubscriptions.isNotEmpty ||
                state.status == AdminStateStatus.loaded) {
              return Column(
                children: [
                  _buildSearchBar(),
                  _buildSummaryStrip(state),
                  const SizedBox(height: 4),
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
                              .where(
                                (s) => s.status == SubscriptionStatus.active,
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            // Fallback for initial state
            return _buildSkeleton();
          },
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppUIConstants.surface,
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
          border: Border.all(color: AppUIConstants.border),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value),
          style: AppUIConstants.bodyMd,
          cursorColor: AppUIConstants.primaryLight,
          decoration: InputDecoration(
            hintText: 'Search PG, owner, phone or transaction ID',
            hintStyle: AppUIConstants.bodySm.copyWith(
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
                      size: 18,
                      color: AppUIConstants.textSecondary,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriptionList(List<Subscription> subscriptions) {
    final filtered = _filterSubscriptions(subscriptions);

    if (filtered.isEmpty) {
      final searching = _searchQuery.isNotEmpty;
      return AdminEmptyState(
        icon: searching ? Icons.search_off_rounded : Icons.inbox_outlined,
        title: searching ? 'No results found' : 'No subscriptions found',
        message: searching
            ? 'Try a different PG, owner or transaction ID'
            : 'Subscriptions in this view will show up here',
      );
    }

    // Group subscriptions by library
    final groupedByLibrary = <String, List<Subscription>>{};
    for (final sub in filtered) {
      groupedByLibrary.putIfAbsent(sub.libraryId, () => []).add(sub);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
