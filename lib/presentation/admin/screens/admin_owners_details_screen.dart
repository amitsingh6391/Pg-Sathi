import 'package:flutter/material.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/entities/library.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/repositories/library_repository.dart';
import '../../../domain/repositories/user_repository.dart';
import '../../core/app_ui_constants.dart';
import '../widgets/owner_cards/edit_custom_pricing_dialog.dart';
import '../widgets/owner_cards/owner_card.dart';
import '../widgets/owner_cards/owner_filter_bar.dart';

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
        (failure) => errorMsg ??= failure.message ?? 'Failed to load libraries',
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
          final aDate = _ownerLibraryMap[a.id]?.createdAt
              ?? a.createdAt
              ?? DateTime(0);
          final bDate = _ownerLibraryMap[b.id]?.createdAt
              ?? b.createdAt
              ?? DateTime(0);
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
        title: Text(
          'Manage Owners',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        backgroundColor: AppUIConstants.primary,
        foregroundColor: Colors.white,
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
            child: _isLoading
                ? _buildLoadingState()
                : _error != null
                ? _buildErrorState()
                : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppUIConstants.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(
              color: AppUIConstants.primary,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading owners...',
            style: AppUIConstants.bodyMd.copyWith(
              color: AppUIConstants.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppUIConstants.error.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: AppUIConstants.error,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Something went wrong',
            style: AppUIConstants.headingSm.copyWith(
              color: AppUIConstants.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              _error!,
              style: AppUIConstants.bodySm.copyWith(
                color: AppUIConstants.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppUIConstants.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final owners = _getFilteredAndSortedOwners();

    if (owners.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppUIConstants.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people_outline_rounded,
                size: 64,
                color: AppUIConstants.primary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No owners match your search'
                  : 'No owners found',
              style: AppUIConstants.headingSm.copyWith(
                color: AppUIConstants.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try adjusting your search filters'
                  : 'Owners will appear here once added',
              style: AppUIConstants.bodySm.copyWith(
                color: AppUIConstants.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppUIConstants.spacingSm),
      children: [
        OwnerStatsRow(
          totalOwners: _ownerCache.length,
          withLibrary: _countWithLibrary(),
          withoutLibrary: _ownerCache.length - _countWithLibrary(),
          withCustomPricing: _countCustomPricing(),
        ),
        const SizedBox(height: 4),
        ...owners.map((owner) {
          final library = _ownerLibraryMap[owner.id];
          final isExpanded = _expandedState[owner.id] ?? false;

          return OwnerCard(
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
    );
  }
}
