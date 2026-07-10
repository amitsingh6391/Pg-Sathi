import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/entities/custom_slot.dart';
import '../../../domain/entities/library.dart';
import '../../../domain/entities/slot.dart';
import '../../../domain/usecases/get_student_memberships.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/attendance_history_cubit.dart';
import '../cubit/library_details_cubit.dart';
import '../cubit/library_details_state.dart';
import '../widgets/fullscreen_image_viewer.dart';
import 'attendance_details_screen.dart';

/// Unified Library Details Screen.
/// Shows complete library info regardless of navigation source.
/// If user is a member, shows additional member-specific section.
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
          return Scaffold(
            backgroundColor: AppUIConstants.background,
            body: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                _buildAppBar(context),
                SliverPadding(
                  padding: const EdgeInsets.all(AppUIConstants.spacingXl),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // ============================================
                      // SECTION 1: PHOTOS CAROUSEL (If available)
                      // ============================================
                      if (library.photos.isNotEmpty) ...[
                        _LibraryPhotosCarousel(photos: library.photos),
                        const SizedBox(height: AppUIConstants.spacingLg),
                      ],

                      // ============================================
                      // SECTION 2: LIBRARY INFO (Always visible)
                      // ============================================
                      _LibraryInfoCard(library: library),
                      const SizedBox(height: AppUIConstants.spacingLg),

                      const SizedBox(height: AppUIConstants.spacingLg),

                      // ============================================
                      // SECTION 3: PRICING (Always visible)
                      // ============================================
                      _PricingCard(
                        library: library,
                        customSlots: state.customSlots,
                      ),
                      const SizedBox(height: AppUIConstants.spacingLg),

                      // ============================================
                      // SECTION 4: FACILITIES (Always visible)
                      // ============================================
                      _FacilitiesCard(library: library),
                      const SizedBox(height: AppUIConstants.spacingLg),

                      // ============================================
                      // SECTION 5: SEAT AVAILABILITY (Always visible)
                      // ============================================
                      _SeatAvailabilityCard(
                        library: library,
                        customSlots: state.customSlots,
                      ),
                      const SizedBox(height: AppUIConstants.spacingLg),

                      // ============================================
                      // SECTION 6: CONTACT (Always visible)
                      // ============================================
                      _ContactCard(library: library),

                      // ============================================
                      // SECTION 7: MEMBER SECTION (Only for members)
                      // ============================================
                      if (isMember) ...[
                        const SizedBox(height: AppUIConstants.spacing2Xl),
                        const _SectionDivider(label: 'Your Membership'),
                        const SizedBox(height: AppUIConstants.spacingLg),

                        _MembershipInfoCard(membershipInfo: membershipInfo!),
                        const SizedBox(height: AppUIConstants.spacingLg),

                        _SessionInfoCard(membershipInfo: membershipInfo!),
                        const SizedBox(height: AppUIConstants.spacingLg),

                        // Attendance CTA
                        _AttendanceCTA(
                          onTap: () => _navigateToAttendance(context),
                        ),
                      ],

                      const SizedBox(height: 40),
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: AppUIConstants.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          color: AppUIConstants.primary,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(56, 40, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isMember)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppUIConstants.success,
                        borderRadius: BorderRadius.circular(
                          AppUIConstants.radiusFull,
                        ),
                      ),
                      child: const Text(
                        'MEMBER',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Text(
                    library.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          library.area ?? library.fullAddress ?? 'Location',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToAttendance(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => sl<AttendanceHistoryCubit>(),
          child: AttendanceDetailsScreen(
            userId: userId,
            libraryId: library.id,
            libraryName: library.name,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SECTION WIDGETS
// ============================================================================

class _SectionDivider extends StatelessWidget {
  const _SectionDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppUIConstants.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: AppUIConstants.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: AppUIConstants.textSecondary,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppUIConstants.border)),
      ],
    );
  }
}

/// Library Info Card - Address, Capacity, Contact
class _LibraryInfoCard extends StatelessWidget {
  const _LibraryInfoCard({required this.library});

  final Library library;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppUIConstants.spacingLg),
      decoration: AppUIConstants.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('About', style: AppUIConstants.headingSm),
          const SizedBox(height: AppUIConstants.spacingLg),
          _InfoRow(
            label: 'Address',
            value: library.fullAddress ?? 'Not specified',
          ),
          if (library.area != null) ...[
            const SizedBox(height: AppUIConstants.spacingMd),
            _InfoRow(label: 'Area', value: library.area!),
          ],
          const SizedBox(height: AppUIConstants.spacingMd),
          _InfoRow(label: 'Capacity', value: '${library.capacity} seats'),
        ],
      ),
    );
  }
}

/// Pricing Card - Custom slot rates
class _PricingCard extends StatelessWidget {
  const _PricingCard({required this.library, this.customSlots = const []});

  final Library library;
  final List<CustomSlot> customSlots;

  @override
  Widget build(BuildContext context) {
    // Show pricing card only if there are custom slots with pricing
    if (customSlots.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppUIConstants.spacingLg),
      decoration: AppUIConstants.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pricing', style: AppUIConstants.headingSm),
          Text('per month', style: AppUIConstants.caption),
          const SizedBox(height: AppUIConstants.spacingLg),
          Wrap(
            spacing: AppUIConstants.spacingMd,
            runSpacing: AppUIConstants.spacingMd,
            children: customSlots.take(3).map((slot) {
              return SizedBox(
                width:
                    (MediaQuery.of(context).size.width -
                        (AppUIConstants.spacingLg * 2) -
                        (AppUIConstants.spacingMd * 2)) /
                    3,
                child: _PriceItem(label: slot.name, amount: slot.price),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _PriceItem extends StatelessWidget {
  const _PriceItem({
    required this.label,
    required this.amount,
  });

  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: AppUIConstants.caption),
        const SizedBox(height: 4),
        Text(
          '₹${amount.toStringAsFixed(0)}',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppUIConstants.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Facilities Card
class _FacilitiesCard extends StatelessWidget {
  const _FacilitiesCard({required this.library});

  final Library library;

  @override
  Widget build(BuildContext context) {
    final facilities = library.enabledFacilities;
    if (facilities.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppUIConstants.spacingLg),
      decoration: AppUIConstants.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Facilities', style: AppUIConstants.headingSm),
          const SizedBox(height: AppUIConstants.spacingLg),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: facilities
                .map((f) => _FacilityChip(facility: f))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _FacilityChip extends StatelessWidget {
  const _FacilityChip({required this.facility});

  final LibraryFacility facility;

  IconData get _icon {
    switch (facility) {
      case LibraryFacility.wifi:
        return Icons.wifi_outlined;
      case LibraryFacility.ac:
        return Icons.ac_unit_outlined;
      case LibraryFacility.powerBackup:
        return Icons.power_outlined;
      case LibraryFacility.washroom:
        return Icons.wc_outlined;
      case LibraryFacility.drinkingWater:
        return Icons.water_drop_outlined;
      case LibraryFacility.cctv:
        return Icons.videocam_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppUIConstants.background,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
        border: Border.all(color: AppUIConstants.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 14, color: AppUIConstants.textSecondary),
          const SizedBox(width: 6),
          Text(facility.displayName, style: AppUIConstants.bodySm),
        ],
      ),
    );
  }
}

/// Seat Availability Card
class _SeatAvailabilityCard extends StatelessWidget {
  const _SeatAvailabilityCard({
    required this.library,
    this.customSlots = const [],
  });

  final Library library;
  final List<CustomSlot> customSlots;

  @override
  Widget build(BuildContext context) {
    final hasCustomSlots = customSlots.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(AppUIConstants.spacingLg),
      decoration: AppUIConstants.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Seat Availability', style: AppUIConstants.headingSm),
          const SizedBox(height: AppUIConstants.spacingMd),
          // Custom slots only
          if (hasCustomSlots) ...[
            Wrap(
              spacing: AppUIConstants.spacingMd,
              runSpacing: AppUIConstants.spacingMd,
              children: customSlots.map((slot) {
                return _CustomAvailabilitySlot(slot: slot);
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _CustomAvailabilitySlot extends StatelessWidget {
  const _CustomAvailabilitySlot({required this.slot});

  final CustomSlot slot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppUIConstants.spacingMd),
      decoration: BoxDecoration(
        color: AppUIConstants.background,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
        border: Border.all(color: AppUIConstants.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            slot.name,
            style: AppUIConstants.caption.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            slot.displayTime,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 2),
          Text(
            '₹${slot.price.toStringAsFixed(0)}/month',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppUIConstants.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Contact Card - Tappable to call owner
class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.library});

  final Library library;

  Future<void> _launchPhoneDialer(String phoneNumber) async {
    // Clean the phone number
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: cleanNumber);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (library.ownerPhone == null) return const SizedBox.shrink();

    return InkWell(
      onTap: () => _launchPhoneDialer(library.ownerPhone!),
      borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppUIConstants.spacingLg),
        decoration: BoxDecoration(
          color: AppUIConstants.surface,
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
          border: Border.all(
            color: AppUIConstants.success.withValues(alpha: 0.2),
          ),
          boxShadow: [AppUIConstants.shadowSm],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppUIConstants.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.call_rounded,
                color: AppUIConstants.success,
                size: 22,
              ),
            ),
            const SizedBox(width: AppUIConstants.spacingLg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Contact Owner', style: AppUIConstants.caption),
                  const SizedBox(height: 2),
                  Text(
                    library.ownerPhone!,
                    style: AppUIConstants.bodyLg.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppUIConstants.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppUIConstants.success,
                borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.phone_in_talk_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Call',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// MEMBER-SPECIFIC WIDGETS
// ============================================================================

/// Membership Info Card (for members)
class _MembershipInfoCard extends StatelessWidget {
  const _MembershipInfoCard({required this.membershipInfo});

  final StudentMembershipInfo membershipInfo;

  @override
  Widget build(BuildContext context) {
    final daysRemaining = membershipInfo.daysRemaining;

    return Container(
      padding: const EdgeInsets.all(AppUIConstants.spacingLg),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(
          color: membershipInfo.isActive
              ? AppUIConstants.success.withValues(alpha: 0.3)
              : AppUIConstants.warning.withValues(alpha: 0.3),
        ),
        boxShadow: [AppUIConstants.shadowSm],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Membership', style: AppUIConstants.headingSm),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: membershipInfo.isActive
                      ? AppUIConstants.success.withValues(alpha: 0.1)
                      : AppUIConstants.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(
                    AppUIConstants.radiusFull,
                  ),
                ),
                child: Text(
                  membershipInfo.isActive ? 'Active' : 'Pending',
                  style: TextStyle(
                    color: membershipInfo.isActive
                        ? AppUIConstants.success
                        : AppUIConstants.warning,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppUIConstants.spacingLg),
          Row(
            children: [
              Expanded(
                child: _StatColumn(
                  label: 'Seat',
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
                  label: 'Days Left',
                  value: '$daysRemaining',
                  valueColor: daysRemaining <= 7
                      ? AppUIConstants.warning
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppUIConstants.spacingMd),
          const Divider(height: 1, color: AppUIConstants.divider),
          const SizedBox(height: AppUIConstants.spacingMd),
          _InfoRow(
            label: 'Valid Till',
            value: membershipInfo.validTillFormatted,
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: AppUIConstants.caption),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppUIConstants.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

/// Session Info Card - Shows member's assigned slot timing
class _SessionInfoCard extends StatelessWidget {
  const _SessionInfoCard({required this.membershipInfo});

  final StudentMembershipInfo membershipInfo;

  @override
  Widget build(BuildContext context) {
    // Use custom slot - primary way now
    final customSlot = membershipInfo.customSlot;
    final derivedSlot = customSlot != null
        ? (customSlot.startTimeOfDay.hour < 14 ? Slot.morning : Slot.evening)
        : membershipInfo.membership.slot;

    final slotName = membershipInfo.slotName;
    final sessionTiming = membershipInfo.sessionTiming;

    // Determine icon based on slot timing
    final isMorning =
        derivedSlot == Slot.morning ||
        (customSlot != null && customSlot.startTimeOfDay.hour < 14);

    return Container(
      padding: const EdgeInsets.all(AppUIConstants.spacingLg),
      decoration: AppUIConstants.cardDecoration,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppUIConstants.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
            ),
            child: Icon(
              isMorning ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined,
              color: AppUIConstants.accent,
              size: 24,
            ),
          ),
          const SizedBox(width: AppUIConstants.spacingLg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your Session', style: AppUIConstants.caption),
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

/// Attendance CTA
class _AttendanceCTA extends StatelessWidget {
  const _AttendanceCTA({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppUIConstants.spacingLg),
        decoration: BoxDecoration(
          color: AppUIConstants.primary,
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        ),
        child: Row(
          children: [
            Icon(Icons.insights_outlined, color: Colors.white, size: 22),
            const SizedBox(width: AppUIConstants.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'View Attendance',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    'History, stats & trends',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white.withValues(alpha: 0.7),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppUIConstants.caption),
        const SizedBox(height: 4),
        Text(value, style: AppUIConstants.bodyLg),
      ],
    );
  }
}

/// Photo carousel widget for library photos with fullscreen viewer.
class _LibraryPhotosCarousel extends StatefulWidget {
  const _LibraryPhotosCarousel({required this.photos});

  final List<String> photos;

  @override
  State<_LibraryPhotosCarousel> createState() => _LibraryPhotosCarouselState();
}

class _LibraryPhotosCarouselState extends State<_LibraryPhotosCarousel> {
  int _currentIndex = 0;

  void _openFullscreen(int index) {
    FullScreenImageViewer.open(
      context,
      images: widget.photos,
      initialIndex: index,
      heroTagPrefix: 'pg_photo',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        boxShadow: [AppUIConstants.shadowSm],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(AppUIConstants.spacingLg),
            child: Row(
              children: [
                Icon(
                  Icons.photo_library_outlined,
                  color: AppUIConstants.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text('PG Photos', style: AppUIConstants.headingSm),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppUIConstants.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                      AppUIConstants.radiusFull,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.touch_app_outlined,
                        size: 12,
                        color: AppUIConstants.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Tap to view',
                        style: TextStyle(
                          color: AppUIConstants.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Carousel
          CarouselSlider.builder(
            itemCount: widget.photos.length,
            itemBuilder: (context, index, realIndex) {
              return GestureDetector(
                onTap: () => _openFullscreen(index),
                child: Hero(
                  // Use URL as tag — unique per photo, avoids
                  // duplicate-tag crash when carousel loops.
                  tag: 'pg_photo_${widget.photos[index]}',
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        AppUIConstants.radiusSm,
                      ),
                      color: AppUIConstants.divider,
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppUIConstants.radiusSm,
                          ),
                          child: Image.network(
                            widget.photos[index],
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: AppUIConstants.divider,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value:
                                        loadingProgress.expectedTotalBytes !=
                                            null
                                        ? loadingProgress
                                                  .cumulativeBytesLoaded /
                                              loadingProgress
                                                  .expectedTotalBytes!
                                        : null,
                                    color: AppUIConstants.primary,
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: AppUIConstants.divider,
                                child: const Icon(
                                  Icons.broken_image,
                                  color: AppUIConstants.textTertiary,
                                  size: 48,
                                ),
                              );
                            },
                          ),
                        ),
                        // Zoom icon overlay
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(
                                AppUIConstants.radiusSm,
                              ),
                            ),
                            child: const Icon(
                              Icons.zoom_in_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            options: CarouselOptions(
              height: 250,
              viewportFraction: 0.9,
              enlargeCenterPage: true,
              autoPlay: widget.photos.length > 1,
              autoPlayInterval: const Duration(seconds: 4),
              autoPlayAnimationDuration: const Duration(milliseconds: 800),
              autoPlayCurve: Curves.fastOutSlowIn,
              onPageChanged: (index, reason) {
                setState(() => _currentIndex = index);
              },
            ),
          ),

          // Page indicator
          if (widget.photos.length > 1)
            Padding(
              padding: const EdgeInsets.only(
                top: AppUIConstants.spacingMd,
                bottom: AppUIConstants.spacingLg,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.photos.length,
                  (index) => Container(
                    width: index == _currentIndex ? 20 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: index == _currentIndex
                          ? AppUIConstants.primary
                          : AppUIConstants.divider,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: AppUIConstants.spacingLg),
        ],
      ),
    );
  }
}
