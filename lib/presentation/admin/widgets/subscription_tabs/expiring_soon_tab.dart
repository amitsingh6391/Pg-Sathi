import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/entities/subscription.dart';
import '../../../core/app_ui_constants.dart';
import '../../cubit/expiring_subscriptions_cubit.dart';
import '../subscription_cards/expiring_subscription_card.dart';
import '../subscription_cards/expiring_trial_card.dart';
import '../subscription_widgets/section_header.dart';

/// Filter options for trials.
enum TrialFilter {
  expiring('Expiring Soon (≤7d)', Icons.timer_off_rounded),
  active('Active Trials (>7d)', Icons.timer_rounded),
  expired('Expired Trials', Icons.cancel_outlined),
  all('All Trials', Icons.list_rounded);

  const TrialFilter(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Tab widget for displaying expiring subscriptions and trials.
/// Optimized with Cubit for state management and caching.
class ExpiringSoonTab extends StatefulWidget {
  const ExpiringSoonTab({
    required this.allSubscriptions,
    this.customMessage,
    this.searchQuery = '',
    this.libraryCache = const {},
    this.ownerNames = const {},
    this.ownerPhones = const {},
    super.key,
  });

  final List<Subscription> allSubscriptions;
  final String? customMessage;
  final String searchQuery;
  final Map<String, dynamic> libraryCache;
  final Map<String, String> ownerNames;
  final Map<String, String> ownerPhones;

  @override
  State<ExpiringSoonTab> createState() => _ExpiringSoonTabState();
}

class _ExpiringSoonTabState extends State<ExpiringSoonTab>
    with AutomaticKeepAliveClientMixin {
  TrialFilter _selectedFilter = TrialFilter.expiring;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<ExpiringSubscriptionsCubit>()
          .loadExpiringData(widget.allSubscriptions);
    });
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppUIConstants.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.filter_list_rounded,
                  color: AppUIConstants.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Filter Trials',
                  style: AppUIConstants.bodyLg.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppUIConstants.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...TrialFilter.values.map((filter) => _FilterOption(
                  filter: filter,
                  isSelected: _selectedFilter == filter,
                  onTap: () {
                    setState(() => _selectedFilter = filter);
                    Navigator.pop(context);
                  },
                )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return BlocBuilder<ExpiringSubscriptionsCubit, ExpiringSubscriptionsState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading expiring data...'),
              ],
            ),
          );
        }

        if (state.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppUIConstants.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading data',
                  style: AppUIConstants.bodyLg.copyWith(
                    color: AppUIConstants.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  state.error!,
                  style: AppUIConstants.bodySm.copyWith(
                    color: AppUIConstants.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => context
                      .read<ExpiringSubscriptionsCubit>()
                      .refresh(widget.allSubscriptions),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppUIConstants.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        if (!state.hasData) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: AppUIConstants.success,
                ),
                const SizedBox(height: 16),
                Text(
                  'No expiring subscriptions or trials',
                  style: AppUIConstants.bodyLg.copyWith(
                    color: AppUIConstants.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'All subscriptions and trials are up to date',
                  style: AppUIConstants.bodySm.copyWith(
                    color: AppUIConstants.textTertiary,
                  ),
                ),
              ],
            ),
          );
        }

        // Apply search filter
        final filteredSubscriptions = _filterSubscriptions(state.expiringSubscriptions);
        final filteredExpiringTrials = _filterTrials(state.expiringTrials);
        final filteredActiveTrials = _filterTrials(state.activeTrials);
        final filteredExpiredTrials = _filterTrials(state.expiredTrials);

        final hasTrials = filteredExpiringTrials.isNotEmpty ||
            filteredActiveTrials.isNotEmpty ||
            filteredExpiredTrials.isNotEmpty;

        return Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              children: [
                // Expiring subscriptions
                if (filteredSubscriptions.isNotEmpty) ...[
                  const SectionHeader(
                    title: 'Expiring Subscriptions',
                    icon: Icons.subscriptions_rounded,
                  ),
                  const SizedBox(height: 12),
                  ...filteredSubscriptions.map(
                    (sub) => ExpiringSubscriptionCard(
                      subscription: sub,
                      library: state.libraryCache[sub.libraryId],
                      ownerName: context
                          .read<ExpiringSubscriptionsCubit>()
                          .getOwnerName(sub.libraryId),
                      ownerPhone: context
                          .read<ExpiringSubscriptionsCubit>()
                          .getOwnerPhone(sub.libraryId),
                      customMessage: widget.customMessage,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                // Trials section
                _buildTrialSection(
                  filteredExpiringTrials,
                  filteredActiveTrials,
                  filteredExpiredTrials,
                ),
              ],
            ),
            // Floating Action Button for Filter
            if (hasTrials)
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton.extended(
                  onPressed: _showFilterBottomSheet,
                  backgroundColor: AppUIConstants.primary,
                  foregroundColor: Colors.white,
                  icon: Icon(_selectedFilter.icon, size: 20),
                  label: Text(
                    _selectedFilter == TrialFilter.expiring
                        ? 'Expiring'
                        : _selectedFilter == TrialFilter.active
                        ? 'Active'
                        : _selectedFilter == TrialFilter.expired
                        ? 'Expired'
                        : 'All',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  elevation: 4,
                ),
              ),
          ],
        );
      },
    );
  }

  List<dynamic> _filterSubscriptions(List<dynamic> subs) {
    if (widget.searchQuery.isEmpty) return subs;

    final query = widget.searchQuery.toLowerCase();
    return subs.where((s) {
      final libraryName = widget.libraryCache[s.libraryId]?.name?.toLowerCase() ?? '';
      final ownerName = widget.ownerNames[s.libraryId]?.toLowerCase() ?? '';
      final ownerPhone = widget.ownerPhones[s.libraryId]?.toLowerCase() ?? '';
      
      return libraryName.contains(query) ||
          ownerName.contains(query) ||
          ownerPhone.contains(query) ||
          s.id.toLowerCase().contains(query) ||
          (s.transactionId?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  List<dynamic> _filterTrials(List<dynamic> trials) {
    if (widget.searchQuery.isEmpty) return trials;

    final query = widget.searchQuery.toLowerCase();
    return trials.where((t) {
      final libraryName = t.libraryName?.toLowerCase() ?? '';
      final ownerName = t.ownerName?.toLowerCase() ?? '';
      final ownerPhone = t.ownerPhone?.toLowerCase() ?? '';
      
      return libraryName.contains(query) ||
          ownerName.contains(query) ||
          ownerPhone.contains(query);
    }).toList();
  }

  Widget _buildTrialSection(
    List<dynamic> expiringTrials,
    List<dynamic> activeTrials,
    List<dynamic> expiredTrials,
  ) {
    final children = <Widget>[];

    switch (_selectedFilter) {
      case TrialFilter.expiring:
        if (expiringTrials.isNotEmpty) {
          children.addAll([
            SectionHeader(
              title: 'Expiring Trials',
              count: expiringTrials.length,
              icon: Icons.timer_off_rounded,
            ),
            const SizedBox(height: 12),
            ...expiringTrials.map(
              (t) => ExpiringTrialCard(
                trialInfo: t,
                customMessage: widget.customMessage,
              ),
            ),
          ]);
        }
        break;

      case TrialFilter.active:
        if (activeTrials.isNotEmpty) {
          children.addAll([
            SectionHeader(
              title: 'Active Trials',
              count: activeTrials.length,
              icon: Icons.timer_rounded,
            ),
            const SizedBox(height: 12),
            ...activeTrials.map(
              (t) => ExpiringTrialCard(
                trialInfo: t,
                customMessage: widget.customMessage,
              ),
            ),
          ]);
        }
        break;

      case TrialFilter.expired:
        if (expiredTrials.isNotEmpty) {
          children.addAll([
            SectionHeader(
              title: 'Expired Trials',
              count: expiredTrials.length,
              icon: Icons.cancel_outlined,
            ),
            const SizedBox(height: 12),
            ...expiredTrials.map(
              (t) => ExpiringTrialCard(
                trialInfo: t,
                customMessage: widget.customMessage,
              ),
            ),
          ]);
        }
        break;

      case TrialFilter.all:
        if (expiringTrials.isNotEmpty) {
          children.addAll([
            SectionHeader(
              title: 'Expiring Trials',
              count: expiringTrials.length,
              icon: Icons.timer_off_rounded,
            ),
            const SizedBox(height: 12),
            ...expiringTrials.map(
              (t) => ExpiringTrialCard(
                trialInfo: t,
                customMessage: widget.customMessage,
              ),
            ),
            const SizedBox(height: 24),
          ]);
        }

        if (activeTrials.isNotEmpty) {
          children.addAll([
            SectionHeader(
              title: 'Active Trials',
              count: activeTrials.length,
              icon: Icons.timer_rounded,
            ),
            const SizedBox(height: 12),
            ...activeTrials.map(
              (t) => ExpiringTrialCard(
                trialInfo: t,
                customMessage: widget.customMessage,
              ),
            ),
            const SizedBox(height: 24),
          ]);
        }

        if (expiredTrials.isNotEmpty) {
          children.addAll([
            SectionHeader(
              title: 'Expired Trials',
              count: expiredTrials.length,
              icon: Icons.cancel_outlined,
            ),
            const SizedBox(height: 12),
            ...expiredTrials.map(
              (t) => ExpiringTrialCard(
                trialInfo: t,
                customMessage: widget.customMessage,
              ),
            ),
          ]);
        }
        break;
    }

    if (children.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                Icons.inbox_outlined,
                size: 48,
                color: AppUIConstants.textTertiary,
              ),
              const SizedBox(height: 16),
              Text(
                widget.searchQuery.isEmpty
                    ? 'No trials in this category'
                    : 'No results found',
                style: AppUIConstants.bodyMd.copyWith(
                  color: AppUIConstants.textTertiary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(children: children);
  }
}

class _FilterOption extends StatelessWidget {
  const _FilterOption({
    required this.filter,
    required this.isSelected,
    required this.onTap,
  });

  final TrialFilter filter;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppUIConstants.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppUIConstants.primary
                  : AppUIConstants.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                filter.icon,
                color: isSelected
                    ? AppUIConstants.primary
                    : AppUIConstants.textSecondary,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  filter.label,
                  style: AppUIConstants.bodyMd.copyWith(
                    color: isSelected
                        ? AppUIConstants.primary
                        : AppUIConstants.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: AppUIConstants.primary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
