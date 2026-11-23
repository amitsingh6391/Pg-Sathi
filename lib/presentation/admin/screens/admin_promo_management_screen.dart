import 'package:material_ui/material_ui.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/entities/promo_offer.dart';
import '../../../domain/usecases/promo/promo_usecases.dart';
import '../../core/app_ui_constants.dart';
import '../widgets/promo_analytics_dialog.dart';
import '../widgets/promo_card.dart';
import '../widgets/promo_form_dialog.dart';
import '../widgets/promo_ticket.dart';

enum _PromoFilter { all, live, paused, ended }

/// Admin screen for managing promotional offers.
class AdminPromoManagementScreen extends StatefulWidget {
  const AdminPromoManagementScreen({super.key});

  @override
  State<AdminPromoManagementScreen> createState() =>
      _AdminPromoManagementScreenState();
}

class _AdminPromoManagementScreenState
    extends State<AdminPromoManagementScreen> {
  List<PromoOffer> _promos = [];
  bool _isLoading = true;
  String? _error;
  _PromoFilter _filter = _PromoFilter.all;

  @override
  void initState() {
    super.initState();
    _loadPromos();
  }

  Future<void> _loadPromos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final getAllPromos = sl<GetAllPromos>();
    final result = await getAllPromos();

    result.fold(
      (failure) => setState(() {
        _error = failure.message ?? 'Failed to load promos';
        _isLoading = false;
      }),
      (promos) => setState(() {
        _promos = promos;
        _isLoading = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      appBar: AppBar(
        title: const Text('Promo offers'),
        backgroundColor: AppUIConstants.surface,
        foregroundColor: AppUIConstants.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadPromos,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPromoFormDialog(context),
        backgroundColor: AppUIConstants.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New promo'),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: KeyedSubtree(
          key: ValueKey(
            _isLoading ? 'loading' : (_error != null ? 'error' : 'data'),
          ),
          child: _buildBody(),
        ),
      ),
    );
  }

  bool _matches(PromoOffer p) {
    final now = DateTime.now();
    switch (_filter) {
      case _PromoFilter.all:
        return true;
      case _PromoFilter.live:
        return p.isValidForDisplay;
      case _PromoFilter.paused:
        return !p.isActive;
      case _PromoFilter.ended:
        return p.endDate != null && now.isAfter(p.endDate!);
    }
  }

  String _filterLabel(_PromoFilter f) {
    switch (f) {
      case _PromoFilter.all:
        return 'All (${_promos.length})';
      case _PromoFilter.live:
        return 'Live (${_promos.where((p) => p.isValidForDisplay).length})';
      case _PromoFilter.paused:
        return 'Paused (${_promos.where((p) => !p.isActive).length})';
      case _PromoFilter.ended:
        final now = DateTime.now();
        return 'Ended (${_promos.where((p) => p.endDate != null && now.isAfter(p.endDate!)).length})';
    }
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const SkeletonList();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_promos.isEmpty) {
      return _buildEmptyState();
    }

    final visible = _promos.where(_matches).toList();

    return RefreshIndicator(
      color: AppUIConstants.primaryLight,
      backgroundColor: AppUIConstants.surface,
      onRefresh: _loadPromos,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppUIConstants.spacingLg,
          AppUIConstants.spacingMd,
          AppUIConstants.spacingLg,
          96,
        ),
        children: [
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final f in _PromoFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_filterLabel(f)),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                      showCheckmark: false,
                      backgroundColor: AppUIConstants.surfaceMuted,
                      selectedColor: AppUIConstants.primarySoft,
                      side: BorderSide(
                        color: _filter == f
                            ? AppUIConstants.primaryLight
                            : AppUIConstants.border,
                      ),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: _filter == f
                            ? AppUIConstants.textPrimary
                            : AppUIConstants.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppUIConstants.spacingMd),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: AdminEmptyState(
                icon: Icons.filter_alt_off_rounded,
                title: 'Nothing here',
                message: 'No promos match this filter.',
              ),
            )
          else
            for (final promo in visible)
              PromoCard(
                key: ValueKey(promo.id),
                promo: promo,
                onEdit: () => _showPromoFormDialog(context, promo: promo),
                onToggle: () => _togglePromoStatus(promo),
                onDelete: () => _deletePromo(promo),
                onViewAnalytics: () => _showAnalyticsDialog(promo),
              ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return AdminEmptyState(
      icon: Icons.cloud_off_rounded,
      color: AppUIConstants.error,
      title: 'Could not load promos',
      message: _error!,
      actionLabel: 'Retry',
      actionIcon: Icons.refresh_rounded,
      onAction: _loadPromos,
    );
  }

  Widget _buildEmptyState() {
    return AdminEmptyState(
      icon: Icons.local_offer_outlined,
      title: 'No promos yet',
      message:
          'Create a popup offer to reach owners right from their dashboard.',
      actionLabel: 'Create first promo',
      onAction: () => _showPromoFormDialog(context),
    );
  }

  Future<void> _showPromoFormDialog(
    BuildContext context, {
    PromoOffer? promo,
  }) async {
    final result = await showDialog<PromoOffer>(
      context: context,
      builder: (ctx) => PromoFormDialog(promo: promo),
    );

    if (result != null) {
      await _loadPromos();
    }
  }

  Future<void> _togglePromoStatus(PromoOffer promo) async {
    final updatePromo = sl<UpdatePromo>();
    final updated = PromoOffer(
      id: promo.id,
      title: promo.title,
      imageUrl: promo.imageUrl,
      ctaText: promo.ctaText,
      ctaAction: promo.ctaAction,
      ctaValue: promo.ctaValue,
      description: promo.description,
      targetAudience: promo.targetAudience,
      displayFrequency: promo.displayFrequency,
      startDate: promo.startDate,
      endDate: promo.endDate,
      priority: promo.priority,
      isActive: !promo.isActive,
      createdAt: promo.createdAt,
    );

    final result = await updatePromo(updated);
    result.fold(
      (failure) => _showSnackBar('Failed: ${failure.message}', isError: true),
      (_) {
        _showSnackBar(
          updated.isActive ? 'Promo activated' : 'Promo deactivated',
        );
        _loadPromos();
      },
    );
  }

  Future<void> _deletePromo(PromoOffer promo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppUIConstants.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        ),
        title: const Text('Delete promo?', style: AppUIConstants.headingMd),
        content: Text(
          'This will permanently delete "${promo.title}".',
          style: AppUIConstants.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppUIConstants.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final deletePromo = sl<DeletePromo>();
    final result = await deletePromo(promo.id);
    result.fold(
      (failure) => _showSnackBar('Failed: ${failure.message}', isError: true),
      (_) {
        _showSnackBar('Promo deleted');
        _loadPromos();
      },
    );
  }

  void _showAnalyticsDialog(PromoOffer promo) {
    showDialog(
      context: context,
      builder: (ctx) => PromoAnalyticsDialog(promo: promo),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError
            ? AppUIConstants.error
            : AppUIConstants.success,
      ),
    );
  }
}
