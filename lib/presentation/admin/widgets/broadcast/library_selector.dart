import 'package:material_ui/material_ui.dart';

import '../../../../domain/entities/library_summary.dart';
import '../../../core/app_ui_constants.dart';
import '../../../core/widgets/premium_kit.dart';

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

    final allSelected = filtered.every(
      (lib) => widget.selectedLibraryIds.contains(lib.libraryId),
    );

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
    final allSelected =
        filtered.isNotEmpty &&
        filtered.every(
          (lib) => widget.selectedLibraryIds.contains(lib.libraryId),
        );
    final selectedCount = widget.selectedLibraryIds.length;

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: PremiumCard(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: PremiumSectionHeader('Choose PGs')),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: PremiumStatusPill(
                    selectedCount == 0
                        ? 'None selected'
                        : '$selectedCount selected',
                    key: ValueKey(selectedCount),
                    color: selectedCount == 0
                        ? AppUIConstants.textTertiary
                        : AppUIConstants.primaryLight,
                  ),
                ),
              ],
            ),
            Text(
              'Sending to ${widget.targetType}',
              style: AppUIConstants.bodySm,
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              style: AppUIConstants.bodyMd.copyWith(
                color: AppUIConstants.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Search PGs or owners...',
                hintStyle: const TextStyle(
                  color: AppUIConstants.textTertiary,
                  fontSize: 13,
                ),
                filled: true,
                fillColor: AppUIConstants.surfaceMuted,
                isDense: true,
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: AppUIConstants.textSecondary,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          size: 18,
                          color: AppUIConstants.textSecondary,
                        ),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AppUIConstants.radiusSm + 2,
                  ),
                  borderSide: const BorderSide(color: AppUIConstants.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AppUIConstants.radiusSm + 2,
                  ),
                  borderSide: const BorderSide(color: AppUIConstants.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AppUIConstants.radiusSm + 2,
                  ),
                  borderSide: const BorderSide(
                    color: AppUIConstants.primaryLight,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
            if (filtered.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('${filtered.length} PGs', style: AppUIConstants.caption),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _toggleSelectAll,
                    style: TextButton.styleFrom(
                      foregroundColor: AppUIConstants.primaryLight,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: Icon(
                      allSelected
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      size: 18,
                    ),
                    label: Text(allSelected ? 'Deselect all' : 'Select all'),
                  ),
                ],
              ),
            ],
            if (widget.libraries.isEmpty)
              const _EmptyNote(
                icon: Icons.apartment_rounded,
                text: 'No PGs available',
              )
            else if (filtered.isEmpty)
              const _EmptyNote(
                icon: Icons.search_off_rounded,
                text: 'No PGs match your search',
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final library = filtered[index];
                    final isSelected = widget.selectedLibraryIds.contains(
                      library.libraryId,
                    );
                    return _LibraryTile(
                      library: library,
                      isSelected: isSelected,
                      onToggle: () {
                        final newSelection = Set<String>.from(
                          widget.selectedLibraryIds,
                        );
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
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 40, color: AppUIConstants.textTertiary),
            const SizedBox(height: 10),
            Text(text, style: AppUIConstants.bodyMd),
          ],
        ),
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
    final initial = library.libraryName.trim().isEmpty
        ? '?'
        : library.libraryName.trim()[0].toUpperCase();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: isSelected
            ? AppUIConstants.primarySoft
            : AppUIConstants.surfaceMuted,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusSm + 2),
        border: Border.all(
          color: isSelected
              ? AppUIConstants.primaryLight
              : AppUIConstants.border,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(AppUIConstants.radiusSm + 2),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppUIConstants.surface,
                    borderRadius: BorderRadius.circular(
                      AppUIConstants.radiusSm,
                    ),
                  ),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: AppUIConstants.primaryLight,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        library.libraryName,
                        style: AppUIConstants.bodyMd.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppUIConstants.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${library.ownerName} · ${library.activeMemberships} residents',
                        style: AppUIConstants.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppUIConstants.primaryLight
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? AppUIConstants.primaryLight
                          : AppUIConstants.disabled,
                      width: 2,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          size: 14,
                          color: AppUIConstants.background,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
