import 'package:flutter/material.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/entities/promo_offer.dart';
import '../../../domain/usecases/promo/promo_usecases.dart';
import '../../core/app_ui_constants.dart';
import '../widgets/promo_analytics_dialog.dart';
import '../widgets/promo_card.dart';
import '../widgets/promo_form_dialog.dart';

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
        title: const Text('Promo Offers'),
        backgroundColor: AppUIConstants.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
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
        label: const Text('New Promo'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_promos.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadPromos,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppUIConstants.spacingLg),
        itemCount: _promos.length,
        itemBuilder: (context, index) => PromoCard(
          promo: _promos[index],
          onEdit: () => _showPromoFormDialog(context, promo: _promos[index]),
          onToggle: () => _togglePromoStatus(_promos[index]),
          onDelete: () => _deletePromo(_promos[index]),
          onViewAnalytics: () => _showAnalyticsDialog(_promos[index]),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: AppUIConstants.error,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(_error!, style: AppUIConstants.bodyMd),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadPromos,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_offer_outlined,
            color: AppUIConstants.textTertiary,
            size: 64,
          ),
          const SizedBox(height: AppUIConstants.spacingLg),
          Text('No promos yet', style: AppUIConstants.headingSm),
          const SizedBox(height: AppUIConstants.spacingSm),
          Text(
            'Create your first promo offer',
            style: AppUIConstants.bodyMd,
          ),
        ],
      ),
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
        title: const Text('Delete Promo?'),
        content: Text('This will permanently delete "${promo.title}".'),
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
        backgroundColor:
            isError ? AppUIConstants.error : AppUIConstants.success,
      ),
    );
  }
}
