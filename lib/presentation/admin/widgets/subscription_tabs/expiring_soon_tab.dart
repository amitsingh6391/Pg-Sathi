import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/entities/subscription.dart';
import '../../../core/app_ui_constants.dart';
import '../../cubit/expiring_subscriptions_cubit.dart';
import '../subscription_cards/expiring_subscription_card.dart';
import '../subscription_cards/expiring_trial_card.dart';
import '../subscription_widgets/section_header.dart';
import '../subscription_widgets/shimmer_box.dart';

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
      context.read<ExpiringSubscriptionsCubit>().loadExpiringData(
        widget.allSubscriptions,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return BlocBuilder<ExpiringSubscriptionsCubit, ExpiringSubscriptionsState>(
      builder: (context, state) {
        if (state.isLoading) {
          return ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 12),
            children: List.generate(5, (_) => const ShimmerCardRow()),
          );
        }

        if (state.error != null) {
          return AdminEmptyState(
            icon: Icons.cloud_off_rounded,
            color: AppUIConstants.error,
            title: 'Error loading data',
            message: state.error,
            actionLabel: 'Retry',
            onAction: () => context.read<ExpiringSubscriptionsCubit>().refresh(
              widget.allSubscriptions,
            ),
          );
        }

        if (!state.hasData) {
          return const AdminEmptyState(
            icon: Icons.verified_rounded,
            color: AppUIConstants.success,
            title: 'All caught up',
            message: 'No expiring subscriptions or trials right now',
          );
        }

        // Apply search filter
        final filteredSubscriptions = _filterSubscriptions(
          state.expiringSubscriptions,
        );
        final filteredExpiringTrials = _filterTrials(state.expiringTrials);
        final filteredActiveTrials = _filterTrials(state.activeTrials);
        final filteredExpiredTrials = _filterTrials(state.expiredTrials);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _SummaryStrip(
              items: [
                _SummaryItem(
                  'Subs',
                  filteredSubscriptions.length,
                  AppUIConstants.warning,
                  null,
                ),
                _SummaryItem(
                  'Expiring',
                  filteredExpiringTrials.length,
                  AppUIConstants.warning,
                  TrialFilter.expiring,
                ),
                _SummaryItem(
                  'Active',
                  filteredActiveTrials.length,
                  AppUIConstants.success,
                  TrialFilter.active,
                ),
                _SummaryItem(
                  'Expired',
                  filteredExpiredTrials.length,
                  AppUIConstants.error,
                  TrialFilter.expired,
                ),
              ],
              selected: _selectedFilter,
              onSelect: (f) => setState(
                () => _selectedFilter = f == _selectedFilter
                    ? TrialFilter.all
                    : f,
              ),
            ),
            const SizedBox(height: 14),
            // Expiring subscriptions
            if (filteredSubscriptions.isNotEmpty) ...[
              SectionHeader(
                title: 'Expiring Subscriptions',
                count: filteredSubscriptions.length,
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
              const SizedBox(height: 16),
            ],
            // Trials section
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: KeyedSubtree(
                key: ValueKey(_selectedFilter),
                child: _buildTrialSection(
                  filteredExpiringTrials,
                  filteredActiveTrials,
                  filteredExpiredTrials,
                ),
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
      final libraryName =
          widget.libraryCache[s.libraryId]?.name?.toLowerCase() ?? '';
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

    void addGroup(String title, IconData icon, List<dynamic> trials) {
      if (trials.isEmpty) return;
      if (children.isNotEmpty) children.add(const SizedBox(height: 16));
      children.addAll([
        SectionHeader(title: title, count: trials.length, icon: icon),
        const SizedBox(height: 12),
        ...trials.map(
          (t) => ExpiringTrialCard(
            trialInfo: t,
            customMessage: widget.customMessage,
          ),
        ),
      ]);
    }

    final showExpiring =
        _selectedFilter == TrialFilter.expiring ||
        _selectedFilter == TrialFilter.all;
    final showActive =
        _selectedFilter == TrialFilter.active ||
        _selectedFilter == TrialFilter.all;
    final showExpired =
        _selectedFilter == TrialFilter.expired ||
        _selectedFilter == TrialFilter.all;

    if (showExpiring) {
      addGroup('Expiring Trials', Icons.timer_off_rounded, expiringTrials);
    }
    if (showActive) {
      addGroup('Active Trials', Icons.timer_rounded, activeTrials);
    }
    if (showExpired) {
      addGroup('Expired Trials', Icons.cancel_outlined, expiredTrials);
    }

    if (children.isEmpty) {
      return AdminEmptyState(
        icon: widget.searchQuery.isEmpty
            ? Icons.inbox_outlined
            : Icons.search_off_rounded,
        title: widget.searchQuery.isEmpty
            ? 'No trials in this category'
            : 'No results found',
        message: widget.searchQuery.isEmpty
            ? 'Pick another status above to see more'
            : 'Try a different search',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _SummaryItem {
  const _SummaryItem(this.label, this.count, this.color, this.filter);

  final String label;
  final int count;
  final Color color;
  final TrialFilter? filter;
}

/// Count strip; trial tiles double as status filters.
class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.items,
    required this.selected,
    required this.onSelect,
  });

  final List<_SummaryItem> items;
  final TrialFilter selected;
  final ValueChanged<TrialFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _tile(items[i])),
        ],
      ],
    );
  }

  Widget _tile(_SummaryItem it) {
    final isSel = it.filter != null && it.filter == selected;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSel
            ? it.color.withValues(alpha: 0.16)
            : AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(
          color: isSel
              ? it.color.withValues(alpha: 0.7)
              : AppUIConstants.border,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
          onTap: it.filter == null ? null : () => onSelect(it.filter!),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                Text(
                  '${it.count}',
                  style: TextStyle(
                    color: it.color,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  it.label,
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
      ),
    );
  }
}
