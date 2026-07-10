import 'dart:async';

import 'package:flutter/material.dart';
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

/// Tenant stay screen with tabs: ALL | Plans | Pending | Partial | Expired.
/// Shows active, pending, and expired tenant stays in each tab.
class OccupiedSeatsScreen extends StatefulWidget {
  const OccupiedSeatsScreen({super.key, required this.library});

  final Library library;

  @override
  State<OccupiedSeatsScreen> createState() => _OccupiedSeatsScreenState();
}

class _OccupiedSeatsScreenState extends State<OccupiedSeatsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
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

    // Initialize tab controller: ALL | Room/bed plans | Pending | Partial Payment | Expired.
    final tabCount = 4 + _customSlots.length;
    _tabController = TabController(length: tabCount, vsync: this);

    // Load occupied beds
    if (!mounted) return;
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
    _tabController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    context.read<OccupiedSeatsCubit>().clearSearch();
    _searchFocusNode.unfocus();
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      body: _isLoadingSlots
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildContent()),
              ],
            ),
    );
  }

  // -------------------------------------------------------------------------
  // Header
  // -------------------------------------------------------------------------

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppUIConstants.primary, AppUIConstants.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title row
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: Colors.white,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tenants',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.library.name,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
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
                                  color: Colors.white,
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
                              color: Colors.white,
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
                    color: Colors.white,
                    tooltip: 'Refresh',
                  ),
                  IconButton(
                    onPressed: () => showOccupiedSeatsSortDialog(context),
                    icon: const Icon(Icons.sort_rounded),
                    color: Colors.white,
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

  // -------------------------------------------------------------------------
  // Search bar
  // -------------------------------------------------------------------------

  Widget _buildSearchBar() {
    return BlocBuilder<OccupiedSeatsCubit, OccupiedSeatsState>(
      buildWhen: (prev, curr) => prev.hasActiveSearch != curr.hasActiveSearch,
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
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
                hintStyle: TextStyle(
                  color: AppUIConstants.textTertiary,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppUIConstants.textTertiary,
                  size: 22,
                ),
                suffixIcon: state.hasActiveSearch
                    ? IconButton(
                        onPressed: _clearSearch,
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppUIConstants.textTertiary.withValues(
                              alpha: 0.2,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: AppUIConstants.textSecondary,
                            size: 14,
                          ),
                        ),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // Tab bar
  // -------------------------------------------------------------------------

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      isScrollable: true,
      indicatorColor: Colors.white,
      indicatorWeight: 3,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      unselectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 13,
      ),
      tabAlignment: TabAlignment.start,
      labelPadding: const EdgeInsets.symmetric(horizontal: 14),
      tabs: [
        const Tab(text: 'All'),
        ..._customSlots.map((slot) => Tab(text: slot.name)),
        const Tab(text: 'Pending'),
        const Tab(text: 'Partial'),
        const Tab(text: 'Expired'),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Tab content
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
          return const Center(child: CircularProgressIndicator());
        }

        if (state.status == OccupiedSeatsStatus.error) {
          return OccupiedSeatsErrorView(
            message: state.failure?.message ?? 'Failed to load',
            onRetry: () => context.read<OccupiedSeatsCubit>().refresh(),
          );
        }

        final allSeats = sortOccupiedSeats(
          state.searchSeats(state.occupiedSeats),
          state.sortBy,
        );
        final hasActiveSearch = state.hasActiveSearch;

        return TabBarView(
          controller: _tabController,
          children: [
            // "All" tab
            _buildSeatsList(
              seats: allSeats,
              state: state,
              hasActiveSearch: hasActiveSearch,
            ),
            // Room/bed plan tabs
            ..._customSlots.map(
              (slot) => _buildSeatsList(
                seats: sortOccupiedSeats(
                  state.searchSeats(_filterBySlot(state.occupiedSeats, slot)),
                  state.sortBy,
                ),
                state: state,
                hasActiveSearch: hasActiveSearch,
                emptyMessage: 'No tenants in ${slot.name}',
              ),
            ),
            // Pending tab
            _buildSeatsList(
              seats: sortOccupiedSeats(
                state.searchSeats(
                  state.occupiedSeats.where((s) => s.isReserved).toList(),
                ),
                state.sortBy,
              ),
              state: state,
              hasActiveSearch: hasActiveSearch,
              emptyMessage: 'No pending tenants',
              emptyIcon: Icons.hourglass_empty_rounded,
            ),
            // Partial Payment tab
            _buildSeatsList(
              seats: sortOccupiedSeats(
                state.searchSeats(
                  state.occupiedSeats
                      .where((s) => s.membership.hasPartialPayment)
                      .toList(),
                ),
                state.sortBy,
              ),
              state: state,
              hasActiveSearch: hasActiveSearch,
              emptyMessage: 'No partial payments',
              emptyIcon: Icons.payment_outlined,
            ),
            // Expired tab
            _buildSeatsList(
              seats: sortOccupiedSeats(
                state.searchSeats(state.expiredSeats),
                state.sortBy,
              ),
              state: state,
              hasActiveSearch: hasActiveSearch,
              emptyMessage: 'No expired stays',
              emptyIcon: Icons.event_busy_rounded,
              showExpired: true,
              includeReassign: true,
            ),
          ],
        );
      },
    );
  }

  /// Builds a single tab's bed list, wiring callbacks to action handlers.
  Widget _buildSeatsList({
    required List<OccupiedSeatInfo> seats,
    required OccupiedSeatsState state,
    required bool hasActiveSearch,
    String? emptyMessage,
    IconData? emptyIcon,
    bool showExpired = false,
    bool includeReassign = true,
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
