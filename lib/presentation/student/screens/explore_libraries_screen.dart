import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/library.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/explore_libraries_cubit.dart';
import '../cubit/explore_libraries_state.dart';
import '../widgets/explore_library_card.dart';
import 'explore_library_detail_screen.dart';

/// Screen for students to explore available libraries.
/// Redesigned to match modern UI with search, filters, and sorting.
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
      body: BlocBuilder<ExploreLibrariesCubit, ExploreLibrariesState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppUIConstants.primary),
            );
          }
          if (state.isError) {
            return _ErrorView(
              message: state.failure?.message ?? 'Failed to load libraries',
              onRetry: () => context.read<ExploreLibrariesCubit>().refresh(),
            );
          }

          return CustomScrollView(
            slivers: [
              // Sliver App Bar with search and filters
              SliverAppBar(
                expandedHeight: 150,
                floating: false,
                pinned: true,
                centerTitle: false,
                backgroundColor: AppUIConstants.primary,
                title: const Text(
                  'Explore PGs',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      color: AppUIConstants.primary,
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 64, 20, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            _SearchAndFilterSection(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Filter chips section
              SliverToBoxAdapter(
                child: Container(
                  color: AppUIConstants.primary,
                  padding: const EdgeInsets.only(
                    left: 20,
                    right: 20,
                    bottom: 8,
                    top: 8,
                  ),
                  child: _FilterChipsSection(),
                ),
              ),

              // Content
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                sliver: _ContentSection(userId: userId),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SearchAndFilterSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              onChanged: (value) =>
                  context.read<ExploreLibrariesCubit>().updateSearch(value),
              style: const TextStyle(color: Colors.black87, fontSize: 15),
              cursorColor: AppUIConstants.primary,
              decoration: InputDecoration(
                hintText: 'Search PGs, areas...',
                hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[600]),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterChipsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExploreLibrariesCubit, ExploreLibrariesState>(
      builder: (context, state) {
        final filters = [
          LibraryFacility.ac,
          LibraryFacility.wifi,
          LibraryFacility.cctv,
          LibraryFacility.drinkingWater,
          LibraryFacility.washroom,
          LibraryFacility
              .powerBackup, // Using powerBackup as "Silent Zone" equivalent
        ];

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: filters.map((filter) {
              final isSelected = state.selectedFilters.contains(filter);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: isSelected,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getFilterIcon(filter),
                        size: 16,
                        color: isSelected
                            ? Colors.white
                            : Colors.black.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _getFilterLabel(filter),
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : Colors.black.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  onSelected: (_) => context
                      .read<ExploreLibrariesCubit>()
                      .toggleFilter(filter),
                  selectedColor: AppUIConstants.primaryLight,
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  checkmarkColor: Colors.white,
                  side: BorderSide.none,
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  IconData _getFilterIcon(LibraryFacility facility) {
    switch (facility) {
      case LibraryFacility.ac:
        return Icons.ac_unit;
      case LibraryFacility.wifi:
        return Icons.wifi;
      case LibraryFacility.powerBackup:
        return Icons.volume_off;
      case LibraryFacility.cctv:
        return Icons.camera_alt_outlined;
      case LibraryFacility.drinkingWater:
        return Icons.water;
      case LibraryFacility.washroom:
        return Icons.wash_rounded;
    }
  }

  String _getFilterLabel(LibraryFacility facility) {
    switch (facility) {
      case LibraryFacility.ac:
        return 'AC';
      case LibraryFacility.wifi:
        return 'Free Wifi';
      case LibraryFacility.powerBackup:
        return 'Silent Zone';
      default:
        return facility.displayName;
    }
  }
}

class _ContentSection extends StatelessWidget {
  const _ContentSection({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExploreLibrariesCubit, ExploreLibrariesState>(
      builder: (context, state) {
        final libraries = state.filteredLibraries;

        if (libraries.isEmpty) {
          return SliverFillRemaining(child: _EmptyView());
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index == 0) return _SectionHeader();

              final libraryIndex = index - 1;
              if (libraryIndex >= libraries.length) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ExploreLibraryCard(
                  libraryWithStats: libraries[libraryIndex],
                  onTap: () => _navigateToDetails(
                    context,
                    libraries[libraryIndex].library,
                  ),
                ),
              );
            },
            childCount: libraries.length + 1, // +1 for header
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

// Removed _FilterIconButton - unnecessary as filter chips are already available

class _SectionHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExploreLibrariesCubit, ExploreLibrariesState>(
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          color: AppUIConstants.background,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const               Text('PGs NEAR YOU',
                style: TextStyle(
                  color: AppUIConstants.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              _SortDropdown(),
            ],
          ),
        );
      },
    );
  }
}

class _SortDropdown extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExploreLibrariesCubit, ExploreLibrariesState>(
      builder: (context, state) {
        return PopupMenuButton<SortOption>(
          icon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Sort: ${_getSortLabel(state.sortBy)}',
                style: const TextStyle(
                  color: AppUIConstants.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_drop_down,
                color: AppUIConstants.primary,
                size: 16,
              ),
            ],
          ),
          onSelected: (value) {
            context.read<ExploreLibrariesCubit>().updateSort(value);
          },
          itemBuilder: (context) => [
            PopupMenuItem<SortOption>(
              value: SortOption.distance,
              child: Row(
                children: [
                  if (state.sortBy == SortOption.distance)
                    const Icon(
                      Icons.check,
                      size: 16,
                      color: AppUIConstants.primary,
                    )
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 8),
                  const Text('Distance'),
                ],
              ),
            ),
            PopupMenuItem<SortOption>(
              value: SortOption.name,
              child: Row(
                children: [
                  if (state.sortBy == SortOption.name)
                    const Icon(
                      Icons.check,
                      size: 16,
                      color: AppUIConstants.primary,
                    )
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 8),
                  const Text('Name'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _getSortLabel(SortOption sort) {
    switch (sort) {
      case SortOption.distance:
        return 'Distance';
      case SortOption.name:
        return 'Name';
    }
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppUIConstants.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.local_library_outlined,
                size: 56,
                color: AppUIConstants.disabled,
              ),
              const SizedBox(height: 20),
              Text('No PGs Found', style: AppUIConstants.headingMd),
              const SizedBox(height: 8),
              Text(
                'Try adjusting your filters or search in a different area.',
                style: AppUIConstants.bodySm,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppUIConstants.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AppUIConstants.textTertiary,
              ),
              const SizedBox(height: 20),
              Text('Something went wrong', style: AppUIConstants.headingMd),
              const SizedBox(height: 8),
              Text(
                message,
                style: AppUIConstants.bodySm,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
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
      ),
    );
  }
}
