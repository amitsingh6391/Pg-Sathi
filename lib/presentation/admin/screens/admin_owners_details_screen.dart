import 'package:material_ui/material_ui.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/entities/library.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/repositories/library_repository.dart';
import '../../../domain/repositories/user_repository.dart';
import '../../core/app_ui_constants.dart';
import '../widgets/owner_cards/edit_custom_pricing_dialog.dart';
import '../widgets/owner_cards/owner_card.dart';
import '../widgets/owner_cards/owner_filter_bar.dart';
import '../widgets/subscription_widgets/shimmer_box.dart';

/// Admin screen for managing owners and their library subscriptions.
/// Features: Search, filter, sort, and custom pricing management.
class AdminOwnersDetailsScreen extends StatefulWidget {
  const AdminOwnersDetailsScreen({super.key});

  @override
  State<AdminOwnersDetailsScreen> createState() =>
      _AdminOwnersDetailsScreenState();
}

class _AdminOwnersDetailsScreenState extends State<AdminOwnersDetailsScreen> {
  final Map<String, Library?> _ownerLibraryMap = {};
  final Map<String, User> _ownerCache = {};
  final Map<String, bool> _expandedState = {};
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  OwnerFilterType _selectedFilter = OwnerFilterType.all;
  OwnerSortType _selectedSort = OwnerSortType.nameAsc;

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
      final userRepo = sl<UserRepository>();
      final libraryRepo = sl<LibraryRepository>();

      // 2 bulk reads total (owners + libraries) instead of 1 + N individual
      // getLibraryByOwnerId calls. For 50 owners this saves ~49 Firestore reads.
      final results = await Future.wait([
        userRepo.getUsersByRole(UserRole.owner),
        libraryRepo.getAllLibraries(),
      ]);

      final ownersResult = results[0] as dynamic;
      final librariesResult = results[1] as dynamic;

      String? errorMsg;
      List<User>? owners;
      List<Library>? libraries;

      ownersResult.fold(
        (failure) => errorMsg = failure.message ?? 'Failed to load owners',
        (data) => owners = data as List<User>,
      );
      librariesResult.fold(
        (failure) => errorMsg ??= failure.message ?? 'Failed to load PGs',
        (data) => libraries = data as List<Library>,
      );

      if (owners == null) {
        if (mounted) {
          setState(() {
            _error = errorMsg ?? 'Failed to load data';
            _isLoading = false;
          });
        }
        return;
      }

      // Build owner map
      final ownerMap = <String, User>{};
      for (final owner in owners!) {
        ownerMap[owner.id] = owner;
      }

      // Build ownerId → Library map from the bulk libraries list (in-memory join)
      final newLibraryMap = <String, Library?>{};
      final libraryByOwnerId = <String, Library>{};
      if (libraries != null) {
        for (final lib in libraries!) {
          libraryByOwnerId[lib.ownerId] = lib;
        }
      }
      for (final owner in owners!) {
        newLibraryMap[owner.id] = libraryByOwnerId[owner.id];
      }

      if (mounted) {
        setState(() {
          _ownerCache
            ..clear()
            ..addAll(ownerMap);
          _ownerLibraryMap
            ..clear()
            ..addAll(newLibraryMap);
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

  List<User> _getFilteredAndSortedOwners() {
    var owners = _ownerCache.values.toList();

    // Apply filter
    switch (_selectedFilter) {
      case OwnerFilterType.withLibrary:
        owners = owners.where((o) => _ownerLibraryMap[o.id] != null).toList();
      case OwnerFilterType.withoutLibrary:
        owners = owners.where((o) => _ownerLibraryMap[o.id] == null).toList();
      case OwnerFilterType.all:
        break;
    }

    // Apply search
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      owners = owners.where((o) {
        return o.displayName.toLowerCase().contains(query) ||
            o.phone.toLowerCase().contains(query) ||
            (o.email?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // Apply sort
    switch (_selectedSort) {
      case OwnerSortType.nameAsc:
        owners.sort((a, b) => a.displayName.compareTo(b.displayName));
      case OwnerSortType.createdDateDesc:
        owners.sort((a, b) {
          // Prefer library createdAt, fall back to owner registration date.
          // Using DateTime(0) as a last resort so owners with unknown dates
          // sort to the bottom instead of randomly appearing at the top.
          final aDate =
              _ownerLibraryMap[a.id]?.createdAt ?? a.createdAt ?? DateTime(0);
          final bDate =
              _ownerLibraryMap[b.id]?.createdAt ?? b.createdAt ?? DateTime(0);
          return bDate.compareTo(aDate);
        });
      case OwnerSortType.customPriceDesc:
        owners.sort((a, b) {
          final aPrice = _ownerLibraryMap[a.id]?.customMonthlyPrice ?? 0;
          final bPrice = _ownerLibraryMap[b.id]?.customMonthlyPrice ?? 0;
          return bPrice.compareTo(aPrice);
        });
    }

    return owners;
  }

  int _countCustomPricing() {
    return _ownerLibraryMap.values
        .where((lib) => lib?.customMonthlyPrice != null)
        .length;
  }

  int _countWithLibrary() {
    return _ownerLibraryMap.values.where((lib) => lib != null).length;
  }

  Future<void> _editLibraryPricing(Library library) async {
    final result = await showEditCustomPricingSheet(
      context: context,
      currentPrice: library.customMonthlyPrice,
      libraryName: library.name,
      libraryCapacity: library.capacity,
    );

    if (result == null) return;

    final libraryRepo = sl<LibraryRepository>();
    final updatedLib = library.copyWith(
      customMonthlyPrice: result.clearPrice ? null : result.newPrice,
    );

    final updateRes = await libraryRepo.updateLibrary(updatedLib);
    if (!mounted) return;

    updateRes.fold(
      (failure) =>
          _showSnackBar(failure.message ?? 'Failed to update', isError: true),
      (_) async {
        // Reload library from Firestore to get the actual updated data
        final refreshResult = await libraryRepo.getLibraryById(library.id);
        if (!mounted) return;

        refreshResult.fold(
          (failure) {
            // Fallback to local update if reload fails
            _ownerLibraryMap[library.ownerId] = updatedLib;
          },
          (refreshedLibrary) {
            _ownerLibraryMap[library.ownerId] = refreshedLibrary;
          },
        );

        setState(() {});
        _showSnackBar('Pricing updated successfully!');
      },
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: isError
            ? AppUIConstants.error
            : AppUIConstants.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      appBar: AppBar(
        title: const Text(
          'Manage Owners',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        backgroundColor: AppUIConstants.background,
        foregroundColor: AppUIConstants.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: Column(
        children: [
          OwnerFilterBar(
            searchQuery: _searchQuery,
            onSearchChanged: (v) => setState(() => _searchQuery = v),
            selectedFilter: _selectedFilter,
            onFilterChanged: (v) => setState(() => _selectedFilter = v),
            selectedSort: _selectedSort,
            onSortChanged: (v) => setState(() => _selectedSort = v),
            onRefresh: _loadData,
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _isLoading
                  ? KeyedSubtree(
                      key: const ValueKey('loading'),
                      child: _buildLoadingState(),
                    )
                  : _error != null
                  ? KeyedSubtree(
                      key: const ValueKey('error'),
                      child: _buildErrorState(),
                    )
                  : KeyedSubtree(
                      key: const ValueKey('content'),
                      child: _buildContent(),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 12),
      children: List.generate(6, (_) => const ShimmerCardRow()),
    );
  }

  Widget _buildErrorState() {
    return AdminEmptyState(
      icon: Icons.cloud_off_rounded,
      color: AppUIConstants.error,
      title: 'Something went wrong',
      message: _error,
      actionLabel: 'Try Again',
      onAction: _loadData,
    );
  }

  Widget _buildContent() {
    final owners = _getFilteredAndSortedOwners();

    if (owners.isEmpty) {
      final searching = _searchQuery.isNotEmpty;
      return AdminEmptyState(
        icon: searching ? Icons.search_off_rounded : Icons.groups_outlined,
        title: searching ? 'No owners match your search' : 'No owners found',
        message: searching
            ? 'Try a different name, phone or email'
            : 'Owners will appear here once added',
        actionLabel: 'Refresh',
        onAction: _loadData,
      );
    }

    return RefreshIndicator(
      color: AppUIConstants.primaryLight,
      backgroundColor: AppUIConstants.surface,
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          OwnerStatsRow(
            totalOwners: _ownerCache.length,
            withLibrary: _countWithLibrary(),
            withoutLibrary: _ownerCache.length - _countWithLibrary(),
            withCustomPricing: _countCustomPricing(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 2),
            child: Text(
              '${owners.length} owner${owners.length == 1 ? '' : 's'}',
              style: AppUIConstants.caption,
            ),
          ),
          ...owners.map((owner) {
            final library = _ownerLibraryMap[owner.id];
            final isExpanded = _expandedState[owner.id] ?? false;

            return OwnerCard(
              key: ValueKey(owner.id),
              owner: owner,
              library: library,
              isExpanded: isExpanded,
              onExpand: () =>
                  setState(() => _expandedState[owner.id] = !isExpanded),
              onEditPricing: library != null
                  ? () => _editLibraryPricing(library)
                  : null,
            );
          }),
        ],
      ),
    );
  }
}
