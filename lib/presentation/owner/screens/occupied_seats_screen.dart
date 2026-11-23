import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../core/app_ui_constants.dart';
import '../../../domain/entities/custom_slot.dart';
import '../../../domain/entities/library.dart';
import '../../../domain/entities/payment.dart';
import '../../../domain/usecases/get_occupied_seats.dart';
import '../../../domain/usecases/get_slots_by_library.dart';
import '../cubit/occupied_seats_cubit.dart';
import '../cubit/occupied_seats_state.dart';
import '../widgets/occupied_seats/occupied_seats_actions.dart';
import '../widgets/occupied_seats/occupied_seats_empty_views.dart';
import '../widgets/occupied_seats/occupied_seats_list.dart';
import '../../core/widgets/premium_kit.dart';

/// Residents + bed map screen: summary hero, filter chips, bed map and
/// resident cards. Filters: All | Plans | Expiring | Reserved | Rent due | Expired.
class OccupiedSeatsScreen extends StatefulWidget {
  const OccupiedSeatsScreen({super.key, required this.library});

  final Library library;

  @override
  State<OccupiedSeatsScreen> createState() => _OccupiedSeatsScreenState();
}

class _Filter {
  const _Filter({
    required this.label,
    required this.pick,
    this.emptyMessage,
    this.emptyIcon,
    this.showExpired = false,
  });

  final String label;
  final List<OccupiedSeatInfo> Function(OccupiedSeatsState state) pick;
  final String? emptyMessage;
  final IconData? emptyIcon;
  final bool showExpired;
}

class _OccupiedSeatsScreenState extends State<OccupiedSeatsScreen> {
  List<CustomSlot> _customSlots = [];
  bool _isLoadingSlots = true;

  // Search functionality
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _debounceTimer;
  static const _debounceDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _loadSlotsAndSeats();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      if (mounted) {
        context.read<OccupiedSeatsCubit>().updateSearchQuery(
          _searchController.text,
        );
      }
    });
  }

  Future<void> _loadSlotsAndSeats() async {
    setState(() => _isLoadingSlots = true);

    final getSlotsUseCase = sl<GetSlotsByLibrary>();
    final slotsResult = await getSlotsUseCase(
      GetSlotsByLibraryParams(libraryId: widget.library.id, activeOnly: true),
    );
    if (!mounted) return;

    slotsResult.fold(
      (_) => setState(() {
        _customSlots = [];
        _isLoadingSlots = false;
      }),
      (slots) {
        setState(() {
          _customSlots = slots;
          _isLoadingSlots = false;
        });
      },
    );

    // Load occupied beds
    context.read<OccupiedSeatsCubit>().load(
      libraryId: widget.library.id,
      libraryCapacity: widget.library.capacity,
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    context.read<OccupiedSeatsCubit>().clearSearch();
    _searchFocusNode.unfocus();
  }

  /// Filters mapped onto the existing stay lists.
  List<_Filter> get _filters => [
    _Filter(label: 'All', pick: (s) => s.occupiedSeats),
    _Filter(
      label: 'New joined',
      pick: (s) => s.occupiedSeats.where((e) => e.isJoinedThisMonth).toList(),
      emptyMessage: 'No residents joined this month',
      emptyIcon: Icons.person_add_alt_1_rounded,
    ),
    _Filter(
      label: 'Pending',
      pick: (s) => s.occupiedSeats.where((e) => e.isReserved).toList(),
      emptyMessage: 'No pending residents',
      emptyIcon: Icons.hourglass_empty_rounded,
    ),
    _Filter(
      label: 'Partial',
      pick: (s) =>
          s.occupiedSeats.where((e) => e.membership.hasPartialPayment).toList(),
      emptyMessage: 'No partial payments',
      emptyIcon: Icons.payment_outlined,
    ),
    _Filter(
      label: 'Expired',
      pick: (s) => s.expiredSeats,
      emptyMessage: 'No expired stays',
      emptyIcon: Icons.event_busy_rounded,
      showExpired: true,
    ),
    _Filter(
      label: 'Due Today',
      pick: (s) => s.occupiedSeats.where((e) => e.isExpiringToday).toList(),
      emptyMessage: 'No rent due today',
      emptyIcon: Icons.event_repeat_rounded,
    ),
    ..._customSlots.map(
      (slot) => _Filter(
        label: slot.name,
        pick: (s) => _filterBySlot(s.occupiedSeats, slot),
        emptyMessage: 'No residents in ${slot.name}',
      ),
    ),
  ];

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final filters = _filters;
    return DefaultTabController(
      // Rebuilt when room types load and the tab count changes.
      key: ValueKey(filters.length),
      length: filters.length,
      child: Scaffold(
        backgroundColor: AppUIConstants.background,
        body: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: _isLoadingSlots
                  ? const _ResidentsSkeleton()
                  : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Top bar + search (fixed)
  // -------------------------------------------------------------------------

  Widget _buildTopBar() {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: _buildTopBarContent(),
    );
  }

  Widget _buildTopBarContent() {
    return Container(
      decoration: const BoxDecoration(
        color: AppUIConstants.surface,
        border: Border(bottom: BorderSide(color: AppUIConstants.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: AppUIConstants.textPrimary,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Residents',
                          style: TextStyle(
                            color: AppUIConstants.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.library.name,
                          style: const TextStyle(
                            color: AppUIConstants.textSecondary,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  BlocBuilder<OccupiedSeatsCubit, OccupiedSeatsState>(
                    buildWhen: (prev, curr) =>
                        prev.isExporting != curr.isExporting,
                    builder: (context, state) {
                      return state.isExporting
                          ? const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppUIConstants.primary,
                                ),
                              ),
                            )
                          : IconButton(
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                context
                                    .read<OccupiedSeatsCubit>()
                                    .exportMemberData(
                                      libraryName: widget.library.name,
                                    );
                              },
                              icon: const Icon(Icons.download_rounded),
                              color: AppUIConstants.textSecondary,
                              tooltip: 'Export to Excel',
                            );
                    },
                  ),
                  IconButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _loadSlotsAndSeats();
                      context.read<OccupiedSeatsCubit>().refresh();
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    color: AppUIConstants.textSecondary,
                    tooltip: 'Refresh',
                  ),
                  IconButton(
                    onPressed: () => showOccupiedSeatsSortDialog(context),
                    icon: const Icon(Icons.sort_rounded),
                    color: AppUIConstants.textSecondary,
                    tooltip: 'Sort',
                  ),
                ],
              ),
            ),
            _buildSearchBar(),
            _buildTabBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return TabBar(
      isScrollable: true,
      onTap: (_) => HapticFeedback.selectionClick(),
      indicatorColor: AppUIConstants.primary,
      indicatorWeight: 3,
      dividerColor: Colors.transparent,
      labelColor: AppUIConstants.primary,
      unselectedLabelColor: AppUIConstants.textSecondary,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      unselectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 13,
      ),
      tabAlignment: TabAlignment.start,
      labelPadding: const EdgeInsets.symmetric(horizontal: 14),
      tabs: [for (final f in _filters) Tab(text: f.label)],
    );
  }

  Widget _buildSearchBar() {
    return BlocBuilder<OccupiedSeatsCubit, OccupiedSeatsState>(
      buildWhen: (prev, curr) => prev.hasActiveSearch != curr.hasActiveSearch,
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: AppUIConstants.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppUIConstants.border),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: const TextStyle(
                color: AppUIConstants.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              cursorColor: AppUIConstants.primary,
              decoration: InputDecoration(
                hintText: 'Search by name, phone or bed...',
                hintStyle: const TextStyle(
                  color: AppUIConstants.textTertiary,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppUIConstants.textTertiary,
                  size: 22,
                ),
                suffixIcon: state.hasActiveSearch
                    ? IconButton(
                        onPressed: _clearSearch,
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppUIConstants.border,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: AppUIConstants.textSecondary,
                            size: 14,
                          ),
                        ),
                      )
                    : null,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // Scrolling content: hero, filters, bed map, resident cards
  // -------------------------------------------------------------------------

  Widget _buildContent() {
    return BlocConsumer<OccupiedSeatsCubit, OccupiedSeatsState>(
      listener: (context, state) {
        if (state.actionStatus == ActionStatus.success) {
          showOccupiedSeatsSnackBar(
            context,
            state.actionMessage ?? 'Action completed',
            isError: false,
          );
          context.read<OccupiedSeatsCubit>().resetActionStatus();
        } else if (state.actionStatus == ActionStatus.failure) {
          showOccupiedSeatsSnackBar(
            context,
            state.actionMessage ?? 'Action failed',
            isError: true,
          );
          context.read<OccupiedSeatsCubit>().resetActionStatus();
        }
      },
      builder: (context, state) {
        if (state.isLoading) {
          return const _ResidentsSkeleton();
        }

        if (state.status == OccupiedSeatsStatus.error) {
          return OccupiedSeatsErrorView(
            message: state.failure?.message ?? 'Failed to load',
            onRetry: () => context.read<OccupiedSeatsCubit>().refresh(),
          );
        }

        final filters = _filters;
        final tabs = DefaultTabController.of(context);
        return TabBarView(
          children: [
            for (var i = 0; i < filters.length; i++)
              _buildSeatsList(
                seats: sortOccupiedSeats(
                  state.searchSeats(filters[i].pick(state)),
                  state.sortBy,
                ),
                state: state,
                hasActiveSearch: state.hasActiveSearch,
                emptyMessage: filters[i].emptyMessage,
                emptyIcon: filters[i].emptyIcon,
                showExpired: filters[i].showExpired,
                header: const SizedBox(height: 16),
                emptyActionLabel: i != 0 ? 'Show all residents' : 'Refresh',
                onEmptyAction: i != 0
                    ? () => tabs.animateTo(0)
                    : () => context.read<OccupiedSeatsCubit>().refresh(),
              ),
          ],
        );
      },
    );
  }

  /// Builds the resident list, wiring callbacks to action handlers.
  Widget _buildSeatsList({
    required List<OccupiedSeatInfo> seats,
    required OccupiedSeatsState state,
    required bool hasActiveSearch,
    String? emptyMessage,
    IconData? emptyIcon,
    bool showExpired = false,
    bool includeReassign = true,
    Widget? header,
    String? emptyActionLabel,
    VoidCallback? onEmptyAction,
  }) {
    return OccupiedSeatsList(
      seats: seats,
      isActionInProgress: state.isActionInProgress,
      onCancel: (seat) => _onCancel(context, seat),
      onEdit: (seat) => _onEdit(context, seat),
      onSendReminder: (seat) => _onSendReminder(context, seat),
      onConvertPending: (seat, {bool forUpcomingPlan = false}) =>
          _onConvertPending(context, seat, forUpcomingPlan: forUpcomingPlan),
      onReassign: includeReassign ? (seat) => _onReassign(context, seat) : null,
      onRefund: (seat) => _onRefund(context, seat),
      libraryId: widget.library.id,
      customSlots: _customSlots,
      library: widget.library,
      emptyMessage: emptyMessage,
      emptyIcon: emptyIcon,
      hasActiveSearch: hasActiveSearch,
      searchQuery: state.searchQuery,
      showExpired: showExpired,
      header: header,
      onClearSearch: _clearSearch,
      emptyActionLabel: emptyActionLabel,
      onEmptyAction: onEmptyAction,
    );
  }

  List<OccupiedSeatInfo> _filterBySlot(
    List<OccupiedSeatInfo> seats,
    CustomSlot slot,
  ) {
    return seats.where((s) => s.membership.slotId == slot.id).toList();
  }

  // -------------------------------------------------------------------------
  // Action handler delegates
  // -------------------------------------------------------------------------

  void _onCancel(BuildContext context, OccupiedSeatInfo seat) {
    showCancelMembershipDialog(
      context,
      seatInfo: seat,
      cubit: context.read<OccupiedSeatsCubit>(),
    );
  }

  void _onEdit(BuildContext context, OccupiedSeatInfo seat) {
    showEditSeatDialog(
      context,
      seatInfo: seat,
      library: widget.library,
      customSlots: _customSlots,
      cubit: context.read<OccupiedSeatsCubit>(),
    );
  }

  void _onSendReminder(BuildContext context, OccupiedSeatInfo seat) {
    sendOccupiedSeatsReminder(
      context,
      seatInfo: seat,
      library: widget.library,
      customSlots: _customSlots,
    );
  }

  void _onConvertPending(
    BuildContext context,
    OccupiedSeatInfo seat, {
    bool forUpcomingPlan = false,
  }) {
    final effectiveSeat = forUpcomingPlan && seat.upcomingMembership != null
        ? OccupiedSeatInfo(
            seatId: seat.seatId,
            membership: seat.upcomingMembership!,
            studentName: seat.studentName,
            studentPhone: seat.studentPhone,
            studentAvatarUrl: seat.studentAvatarUrl,
            upcomingMembership: null,
          )
        : seat;

    showConvertPendingDialog(
      context,
      seatInfo: effectiveSeat,
      customSlots: _customSlots,
      onSnackBar: (message, {required isError}) =>
          showOccupiedSeatsSnackBar(context, message, isError: isError),
      onExecute:
          (
            seatInfo,
            ownerId, {
            amountPaid,
            isPartial = false,
            notes,
            discount = 0.0,
            required PaymentMode paymentMethod,
          }) => executeConvertPending(
            context,
            seatInfo: seatInfo,
            ownerId: ownerId,
            customSlots: _customSlots,
            cubit: context.read<OccupiedSeatsCubit>(),
            onSnackBar: (message, {required isError}) =>
                showOccupiedSeatsSnackBar(context, message, isError: isError),
            amountPaid: amountPaid,
            isPartial: isPartial,
            notes: notes,
            discount: discount,
            paymentMethod: paymentMethod,
          ),
    );
  }

  void _onReassign(BuildContext context, OccupiedSeatInfo seat) {
    navigateToReassign(
      context,
      seatInfo: seat,
      library: widget.library,
      cubit: context.read<OccupiedSeatsCubit>(),
    );
  }

  Future<void> _onRefund(BuildContext context, OccupiedSeatInfo seat) async {
    await handleOccupiedSeatsRefund(
      context,
      seatInfo: seat,
      cubit: context.read<OccupiedSeatsCubit>(),
    );
  }
}

/// Section title with horizontal page padding for use inside list headers.
class PremiumSectionHeaderPadded extends StatelessWidget {
  const PremiumSectionHeaderPadded({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: PremiumSectionHeader(title),
  );
}

/// Pulsing skeleton shown while slots / residents load.
class _ResidentsSkeleton extends StatefulWidget {
  const _ResidentsSkeleton();

  @override
  State<_ResidentsSkeleton> createState() => _ResidentsSkeletonState();
}

class _ResidentsSkeletonState extends State<_ResidentsSkeleton>
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

  Widget _block(double h, {double? w, double r = 20}) => Container(
    height: h,
    width: w,
    decoration: BoxDecoration(
      color: AppUIConstants.surfaceMuted,
      borderRadius: BorderRadius.circular(r),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_c),
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          for (var i = 0; i < 4; i++) ...[
            _block(190, r: 16),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
