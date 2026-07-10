import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/di/injection_container.dart';
import '../../core/app_ui_constants.dart';
import '../../../domain/entities/library.dart';
import '../cubit/library_form_cubit.dart';
import '../cubit/library_form_state.dart';
import '../cubit/library_photos_cubit.dart';
import '../cubit/library_photos_state.dart';
import '../cubit/slot_management_cubit.dart';
import 'slot_management_screen.dart';

/// Sectioned library form for creating/updating library profile.
class LibraryFormScreen extends StatelessWidget {
  const LibraryFormScreen({super.key, required this.ownerId, this.ownerPhone});

  final String ownerId;
  final String? ownerPhone;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<LibraryFormCubit>()
            ..loadLibrary(ownerId: ownerId, ownerPhone: ownerPhone),
      child: const _LibraryFormView(),
    );
  }
}

class _LibraryFormView extends StatelessWidget {
  const _LibraryFormView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LibraryFormCubit, LibraryFormState>(
      listener: (context, state) {
        if (state.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.isEditing
                    ? 'PG profile updated successfully!'
                    : 'PG profile created successfully!',
              ),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true);
        } else if (state.isError && state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state.isLoading) {
          return Scaffold(
            appBar: AppBar(title: const Text('PG Profile')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(state.isEditing ? 'Edit PG Profile' : 'Add PG Profile'),
            actions: [
              if (state.isSaving)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
          body: Column(
            children: [
              // Progress indicator
              _ProgressHeader(state: state),
              // Form sections
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildCurrentSection(context, state),
                ),
              ),
            ],
          ),
          bottomNavigationBar: _NavigationBar(state: state),
        );
      },
    );
  }

  Widget _buildCurrentSection(BuildContext context, LibraryFormState state) {
    switch (state.currentSection) {
      case 0:
        return _BasicInfoSection(
          key: const ValueKey(0),
          library: state.library,
        );
      case 1:
        return _LocationSection(key: const ValueKey(1), library: state.library);
      case 2:
        return _FacilitiesSection(
          key: const ValueKey(2),
          library: state.library,
        );
      case 3:
        return _PaymentSettingsSection(
          key: const ValueKey(3),
          library: state.library,
        );
      case 4:
        return _BedGroupsSection(
          key: const ValueKey(4),
          library: state.library,
        );
      case 5:
        return _LibraryPhotosSection(
          key: const ValueKey(5),
          library: state.library,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.state});

  final LibraryFormState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step ${state.currentSection + 1} of ${LibraryFormState.totalSections}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                state.currentSectionName,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: state.progress,
              minHeight: 6,
              backgroundColor: Colors.grey.shade300,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationBar extends StatelessWidget {
  const _NavigationBar({required this.state});

  final LibraryFormState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LibraryFormCubit>();

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            offset: const Offset(0, -2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          if (!state.isFirstSection)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: state.isSaving ? null : cubit.previousSection,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
              ),
            ),
          if (!state.isFirstSection) const SizedBox(width: 16),
          Expanded(
            flex: state.isFirstSection ? 1 : 1,
            child: state.isLastSection
                ? ElevatedButton.icon(
                    onPressed: state.isSaving ? null : cubit.saveLibrary,
                    icon: state.isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(state.isSaving ? 'Saving...' : 'Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: state.isSaving ? null : cubit.nextSection,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Next'),
                  ),
          ),
        ],
      ),
    );
  }
}

// === SECTION 1: BASIC INFO ===

class _BasicInfoSection extends StatelessWidget {
  const _BasicInfoSection({super.key, required this.library});

  final Library? library;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.info_outline,
            title: 'Basic Information',
            subtitle: 'Enter your PG or hostel name and basic details',
          ),
          const SizedBox(height: 24),
          TextFormField(
            initialValue: library?.name,
            decoration: const InputDecoration(
              labelText: 'PG / Hostel Name *',
              hintText: 'e.g., Green Stay PG',
              prefixIcon: Icon(Icons.apartment),
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
            onChanged: context.read<LibraryFormCubit>().updateName,
          ),
        ],
      ),
    );
  }
}

// === SECTION 2: LOCATION ===

class _LocationSection extends StatefulWidget {
  const _LocationSection({super.key, required this.library});

  final Library? library;

  @override
  State<_LocationSection> createState() => _LocationSectionState();
}

class _LocationSectionState extends State<_LocationSection> {
  bool _isLoadingLocation = false;
  String? _locationError;

  final _areaController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _areaController.text = widget.library?.area ?? '';
    _addressController.text = widget.library?.fullAddress ?? '';
  }

  @override
  void dispose() {
    _areaController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationError =
              'Location services are disabled. Please enable them.';
          _isLoadingLocation = false;
        });
        return;
      }

      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationError = 'Location permission denied';
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationError =
              'Location permissions are permanently denied. Please enable from settings.';
          _isLoadingLocation = false;
        });
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // Get address from coordinates
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;

        // Build area string
        final area = [
          place.subLocality,
          place.locality,
        ].where((s) => s != null && s.isNotEmpty).join(', ');

        // Build full address
        final fullAddress = [
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
          place.postalCode,
        ].where((s) => s != null && s.isNotEmpty).join(', ');

        // Update text controllers
        setState(() {
          _areaController.text = area;
          _addressController.text = fullAddress;
        });

        // Update cubit
        if (mounted) {
          final cubit = context.read<LibraryFormCubit>();
          cubit.updateArea(area);
          cubit.updateFullAddress(fullAddress);
          cubit.updateCoordinates(position.latitude, position.longitude);
        }
      }
    } catch (e) {
      setState(() {
        _locationError = 'Failed to fetch location: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.location_on_outlined,
            title: 'Location Details',
            subtitle: 'Help tenants find your PG or hostel',
          ),
          const SizedBox(height: 16),

          // Auto-detect location button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isLoadingLocation ? null : _fetchCurrentLocation,
              icon: _isLoadingLocation
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
              label: Text(
                _isLoadingLocation
                    ? 'Detecting location...'
                    : 'Auto-detect my location',
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          if (_locationError != null) ...[
            const SizedBox(height: 8),
            Text(
              _locationError!,
              style: TextStyle(color: Colors.red.shade700, fontSize: 12),
            ),
          ],

          const SizedBox(height: 24),
          TextFormField(
            controller: _areaController,
            decoration: const InputDecoration(
              labelText: 'Area / Locality *',
              hintText: 'e.g., Andheri West',
              prefixIcon: Icon(Icons.location_city),
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
            onChanged: context.read<LibraryFormCubit>().updateArea,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Full Address *',
              hintText: 'Complete address with landmarks',
              prefixIcon: Icon(Icons.home),
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            onChanged: context.read<LibraryFormCubit>().updateFullAddress,
          ),

          // Show coordinates if available
          if (widget.library?.latitude != null &&
              widget.library?.longitude != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Location coordinates saved',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// === SECTION 3: FACILITIES ===

class _FacilitiesSection extends StatelessWidget {
  const _FacilitiesSection({super.key, required this.library});

  final Library? library;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.star_outline,
            title: 'Facilities',
            subtitle: 'What amenities do you offer?',
          ),
          const SizedBox(height: 24),
          _FacilityGrid(library: library),
        ],
      ),
    );
  }
}

class _FacilityGrid extends StatelessWidget {
  const _FacilityGrid({required this.library});

  final Library? library;

  @override
  Widget build(BuildContext context) {
    final facilities = [
      _FacilityItem(
        facility: LibraryFacility.wifi,
        isEnabled: library?.hasWifi ?? false,
        icon: Icons.wifi,
      ),
      _FacilityItem(
        facility: LibraryFacility.ac,
        isEnabled: library?.hasAC ?? false,
        icon: Icons.ac_unit,
      ),
      _FacilityItem(
        facility: LibraryFacility.powerBackup,
        isEnabled: library?.hasPowerBackup ?? false,
        icon: Icons.power,
      ),
      _FacilityItem(
        facility: LibraryFacility.washroom,
        isEnabled: library?.hasWashroom ?? false,
        icon: Icons.wc,
      ),
      _FacilityItem(
        facility: LibraryFacility.drinkingWater,
        isEnabled: library?.hasDrinkingWater ?? false,
        icon: Icons.water_drop,
      ),
      _FacilityItem(
        facility: LibraryFacility.cctv,
        isEnabled: library?.hasCCTV ?? false,
        icon: Icons.videocam,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.5,
      ),
      itemCount: facilities.length,
      itemBuilder: (context, index) => facilities[index],
    );
  }
}

class _FacilityItem extends StatelessWidget {
  const _FacilityItem({
    required this.facility,
    required this.isEnabled,
    required this.icon,
  });

  final LibraryFacility facility;
  final bool isEnabled;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.read<LibraryFormCubit>().toggleFacility(facility),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isEnabled
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isEnabled
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
            width: isEnabled ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isEnabled
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                facility.displayName,
                style: TextStyle(
                  fontWeight: isEnabled ? FontWeight.bold : FontWeight.normal,
                  color: isEnabled
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.shade700,
                ),
              ),
            ),
            Icon(
              isEnabled ? Icons.check_circle : Icons.circle_outlined,
              color: isEnabled
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}

// === SHARED WIDGETS ===

// === SECTION 4: PAYMENT SETTINGS ===

class _PaymentSettingsSection extends StatefulWidget {
  const _PaymentSettingsSection({super.key, required this.library});

  final Library? library;

  @override
  State<_PaymentSettingsSection> createState() =>
      _PaymentSettingsSectionState();
}

class _PaymentSettingsSectionState extends State<_PaymentSettingsSection> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.account_balance_rounded,
            title: 'Payment Settings',
            subtitle: 'Configure UPI for direct payments',
          ),
          const SizedBox(height: 32),

          // UPI Info Card - Neutral design
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppUIConstants.divider,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppUIConstants.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.info_outline,
                    color: AppUIConstants.textSecondary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Add your UPI ID to let tenants pay rent directly. No gateway fees.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppUIConstants.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // UPI ID Input
          TextFormField(
            initialValue: widget.library?.ownerUpiId,
            decoration: InputDecoration(
              labelText: 'UPI ID (Optional)',
              hintText: 'e.g., yourname@upi',
              prefixIcon: const Icon(Icons.account_balance_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              helperText: 'Tenants can pay rent directly to this UPI ID',
              helperMaxLines: 2,
            ),
            keyboardType: TextInputType.emailAddress,
            onChanged: (value) {
              context.read<LibraryFormCubit>().updateOwnerUpiId(
                value.trim().isEmpty ? null : value.trim(),
              );
            },
          ),
          const SizedBox(height: 16),

          // UPI Validation hint
          if (widget.library?.ownerUpiId != null &&
              widget.library!.ownerUpiId!.isNotEmpty &&
              !_isValidUpiId(widget.library!.ownerUpiId!))
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.amber.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'UPI ID format seems incorrect. Expected format: name@upi',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          const SizedBox(height: 32),

          // How UPI works section
          Text(
            'How UPI Payments Work',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _UpiStepCard(
            step: '1',
            title: 'Tenant selects UPI',
            description: 'They see your UPI ID on the payment screen',
          ),
          _UpiStepCard(
            step: '2',
            title: 'Direct payment',
            description: 'Tenant pays via any UPI app (GPay, PhonePe, etc.)',
          ),
          _UpiStepCard(
            step: '3',
            title: 'Mark as paid',
            description: 'Tenant confirms payment with optional UTR',
          ),
          _UpiStepCard(
            step: '4',
            title: 'You approve',
            description: 'Verify and approve to activate the stay',
          ),
        ],
      ),
    );
  }

  bool _isValidUpiId(String upiId) {
    // Basic UPI ID validation: should contain @
    return upiId.contains('@') && upiId.indexOf('@') > 0;
  }
}

class _UpiStepCard extends StatelessWidget {
  const _UpiStepCard({
    required this.step,
    required this.title,
    required this.description,
  });

  final String step;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppUIConstants.divider,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                step,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppUIConstants.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppUIConstants.textPrimary,
                  ),
                ),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppUIConstants.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// === SECTION 5: BED GROUPS ===

class _BedGroupsSection extends StatelessWidget {
  const _BedGroupsSection({super.key, required this.library});

  final Library? library;

  @override
  Widget build(BuildContext context) {
    if (library == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Please save basic info first before adding bed groups.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: _SectionTitle(
            icon: Icons.bed_outlined,
            title: 'Bed Groups',
            subtitle: 'Set up your rooms, floors or bed categories',
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: BlocProvider(
            create: (_) => sl<SlotManagementCubit>(),
            // Hide the SlotManagementScreen's own AppBar since we
            // are already inside the LibraryFormScreen scaffold.
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: Theme(
                data: Theme.of(context).copyWith(
                  appBarTheme: const AppBarTheme(toolbarHeight: 0),
                ),
                child: SlotManagementScreen(library: library!),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// === SECTION 6: PG PHOTOS ===

class _LibraryPhotosSection extends StatelessWidget {
  const _LibraryPhotosSection({super.key, required this.library});

  final Library? library;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<LibraryPhotosCubit>(),
      child: _LibraryPhotosSectionView(library: library),
    );
  }
}

class _LibraryPhotosSectionView extends StatefulWidget {
  const _LibraryPhotosSectionView({required this.library});

  final Library? library;

  @override
  State<_LibraryPhotosSectionView> createState() =>
      _LibraryPhotosSectionViewState();
}

class _LibraryPhotosSectionViewState extends State<_LibraryPhotosSectionView> {
  final ImagePicker _imagePicker = ImagePicker();
  final List<File> _selectedFiles = [];

  @override
  void initState() {
    super.initState();
  }

  Future<void> _pickImages() async {
    if (widget.library == null) return;

    final currentPhotos = widget.library!.photos;
    final remainingSlots = 5 - currentPhotos.length - _selectedFiles.length;

    if (remainingSlots <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maximum 5 photos allowed'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final pickedFiles = await _imagePicker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1920,
      );

      if (pickedFiles.isEmpty) return;

      final files = pickedFiles.map((file) => File(file.path)).toList();
      final totalAfterPick =
          currentPhotos.length + _selectedFiles.length + files.length;

      if (totalAfterPick > 5) {
        final allowedCount = 5 - currentPhotos.length - _selectedFiles.length;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('You can only add $allowedCount more photo(s)'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      setState(() {
        _selectedFiles.addAll(files);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick images: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeSelectedFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Future<void> _uploadPhotos() async {
    if (widget.library == null || _selectedFiles.isEmpty) return;

    final cubit = context.read<LibraryPhotosCubit>();
    await cubit.uploadPhotos(
      library: widget.library!,
      photoFiles: _selectedFiles,
    );
  }

  Future<void> _deletePhoto(String photoUrl) async {
    if (widget.library == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text('Are you sure you want to delete this photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final cubit = context.read<LibraryPhotosCubit>();
      await cubit.deletePhoto(library: widget.library!, photoUrl: photoUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LibraryPhotosCubit, LibraryPhotosState>(
      listener: (context, state) {
        if (state.isSuccess && state.library != null) {
          // Update the form cubit with the new library
          context.read<LibraryFormCubit>().syncLibraryState(state.library!);
          setState(() {
            _selectedFiles.clear();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photos updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (state.isError && state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: BlocBuilder<LibraryPhotosCubit, LibraryPhotosState>(
        builder: (context, photosState) {
          final currentPhotos =
              photosState.library?.photos ?? widget.library?.photos ?? [];
          final totalPhotos = currentPhotos.length + _selectedFiles.length;
          final canAddMore = totalPhotos < 5;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle(
                  icon: Icons.photo_library_outlined,
                  title: 'PG Photos',
                  subtitle: 'Upload up to 5 photos of your PG or hostel',
                ),
                const SizedBox(height: 24),

                // Info card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppUIConstants.divider,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppUIConstants.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tenants will see these photos when viewing your PG',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppUIConstants.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Current photos grid
                if (currentPhotos.isNotEmpty) ...[
                  Text(
                    'Current Photos (${currentPhotos.length}/5)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1,
                        ),
                    itemCount: currentPhotos.length,
                    itemBuilder: (context, index) {
                      return _PhotoThumbnail(
                        imageUrl: currentPhotos[index],
                        onDelete: () => _deletePhoto(currentPhotos[index]),
                        isDeleting: photosState.isDeleting,
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],

                // Selected files (pending upload)
                if (_selectedFiles.isNotEmpty) ...[
                  Text(
                    'New Photos (${_selectedFiles.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1,
                        ),
                    itemCount: _selectedFiles.length,
                    itemBuilder: (context, index) {
                      return _PhotoThumbnail(
                        imageFile: _selectedFiles[index],
                        onDelete: () => _removeSelectedFile(index),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: photosState.isUploading ? null : _uploadPhotos,
                      icon: photosState.isUploading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_upload),
                      label: Text(
                        photosState.isUploading
                            ? 'Uploading...'
                            : 'Upload Photos',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Add photos button
                if (canAddMore)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _pickImages,
                      icon: const Icon(Icons.add_photo_alternate),
                      label: Text(
                        currentPhotos.isEmpty
                            ? 'Add Photos (${5 - totalPhotos} remaining)'
                            : 'Add More Photos (${5 - totalPhotos} remaining)',
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  const _PhotoThumbnail({
    this.imageUrl,
    this.imageFile,
    required this.onDelete,
    this.isDeleting = false,
  }) : assert(imageUrl != null || imageFile != null);

  final String? imageUrl;
  final File? imageFile;
  final VoidCallback onDelete;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: imageFile != null
              ? Image.file(imageFile!, fit: BoxFit.cover)
              : Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.grey.shade200,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    );
                  },
                ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: Material(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: isDeleting ? null : onDelete,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: isDeleting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
