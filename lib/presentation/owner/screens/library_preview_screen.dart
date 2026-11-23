import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/map_launcher.dart';
import '../../../core/utils/whatsapp_launcher.dart';
import '../../../domain/entities/library.dart';
import '../../core/app_ui_constants.dart';
import '../../core/widgets/premium_kit.dart';

/// Read-only preview of the PG listing as residents will see it.
/// Shows photos, address, amenities, bed availability and contact actions.
class LibraryPreviewScreen extends StatelessWidget {
  const LibraryPreviewScreen({
    super.key,
    required this.library,
    required this.availableSeats,
    required this.totalSeats,
  });

  final Library library;
  final int availableSeats;
  final int totalSeats;

  @override
  Widget build(BuildContext context) {
    final occupied = (totalSeats - availableSeats).clamp(0, totalSeats);
    final phone = library.ownerPhone;
    final hasPhone = phone != null && phone.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppUIConstants.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _PhotoHeader(library: library)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: PremiumStatTile(
                          icon: Icons.bed_outlined,
                          value: '$totalSeats',
                          label: 'Total beds',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: PremiumStatTile(
                          icon: Icons.event_available_outlined,
                          value: '$availableSeats',
                          label: 'Vacant',
                          color: availableSeats > 0
                              ? AppUIConstants.success
                              : AppUIConstants.error,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: PremiumStatTile(
                          icon: Icons.people_outline,
                          value: '$occupied',
                          label: 'Residents',
                          color: AppUIConstants.primaryLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _AvailabilityCard(
                    available: availableSeats,
                    total: totalSeats,
                  ),
                  const PremiumSectionHeader('Amenities'),
                  _AmenitiesCard(facilities: library.enabledFacilities),
                  if (library.ownerUpiId != null &&
                      library.ownerUpiId!.isNotEmpty) ...[
                    const PremiumSectionHeader('Rent & payments'),
                    const _InfoRowCard(
                      icon: Icons.account_balance_rounded,
                      title: 'Pay rent via UPI',
                      subtitle:
                          'Residents can pay directly with any UPI app, no gateway fees.',
                    ),
                  ],
                  const PremiumSectionHeader('Location'),
                  _AddressCard(library: library),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _ContactBar(
        library: library,
        phone: hasPhone ? phone.trim() : null,
      ),
    );
  }
}

// =============================================================================
// Photo carousel header
// =============================================================================

class _PhotoHeader extends StatefulWidget {
  const _PhotoHeader({required this.library});

  final Library library;

  @override
  State<_PhotoHeader> createState() => _PhotoHeaderState();
}

class _PhotoHeaderState extends State<_PhotoHeader> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = widget.library;
    final photos = library.photos;
    final topInset = MediaQuery.of(context).padding.top;

    return SizedBox(
      height: 340 + topInset * 0.4,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (photos.isEmpty)
            Container(
              decoration: const BoxDecoration(color: AppUIConstants.surface),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 44,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No photos added yet',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            PageView.builder(
              controller: _controller,
              itemCount: photos.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) => Image.network(
                photos[i],
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(color: AppUIConstants.surfaceMuted);
                },
                errorBuilder: (_, _, _) => Container(
                  color: AppUIConstants.surfaceMuted,
                  child: const Center(
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: AppUIConstants.textTertiary,
                      size: 36,
                    ),
                  ),
                ),
              ),
            ),
          // Gradient for legibility (ignores touches so the carousel swipes).
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.35, 1.0],
                  colors: [
                    Colors.black.withValues(alpha: 0.45),
                    Colors.transparent,
                    AppUIConstants.background,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: topInset + 8,
            left: 12,
            right: 12,
            child: Row(
              children: [
                _RoundButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppUIConstants.primaryLight,
                    borderRadius: BorderRadius.circular(
                      AppUIConstants.radiusFull,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.visibility_outlined,
                        size: 14,
                        color: Colors.white,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Resident preview',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 16,
            child: IgnorePointer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    library.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppUIConstants.headingLg.copyWith(fontSize: 26),
                  ),
                  if (library.area != null && library.area!.isNotEmpty) ...[
                    const SizedBox(height: 6),
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
                            library.area!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppUIConstants.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (photos.length > 1) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        for (var i = 0; i < photos.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.only(right: 6),
                            width: i == _page ? 22 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: i == _page
                                  ? AppUIConstants.primaryLight
                                  : Colors.white.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.4),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

// =============================================================================
// Bed availability
// =============================================================================

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({required this.available, required this.total});

  final int available;
  final int total;

  @override
  Widget build(BuildContext context) {
    final percentage = total > 0 ? (available / total).clamp(0.0, 1.0) : 0.0;
    final color = total == 0
        ? AppUIConstants.textSecondary
        : percentage > 0.5
        ? AppUIConstants.success
        : percentage > 0.2
        ? AppUIConstants.warning
        : AppUIConstants.error;

    return PremiumCard(
      glow: total > 0 ? color : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      total == 0
                          ? 'Beds not set up yet'
                          : available == 0
                          ? 'Fully occupied'
                          : '$available beds available',
                      style: AppUIConstants.headingMd.copyWith(color: color),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      total == 0
                          ? 'Add room types and beds to show availability'
                          : 'out of $total total beds',
                      style: AppUIConstants.bodySm,
                    ),
                  ],
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: percentage),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => SizedBox(
                  width: 56,
                  height: 56,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: v,
                        strokeWidth: 5,
                        backgroundColor: AppUIConstants.surfaceMuted,
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                      Center(
                        child: Text(
                          '${(v * 100).round()}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Amenities
// =============================================================================

class _AmenitiesCard extends StatelessWidget {
  const _AmenitiesCard({required this.facilities});

  final List<LibraryFacility> facilities;

  IconData _getIcon(LibraryFacility facility) {
    switch (facility) {
      case LibraryFacility.wifi:
        return Icons.wifi;
      case LibraryFacility.ac:
        return Icons.ac_unit;
      case LibraryFacility.powerBackup:
        return Icons.power;
      case LibraryFacility.washroom:
        return Icons.wc;
      case LibraryFacility.drinkingWater:
        return Icons.water_drop;
      case LibraryFacility.cctv:
        return Icons.videocam;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (facilities.isEmpty) {
      return const _InfoRowCard(
        icon: Icons.star_outline_rounded,
        title: 'No amenities listed',
        subtitle:
            'Edit your PG profile and switch on the amenities you provide.',
      );
    }

    return PremiumCard(
      child: Wrap(
        spacing: AppUIConstants.spacingSm,
        runSpacing: AppUIConstants.spacingSm,
        children: facilities.map((facility) {
          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppUIConstants.spacingMd,
              vertical: AppUIConstants.spacingSm,
            ),
            decoration: BoxDecoration(
              color: AppUIConstants.primarySoft,
              borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
              border: Border.all(
                color: AppUIConstants.primaryLight.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getIcon(facility),
                  size: 16,
                  color: AppUIConstants.primaryLight,
                ),
                const SizedBox(width: 6),
                Text(
                  facility.displayName,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppUIConstants.textPrimary,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _InfoRowCard extends StatelessWidget {
  const _InfoRowCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppUIConstants.primarySoft,
              borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
            ),
            child: Icon(icon, color: AppUIConstants.primaryLight, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppUIConstants.bodyLg),
                const SizedBox(height: 2),
                Text(subtitle, style: AppUIConstants.bodySm),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Address Card
// =============================================================================

Future<void> _openMaps(BuildContext context, Library library) async {
  final lat = library.latitude!;
  final lng = library.longitude!;
  try {
    final opened = await launchMapsAt(
      latitude: lat,
      longitude: lng,
      label: library.fullAddress,
    );
    if (!context.mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open Maps')));
    }
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not open Maps')));
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.library});

  final Library library;

  @override
  Widget build(BuildContext context) {
    final address = library.fullAddress;
    if (address == null || address.isEmpty) {
      return const _InfoRowCard(
        icon: Icons.location_off_outlined,
        title: 'No address added',
        subtitle: 'Edit your PG profile to add the address and location.',
      );
    }

    final hasCoords = library.latitude != null && library.longitude != null;
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppUIConstants.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  color: AppUIConstants.primaryLight,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(address, style: AppUIConstants.bodyMd)),
            ],
          ),
          if (hasCoords) ...[
            const SizedBox(height: AppUIConstants.spacingMd),
            Material(
              color: AppUIConstants.surfaceMuted,
              borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
              child: InkWell(
                onTap: () => _openMaps(context, library),
                borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppUIConstants.spacingMd,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.map_outlined,
                        color: AppUIConstants.primaryLight,
                        size: 24,
                      ),
                      const SizedBox(width: AppUIConstants.spacingMd),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Open in Maps', style: AppUIConstants.bodyLg),
                            SizedBox(height: 2),
                            Text(
                              'Apple Maps or Google Maps',
                              style: AppUIConstants.bodySm,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.open_in_new,
                        size: 18,
                        color: AppUIConstants.textTertiary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// Contact action bar
// =============================================================================

class _ContactBar extends StatelessWidget {
  const _ContactBar({required this.library, required this.phone});

  final Library library;
  final String? phone;

  Future<void> _call(BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: phone);
    var ok = false;
    try {
      ok = await launchUrl(uri);
    } catch (_) {}
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not start the call')));
    }
  }

  Future<void> _whatsApp(BuildContext context) async {
    var digits = phone!.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 10) digits = '91$digits';
    var ok = false;
    try {
      ok = await WhatsAppLauncher.launch(
        phone: digits,
        message:
            'Hi, I am interested in a bed at ${library.name}. Is one available?',
      );
    } catch (_) {}
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCoords = library.latitude != null && library.longitude != null;
    return Container(
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        border: Border(top: BorderSide(color: AppUIConstants.border)),
        boxShadow: [AppUIConstants.shadowLg],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: phone == null
              ? Row(
                  children: [
                    const Icon(
                      Icons.phone_disabled_outlined,
                      color: AppUIConstants.textTertiary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'No contact number on this PG yet',
                        style: AppUIConstants.bodySm,
                      ),
                    ),
                    if (hasCoords)
                      TextButton.icon(
                        onPressed: () => _openMaps(context, library),
                        icon: const Icon(Icons.directions_outlined, size: 18),
                        label: const Text('Directions'),
                      ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () => _call(context),
                          icon: const Icon(Icons.call_rounded, size: 20),
                          label: const Text('Call'),
                          style: _style(AppUIConstants.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () => _whatsApp(context),
                          icon: const Icon(Icons.chat_rounded, size: 20),
                          label: const Text('WhatsApp'),
                          style: _style(AppUIConstants.primaryLight),
                        ),
                      ),
                    ),
                    if (hasCoords) ...[
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 50,
                        width: 50,
                        child: OutlinedButton(
                          onPressed: () => _openMaps(context, library),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            foregroundColor: AppUIConstants.primaryLight,
                            side: BorderSide(color: AppUIConstants.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppUIConstants.radiusMd,
                              ),
                            ),
                          ),
                          child: const Icon(Icons.directions_outlined),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  ButtonStyle _style(Color color) => ElevatedButton.styleFrom(
    backgroundColor: color,
    foregroundColor: Colors.white,
    elevation: 0,
    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
    ),
  );
}
