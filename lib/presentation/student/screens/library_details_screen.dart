import 'package:carousel_slider/carousel_slider.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/entities/custom_slot.dart';
import '../../../domain/entities/library.dart';
import '../../../domain/entities/library_stats.dart';
import '../../../domain/entities/slot.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/usecases/get_student_memberships.dart';
import '../../core/app_ui_constants.dart';
import '../../core/widgets/premium_kit.dart';
import '../cubit/library_details_cubit.dart';
import '../cubit/library_details_state.dart';
import '../widgets/fullscreen_image_viewer.dart';
import 'bed_request_screen.dart';

/// Unified PG Details Screen.
/// Shows complete PG info regardless of navigation source.
/// If user is a resident (member), shows an additional "Your Stay" section.
class LibraryDetailsScreen extends StatelessWidget {
  const LibraryDetailsScreen({
    super.key,
    required this.library,
    required this.userId,
    this.membershipInfo,
  });

  final Library library;
  final String userId;

  /// If null, user is viewing as non-member (explore mode).
  /// If provided, user is a member and we show member-specific info.
  final StudentMembershipInfo? membershipInfo;

  bool get isMember => membershipInfo != null && membershipInfo!.isActive;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<LibraryDetailsCubit>()
            ..loadLibrary(libraryId: library.id, userId: userId),
      child: BlocBuilder<LibraryDetailsCubit, LibraryDetailsState>(
        builder: (context, state) {
          final hasPhone = library.ownerPhone != null;
          return Scaffold(
            backgroundColor: AppUIConstants.background,
            body: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(
                            child: _PhotoHeader(
                              library: library,
                              isMember: isMember,
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            sliver: SliverList(
                              delegate: SliverChildListDelegate([
                                _TitleBlock(
                                  library: library,
                                  stats: state.stats,
                                  customSlots: state.customSlots,
                                  loading: state.isLoading,
                                ),
                                if (isMember) ...[
                                  const PremiumSectionHeader('Your stay'),
                                  _MembershipInfoCard(
                                    membershipInfo: membershipInfo!,
                                  ),
                                  const SizedBox(height: 12),
                                  _SessionInfoCard(
                                    membershipInfo: membershipInfo!,
                                  ),
                                ],
                                if (state.customSlots.isNotEmpty) ...[
                                  const PremiumSectionHeader('Room types'),
                                  _PricingCard(customSlots: state.customSlots),
                                ],
                                const PremiumSectionHeader('Amenities'),
                                _FacilitiesCard(library: library),
                                if (state.stats != null &&
                                    state.stats!.totalSeats > 0) ...[
                                  const PremiumSectionHeader(
                                    'Bed availability',
                                  ),
                                  _BedAvailabilityCard(stats: state.stats!),
                                ],
                                const PremiumSectionHeader('About this PG'),
                                _AboutCard(library: library),
                                if (hasPhone) ...[
                                  const PremiumSectionHeader('Contact'),
                                  _ContactCard(library: library),
                                ],
                                // Room for the sticky CTA (attendance / request a bed).
                                const SizedBox(height: 90),
                              ]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Floating back button (always reachable)
                Positioned(
                  top: 0,
                  left: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _CircleButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _StickyCta(
                    isMember: isMember,
                    library: library,
                    onRequestBed: () => _openBedRequest(context),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openBedRequest(BuildContext context) async {
    final userResult = await sl<AuthRepository>().getCurrentUser();
    final user = userResult.fold((_) => null, (u) => u);
    if (!context.mounted) return;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in again to request a bed.')),
      );
      return;
    }
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BedRequestScreen(library: library, user: user),
      ),
    );
    if (sent == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bed request sent. The owner will review it soon.'),
        ),
      );
    }
  }
}

// ============================================================================
// HEADER
// ============================================================================

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppUIConstants.background.withValues(alpha: 0.6),
      shape: CircleBorder(
        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}

/// Full-bleed photo carousel with gradient, page dots and photo counter.
class _PhotoHeader extends StatefulWidget {
  const _PhotoHeader({required this.library, required this.isMember});

  final Library library;
  final bool isMember;

  @override
  State<_PhotoHeader> createState() => _PhotoHeaderState();
}

class _PhotoHeaderState extends State<_PhotoHeader> {
  int _index = 0;

  List<String> get _photos => widget.library.photos;

  void _openFullscreen(int index) {
    HapticFeedback.selectionClick();
    FullScreenImageViewer.open(
      context,
      images: _photos,
      initialIndex: index,
      heroTagPrefix: 'pg_photo',
    );
  }

  @override
  Widget build(BuildContext context) {
    const height = 300.0;
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_photos.isEmpty)
            Container(
              color: AppUIConstants.surfaceMuted,
              child: const Center(
                child: Icon(
                  Icons.apartment_rounded,
                  size: 72,
                  color: AppUIConstants.textTertiary,
                ),
              ),
            )
          else
            CarouselSlider.builder(
              itemCount: _photos.length,
              itemBuilder: (context, index, realIndex) {
                return GestureDetector(
                  onTap: () => _openFullscreen(index),
                  child: Hero(
                    // URL as tag: unique per photo, avoids duplicate-tag
                    // crash when carousel loops.
                    tag: 'pg_photo_${_photos[index]}',
                    child: Image.network(
                      _photos[index],
                      width: double.infinity,
                      height: height,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: AppUIConstants.surfaceMuted,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: AppUIConstants.primaryLight,
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, _, _) => Container(
                        color: AppUIConstants.surfaceMuted,
                        child: const Icon(
                          Icons.broken_image_outlined,
                          color: AppUIConstants.textTertiary,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                );
              },
              options: CarouselOptions(
                height: height,
                viewportFraction: 1,
                autoPlay: _photos.length > 1,
                autoPlayInterval: const Duration(seconds: 4),
                autoPlayAnimationDuration: const Duration(milliseconds: 800),
                autoPlayCurve: Curves.fastOutSlowIn,
                onPageChanged: (index, reason) =>
                    setState(() => _index = index),
              ),
            ),
          // gradient so the title overlap + buttons are legible
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black54,
                    Colors.transparent,
                    Colors.transparent,
                    AppUIConstants.background,
                  ],
                  stops: [0, 0.28, 0.6, 1],
                ),
              ),
            ),
          ),
          if (widget.isMember)
            Positioned(
              top: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: const PremiumStatusPill(
                    'Your PG',
                    color: AppUIConstants.success,
                  ),
                ),
              ),
            ),
          if (_photos.length > 1)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _photos.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: i == _index ? 20 : 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i == _index
                            ? AppUIConstants.primaryLight
                            : Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_photos.isNotEmpty)
            Positioned(
              bottom: 38,
              right: 16,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppUIConstants.background.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(
                      AppUIConstants.radiusFull,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.zoom_out_map_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${_index + 1}/${_photos.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
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
  }
}

/// Name, location, headline numbers (rent from / vacant beds / occupancy).
class _TitleBlock extends StatelessWidget {
  const _TitleBlock({
    required this.library,
    required this.stats,
    required this.customSlots,
    required this.loading,
  });

  final Library library;
  final LibraryStats? stats;
  final List<CustomSlot> customSlots;
  final bool loading;

  double? get _rentFrom {
    final prices = customSlots.map((s) => s.price).where((p) => p > 0);
    if (prices.isNotEmpty) {
      return prices.reduce((a, b) => a < b ? a : b);
    }
    return library.customMonthlyPrice;
  }

  @override
  Widget build(BuildContext context) {
    final rent = _rentFrom;
    final available = stats?.availableSeats;
    final total = stats?.totalSeats ?? library.capacity;
    final occupancy = stats == null || total <= 0
        ? null
        : ((total - (available ?? 0).clamp(0, total)) / total * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          library.name,
          style: const TextStyle(
            color: AppUIConstants.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(
              Icons.location_on_rounded,
              size: 16,
              color: AppUIConstants.primaryLight,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                library.area ?? library.fullAddress ?? 'Location not listed',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppUIConstants.bodyMd,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _HeadlineTile(
                icon: Icons.currency_rupee_rounded,
                value: rent != null ? rent.toStringAsFixed(0) : '--',
                label: 'Rent from / mo',
                color: AppUIConstants.primaryLight,
                loading: loading && rent == null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _HeadlineTile(
                icon: Icons.bed_rounded,
                value: available != null
                    ? '${available < 0 ? 0 : available}'
                    : '--',
                label: 'Beds vacant',
                color: (available ?? 1) <= 0
                    ? AppUIConstants.error
                    : AppUIConstants.success,
                loading: loading && stats == null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _HeadlineTile(
                icon: Icons.pie_chart_rounded,
                value: occupancy != null ? '$occupancy%' : '--',
                label: 'Occupied',
                color: AppUIConstants.primaryLight,
                loading: loading && stats == null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeadlineTile extends StatelessWidget {
  const _HeadlineTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.loading,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: loading
                ? Container(
                    key: const ValueKey('sk'),
                    width: 40,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppUIConstants.surfaceMuted,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  )
                : Text(
                    value,
                    key: ValueKey(value),
                    style: AppUIConstants.statValue.copyWith(fontSize: 22),
                  ),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppUIConstants.caption),
        ],
      ),
    );
  }
}

// ============================================================================
// SECTIONS
// ============================================================================

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.library});

  final Library library;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.home_work_outlined,
            label: 'Address',
            value: library.fullAddress ?? 'Not specified',
          ),
          if (library.area != null) ...[
            const _RowDivider(),
            _InfoRow(
              icon: Icons.map_outlined,
              label: 'Locality',
              value: library.area!,
            ),
          ],
          const _RowDivider(),
          _InfoRow(
            icon: Icons.bed_outlined,
            label: 'Total capacity',
            value: '${library.capacity} beds',
          ),
        ],
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 12),
    child: Divider(height: 1, color: AppUIConstants.divider),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: AppUIConstants.primarySoft,
            borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
          ),
          child: Icon(icon, size: 18, color: AppUIConstants.primaryLight),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppUIConstants.caption),
              const SizedBox(height: 3),
              Text(value, style: AppUIConstants.bodyLg),
            ],
          ),
        ),
      ],
    );
  }
}

/// Room / sharing options with rent per month.
class _PricingCard extends StatelessWidget {
  const _PricingCard({required this.customSlots});

  final List<CustomSlot> customSlots;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final slot in customSlots)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: PremiumCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: AppUIConstants.surfaceMuted,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.king_bed_rounded,
                      color: AppUIConstants.primaryLight,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          slot.name,
                          style: AppUIConstants.bodyLg.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(slot.displayTime, style: AppUIConstants.bodySm),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${slot.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: AppUIConstants.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Text('per month', style: AppUIConstants.caption),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Amenities grid: every amenity shown, unavailable ones dimmed.
class _FacilitiesCard extends StatelessWidget {
  const _FacilitiesCard({required this.library});

  final Library library;

  static IconData _icon(LibraryFacility f) {
    switch (f) {
      case LibraryFacility.wifi:
        return Icons.wifi_rounded;
      case LibraryFacility.ac:
        return Icons.ac_unit_rounded;
      case LibraryFacility.powerBackup:
        return Icons.bolt_rounded;
      case LibraryFacility.washroom:
        return Icons.bathtub_outlined;
      case LibraryFacility.drinkingWater:
        return Icons.water_drop_rounded;
      case LibraryFacility.cctv:
        return Icons.videocam_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = library.enabledFacilities.toSet();
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.0,
      children: [
        for (final f in LibraryFacility.values)
          _AmenityTile(
            icon: _icon(f),
            label: f.displayName,
            available: enabled.contains(f),
          ),
      ],
    );
  }
}

class _AmenityTile extends StatelessWidget {
  const _AmenityTile({
    required this.icon,
    required this.label,
    required this.available,
  });

  final IconData icon;
  final String label;
  final bool available;

  @override
  Widget build(BuildContext context) {
    final color = available
        ? AppUIConstants.primaryLight
        : AppUIConstants.textTertiary;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: available ? AppUIConstants.primarySoft : AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(
          color: available
              ? AppUIConstants.primary.withValues(alpha: 0.5)
              : AppUIConstants.border,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 26, color: color),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: available
                  ? AppUIConstants.textPrimary
                  : AppUIConstants.textTertiary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              decoration: available ? null : TextDecoration.lineThrough,
              decorationColor: AppUIConstants.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Visual bed map: one dot per bed (capped), plus legend and totals.
class _BedAvailabilityCard extends StatelessWidget {
  const _BedAvailabilityCard({required this.stats});

  final LibraryStats stats;

  @override
  Widget build(BuildContext context) {
    final total = stats.totalSeats;
    final occupied = stats.occupiedSeats.clamp(0, total);
    final reserved = stats.reservedSeats.clamp(0, total - occupied);
    final vacant = (total - occupied - reserved).clamp(0, total);
    const cap = 60;
    final shown = total > cap ? cap : total;
    // Scale to shown beds when capped.
    int scale(int n) => total > cap ? (n * cap / total).round() : n;
    final occShown = scale(occupied);
    final resShown = scale(reserved);

    Color colorAt(int i) {
      if (i < occShown) return AppUIConstants.error;
      if (i < occShown + resShown) return AppUIConstants.warning;
      return AppUIConstants.success;
    }

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _Legend(
                  color: AppUIConstants.success,
                  value: vacant,
                  label: 'Vacant',
                ),
              ),
              Expanded(
                child: _Legend(
                  color: AppUIConstants.warning,
                  value: reserved,
                  label: 'Reserved',
                ),
              ),
              Expanded(
                child: _Legend(
                  color: AppUIConstants.error,
                  value: occupied,
                  label: 'Occupied',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < shown; i++)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 250 + (i * 12)),
                  curve: Curves.easeOutBack,
                  builder: (_, v, child) =>
                      Transform.scale(scale: v.clamp(0.0, 1.2), child: child),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: colorAt(i).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: colorAt(i).withValues(alpha: 0.8),
                      ),
                    ),
                    child: Icon(Icons.bed_rounded, size: 12, color: colorAt(i)),
                  ),
                ),
            ],
          ),
          if (total > cap) ...[
            const SizedBox(height: 8),
            Text(
              'Each icon represents about ${(total / cap).ceil()} beds',
              style: AppUIConstants.caption,
            ),
          ],
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.value,
    required this.label,
  });

  final Color color;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label, style: AppUIConstants.caption),
          ],
        ),
        const SizedBox(height: 4),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.toDouble()),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (_, v, _) => Text(
            '${v.round()}',
            style: AppUIConstants.statValue.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// Contact card - tap to call the PG owner.
class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.library});

  final Library library;

  @override
  Widget build(BuildContext context) {
    if (library.ownerPhone == null) return const SizedBox.shrink();
    return PremiumCard(
      onTap: () => _launchPhoneDialer(library.ownerPhone!),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppUIConstants.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: AppUIConstants.success,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('PG owner', style: AppUIConstants.caption),
                const SizedBox(height: 2),
                Text(
                  library.ownerPhone!,
                  style: AppUIConstants.bodyLg.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.call_rounded,
            color: AppUIConstants.success,
            size: 22,
          ),
        ],
      ),
    );
  }
}

Future<void> _launchPhoneDialer(String phoneNumber) async {
  final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
  final uri = Uri(scheme: 'tel', path: cleanNumber);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  }
}

// ============================================================================
// STICKY CTA
// ============================================================================

class _StickyCta extends StatelessWidget {
  const _StickyCta({
    required this.isMember,
    required this.library,
    required this.onRequestBed,
  });

  final bool isMember;
  final Library library;
  final VoidCallback onRequestBed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        border: const Border(top: BorderSide(color: AppUIConstants.border)),
        boxShadow: [AppUIConstants.shadowLg],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              if (library.ownerPhone != null) ...[
                SizedBox(
                  height: 50,
                  width: 50,
                  child: OutlinedButton(
                    onPressed: () => _launchPhoneDialer(library.ownerPhone!),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      foregroundColor: AppUIConstants.primaryLight,
                      side: const BorderSide(color: AppUIConstants.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppUIConstants.radiusMd,
                        ),
                      ),
                    ),
                    child: const Icon(Icons.call_rounded),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              // Always offer a bed request, like Library Manager's
              // "Book a Seat" / "Request a Seat" CTA.
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      onRequestBed();
                    },
                    icon: const Icon(Icons.bed_rounded, size: 20),
                    style: AppUIConstants.accentButtonStyle,
                    label: Text(
                      isMember ? 'Request another bed' : 'Request a bed',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// MEMBER-SPECIFIC WIDGETS
// ============================================================================

/// Stay summary: bed, plan, days left, validity.
class _MembershipInfoCard extends StatelessWidget {
  const _MembershipInfoCard({required this.membershipInfo});

  final StudentMembershipInfo membershipInfo;

  @override
  Widget build(BuildContext context) {
    final daysRemaining = membershipInfo.daysRemaining;
    final statusColor = membershipInfo.isActive
        ? AppUIConstants.success
        : AppUIConstants.warning;
    final daysColor = daysRemaining <= 7
        ? AppUIConstants.warning
        : AppUIConstants.textPrimary;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Your stay', style: AppUIConstants.headingSm),
              ),
              PremiumStatusPill(
                membershipInfo.isActive ? 'Active' : 'Pending',
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: daysRemaining.toDouble()),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (_, v, _) => Text(
                  '${v.round()}',
                  style: TextStyle(
                    color: daysColor,
                    fontSize: 44,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 5),
                child: Text('days left', style: AppUIConstants.bodyMd),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppUIConstants.divider),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatColumn(
                  label: 'Bed',
                  value: membershipInfo.seatNumber,
                ),
              ),
              Expanded(
                child: _StatColumn(
                  label: 'Plan',
                  value: membershipInfo.membership.plan.name.toUpperCase(),
                ),
              ),
              Expanded(
                child: _StatColumn(
                  label: 'Valid till',
                  value: membershipInfo.validTillFormatted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppUIConstants.caption),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppUIConstants.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

/// Shows the resident's assigned timing.
class _SessionInfoCard extends StatelessWidget {
  const _SessionInfoCard({required this.membershipInfo});

  final StudentMembershipInfo membershipInfo;

  @override
  Widget build(BuildContext context) {
    final customSlot = membershipInfo.customSlot;
    final derivedSlot = customSlot != null
        ? (customSlot.startTimeOfDay.hour < 14 ? Slot.morning : Slot.evening)
        : membershipInfo.membership.slot;

    final slotName = membershipInfo.slotName;
    final sessionTiming = membershipInfo.sessionTiming;

    final isMorning =
        derivedSlot == Slot.morning ||
        (customSlot != null && customSlot.startTimeOfDay.hour < 14);

    return PremiumCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppUIConstants.surfaceMuted,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isMorning ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded,
              color: AppUIConstants.primaryLight,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your timing', style: AppUIConstants.caption),
                const SizedBox(height: 2),
                Text(slotName, style: AppUIConstants.headingSm),
                const SizedBox(height: 2),
                Text(sessionTiming, style: AppUIConstants.bodySm),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
