import 'package:flutter/material.dart';

import '../../../../domain/entities/library_summary.dart';
import '../../../core/app_ui_constants.dart';

/// Library selector widget with search and multi-select functionality.
class LibrarySelector extends StatefulWidget {
  const LibrarySelector({
    super.key,
    required this.libraries,
    required this.selectedLibraryIds,
    required this.onSelectionChanged,
    required this.targetType,
  });

  final List<LibrarySummary> libraries;
  final Set<String> selectedLibraryIds;
  final ValueChanged<Set<String>> onSelectionChanged;
  final String targetType; // 'owners' or 'students'

  @override
  State<LibrarySelector> createState() => _LibrarySelectorState();
}

class _LibrarySelectorState extends State<LibrarySelector> {
  String _searchQuery = '';

  List<LibrarySummary> get _filteredLibraries {
    if (_searchQuery.isEmpty) {
      return widget.libraries;
    }
    final query = _searchQuery.toLowerCase();
    return widget.libraries.where((lib) {
      return lib.libraryName.toLowerCase().contains(query) ||
          lib.ownerName.toLowerCase().contains(query);
    }).toList();
  }

  void _toggleSelectAll() {
    final filtered = _filteredLibraries;
    if (filtered.isEmpty) return;

    final allSelected = filtered.every((lib) => widget.selectedLibraryIds.contains(lib.libraryId));
    
    final newSelection = Set<String>.from(widget.selectedLibraryIds);
    if (allSelected) {
      // Deselect all filtered
      for (final lib in filtered) {
        newSelection.remove(lib.libraryId);
      }
    } else {
      // Select all filtered
      for (final lib in filtered) {
        newSelection.add(lib.libraryId);
      }
    }
    widget.onSelectionChanged(newSelection);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredLibraries;
    final allSelected = filtered.isNotEmpty && 
        filtered.every((lib) => widget.selectedLibraryIds.contains(lib.libraryId));

    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: AppUIConstants.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppUIConstants.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with search and select all
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppUIConstants.primary.withValues(alpha: 0.08),
                  AppUIConstants.primary.withValues(alpha: 0.03),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppUIConstants.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.filter_list_rounded,
                        size: 18,
                        color: AppUIConstants.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Libraries',
                            style: AppUIConstants.bodyMd.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Sending to ${widget.targetType}',
                            style: AppUIConstants.caption.copyWith(
                              color: AppUIConstants.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.selectedLibraryIds.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppUIConstants.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${widget.selectedLibraryIds.length} selected',
                          style: AppUIConstants.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // Search bar
                Container(
                  decoration: BoxDecoration(
                    color: AppUIConstants.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppUIConstants.border.withValues(alpha: 0.3),
                    ),
                  ),
                  child: TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search libraries or owners...',
                      hintStyle: TextStyle(
                        color: AppUIConstants.textSecondary.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: AppUIConstants.textSecondary,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                size: 18,
                                color: AppUIConstants.textSecondary,
                              ),
                              onPressed: () => setState(() => _searchQuery = ''),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                if (filtered.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _toggleSelectAll,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: allSelected
                            ? AppUIConstants.primary.withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppUIConstants.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            allSelected ? Icons.check_box : Icons.check_box_outline_blank,
                            size: 18,
                            color: AppUIConstants.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            allSelected ? 'Deselect All' : 'Select All',
                            style: AppUIConstants.bodySm.copyWith(
                              color: AppUIConstants.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Library list
          if (widget.libraries.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.library_books_outlined,
                      size: 48,
                      color: AppUIConstants.textSecondary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No libraries available',
                      style: AppUIConstants.bodyMd.copyWith(
                        color: AppUIConstants.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 48,
                      color: AppUIConstants.textSecondary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No libraries match your search',
                      style: AppUIConstants.bodyMd.copyWith(
                        color: AppUIConstants.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                padding: const EdgeInsets.all(8),
                shrinkWrap: true,
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final library = filtered[index];
                  final isSelected = widget.selectedLibraryIds.contains(library.libraryId);
                  
                  return _LibraryTile(
                    library: library,
                    isSelected: isSelected,
                    onToggle: () {
                      final newSelection = Set<String>.from(widget.selectedLibraryIds);
                      if (isSelected) {
                        newSelection.remove(library.libraryId);
                      } else {
                        newSelection.add(library.libraryId);
                      }
                      widget.onSelectionChanged(newSelection);
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _LibraryTile extends StatelessWidget {
  const _LibraryTile({
    required this.library,
    required this.isSelected,
    required this.onToggle,
  });

  final LibrarySummary library;
  final bool isSelected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppUIConstants.primary.withValues(alpha: 0.08)
                : AppUIConstants.background.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? AppUIConstants.primary.withValues(alpha: 0.4)
                  : AppUIConstants.border.withValues(alpha: 0.2),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppUIConstants.primary.withValues(alpha: 0.15)
                      : AppUIConstants.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isSelected ? Icons.check_circle : Icons.local_library_rounded,
                  size: 18,
                  color: isSelected ? AppUIConstants.primary : AppUIConstants.textSecondary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      library.libraryName,
                      style: AppUIConstants.bodySm.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? AppUIConstants.primary
                            : AppUIConstants.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      library.ownerName,
                      style: AppUIConstants.caption.copyWith(
                        color: AppUIConstants.textSecondary,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: isSelected ? AppUIConstants.primary : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? AppUIConstants.primary : AppUIConstants.border,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
