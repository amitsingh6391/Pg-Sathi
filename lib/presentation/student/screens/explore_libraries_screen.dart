import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/library.dart';
import '../../core/app_ui_constants.dart';
import '../../core/widgets/premium_kit.dart';
import '../cubit/explore_libraries_cubit.dart';
import '../cubit/explore_libraries_state.dart';
import '../widgets/explore_library_card.dart';
import 'explore_library_detail_screen.dart';

/// Search-first PG discovery: hero with search + amenity chips, then a feed
/// of rich PG cards.
///
/// Expects an [ExploreLibrariesCubit] to be provided by a parent
/// [BlocProvider] (typically from the navigation screen) to avoid
/// creating a duplicate cubit and duplicate Firestore reads.
class ExploreLibrariesScreen extends StatelessWidget {
  const ExploreLibrariesScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return _ExploreLibrariesView(userId: userId);
  }
}

class _ExploreLibrariesView extends StatelessWidget {
  const _ExploreLibrariesView({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      body: Column(
        children: [
          const _ExploreHero(),
          Expanded(
            child: BlocBuilder<ExploreLibrariesCubit, ExploreLibrariesState>(
              builder: (context, state) {
                final Widget body;
                if (state.isLoading) {
                  body = const _ListingSkeleton(key: ValueKey('loading'));
                } else if (state.isError) {
                  body = _ErrorView(
                    key: const ValueKey('error'),
                    message: state.failure?.message ?? 'Failed to load PGs',
                    onRetry: () =>
                        context.read<ExploreLibrariesCubit>().refresh(),
                  );
                } else {
                  body = _ListingFeed(
                    key: const ValueKey('feed'),
                    userId: userId,
                  );
                }
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  child: body,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// HERO: title, search, amenity chips
// ===========================================================================

class _ExploreHero extends StatefulWidget {
  const _ExploreHero();

  @override
  State<_ExploreHero> createState() => _ExploreHeroState();
}

class _ExploreHeroState extends State<_ExploreHero> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PremiumHero(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Explore PGs',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppUIConstants.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: AppUIConstants.surfaceMuted,
              borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
              border: Border.all(color: AppUIConstants.border),
            ),
            child: TextField(
              controller: _controller,
              onChanged: (value) {
                context.read<ExploreLibrariesCubit>().updateSearch(value);
                setState(() {});
              },
              style: const TextStyle(
                color: AppUIConstants.textPrimary,
                fontSize: 15,
              ),
              cursorColor: AppUIConstants.primary,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search PGs or areas',
                hintStyle: const TextStyle(
                  color: AppUIConstants.textTertiary,
                  fontSize: 14.5,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppUIConstants.primary,
                  size: 22,
                ),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          color: AppUIConstants.textTertiary,
                          size: 20,
                        ),
                        onPressed: () {
                          _controller.clear();
                          context.read<ExploreLibrariesCubit>().updateSearch(
                            '',
                          );
                          setState(() {});
                        },
                      ),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _FilterChipsSection(),
        ],
      ),
    );
  }
}

class _FilterChipsSection extends StatelessWidget {
  const _FilterChipsSection();

  static const _filters = [
    LibraryFacility.ac,
    LibraryFacility.wifi,
    LibraryFacility.cctv,
    LibraryFacility.drinkingWater,
    LibraryFacility.washroom,
    LibraryFacility.powerBackup,
  ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExploreLibrariesCubit, ExploreLibrariesState>(
      buildWhen: (a, b) => a.selectedFilters != b.selectedFilters,
      builder: (context, state) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _filters.map((filter) {
              final selected = state.selectedFilters.contains(filter);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    context.read<ExploreLibrariesCubit>().toggleFilter(filter);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppUIConstants.primary
                          : AppUIConstants.surfaceMuted,
                      borderRadius: BorderRadius.circular(
                        AppUIConstants.radiusFull,
                      ),
                      border: Border.all(
                        color: selected
                            ? AppUIConstants.primary
                            : AppUIConstants.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          selected ? Icons.check_rounded : _icon(filter),
                          size: 15,
                          color: selected
                              ? Colors.white
                              : AppUIConstants.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _label(filter),
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : AppUIConstants.textPrimary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  static IconData _icon(LibraryFacility facility) {
    switch (facility) {
      case LibraryFacility.ac:
        return Icons.ac_unit_rounded;
      case LibraryFacility.wifi:
        return Icons.wifi_rounded;
      case LibraryFacility.powerBackup:
        return Icons.bolt_rounded;
      case LibraryFacility.cctv:
        return Icons.videocam_rounded;
      case LibraryFacility.drinkingWater:
        return Icons.water_drop_rounded;
      case LibraryFacility.washroom:
        return Icons.bathtub_outlined;
    }
  }

  static String _label(LibraryFacility facility) {
    switch (facility) {
      case LibraryFacility.ac:
        return 'AC';
      case LibraryFacility.wifi:
        return 'Wi-Fi';
      case LibraryFacility.powerBackup:
        return 'Power backup';
      case LibraryFacility.washroom:
        return 'Attached bath';
      case LibraryFacility.drinkingWater:
        return 'RO water';
      case LibraryFacility.cctv:
        return 'CCTV';
    }
  }
}

// ===========================================================================
// FEED
// ===========================================================================

class _ListingFeed extends StatelessWidget {
  const _ListingFeed({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExploreLibrariesCubit, ExploreLibrariesState>(
      builder: (context, state) {
        final libraries = state.filteredLibraries;

        return RefreshIndicator(
          color: AppUIConstants.primary,
          backgroundColor: AppUIConstants.surface,
          onRefresh: () => context.read<ExploreLibrariesCubit>().refresh(),
          child: libraries.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.5,
                      child: _EmptyView(
                        hasFilters:
                            state.selectedFilters.isNotEmpty ||
                            state.searchQuery.isNotEmpty,
                        onReset: () {
                          final cubit = context.read<ExploreLibrariesCubit>();
                          cubit.updateSearch('');
                          for (final f in state.selectedFilters.toList()) {
                            cubit.toggleFilter(f);
                          }
                        },
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    24 + MediaQuery.of(context).padding.bottom,
                  ),
                  itemCount: libraries.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _ResultsHeader(count: libraries.length);
                    }
                    final item = libraries[index - 1];
                    return TweenAnimationBuilder<double>(
                      key: ValueKey(item.library.id),
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(
                        milliseconds: 300 + (index.clamp(0, 5) * 60),
                      ),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, child) => Opacity(
                        opacity: v,
                        child: Transform.translate(
                          offset: Offset(0, (1 - v) * 24),
                          child: child,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: ExploreLibraryCard(
                          libraryWithStats: item,
                          onTap: () =>
                              _navigateToDetails(context, item.library),
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  void _navigateToDetails(BuildContext context, Library library) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ExploreLibraryDetailScreen(library: library, userId: userId),
      ),
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExploreLibrariesCubit, ExploreLibrariesState>(
      buildWhen: (a, b) => a.sortBy != b.sortBy,
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(4, 18, 0, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PGs near you',
                      style: TextStyle(
                        color: AppUIConstants.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$count ${count == 1 ? 'result' : 'results'}',
                      style: const TextStyle(
                        color: AppUIConstants.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: AppUIConstants.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppUIConstants.radiusSm + 2,
                  ),
                  side: const BorderSide(color: AppUIConstants.border),
                ),
                child: InkWell(
                  onTap: () => _showSortSheet(context, state.sortBy),
                  borderRadius: BorderRadius.circular(
                    AppUIConstants.radiusSm + 2,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.swap_vert_rounded,
                          size: 16,
                          color: AppUIConstants.primary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _sortLabel(state.sortBy),
                          style: const TextStyle(
                            color: AppUIConstants.primary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _sortLabel(SortOption sort) {
    switch (sort) {
      case SortOption.recent:
        return 'Newest';
      case SortOption.distance:
        return 'Nearest';
      case SortOption.name:
        return 'Name A-Z';
    }
  }

  void _showSortSheet(BuildContext context, SortOption current) {
    final cubit = context.read<ExploreLibrariesCubit>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppUIConstants.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppUIConstants.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text('Sort PGs by', style: AppUIConstants.headingMd),
              const SizedBox(height: 12),
              for (final option in SortOption.values)
                _SortTile(
                  icon: switch (option) {
                    SortOption.recent => Icons.schedule_rounded,
                    SortOption.distance => Icons.near_me_rounded,
                    SortOption.name => Icons.sort_by_alpha_rounded,
                  },
                  label: switch (option) {
                    SortOption.recent => 'Newest first',
                    SortOption.distance => 'Nearest first',
                    SortOption.name => 'Name A-Z',
                  },
                  selected: option == current,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    cubit.updateSort(option);
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SortTile extends StatelessWidget {
  const _SortTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? AppUIConstants.primarySoft
                : AppUIConstants.surfaceMuted,
            borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
            border: Border.all(
              color: selected ? AppUIConstants.primary : AppUIConstants.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected
                    ? AppUIConstants.primary
                    : AppUIConstants.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: AppUIConstants.bodyLg)),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppUIConstants.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// STATES
// ===========================================================================

class _ListingSkeleton extends StatefulWidget {
  const _ListingSkeleton({super.key});

  @override
  State<_ListingSkeleton> createState() => _ListingSkeletonState();
}

class _ListingSkeletonState extends State<_ListingSkeleton>
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

  Widget _bar(double w, double h) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: AppUIConstants.skeletonBase,
      borderRadius: BorderRadius.circular(6),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(_c),
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: 3,
        itemBuilder: (_, _) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: PremiumCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 172, color: AppUIConstants.skeletonBase),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _bar(180, 16),
                      const SizedBox(height: 10),
                      _bar(110, 12),
                      const SizedBox(height: 16),
                      _bar(double.infinity, 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.hasFilters, required this.onReset});

  final bool hasFilters;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppUIConstants.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.home_work_outlined,
                size: 42,
                color: AppUIConstants.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text('No PGs Found', style: AppUIConstants.headingMd),
            const SizedBox(height: 6),
            const Text(
              'Try adjusting your filters or search in a different area.',
              style: AppUIConstants.bodyMd,
              textAlign: TextAlign.center,
            ),
            if (hasFilters) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                label: const Text('Clear search & filters'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppUIConstants.primary,
                  side: const BorderSide(color: AppUIConstants.border),
                  shape: const StadiumBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppUIConstants.error.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 38,
                color: AppUIConstants.error,
              ),
            ),
            const SizedBox(height: 20),
            const Text('Something went wrong', style: AppUIConstants.headingMd),
            const SizedBox(height: 6),
            Text(
              message,
              style: AppUIConstants.bodyMd,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
              style: TextButton.styleFrom(
                foregroundColor: AppUIConstants.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
