import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/di/injection_container.dart';
import '../../core/app_ui_constants.dart';
import '../../core/widgets/premium_kit.dart';
import '../../../domain/entities/library.dart';
import '../cubit/library_form_cubit.dart';
import '../cubit/library_form_state.dart';
import '../cubit/library_photos_cubit.dart';
import '../cubit/library_photos_state.dart';
import '../cubit/library_upi_qr_cubit.dart';
import '../cubit/library_upi_qr_state.dart';
import '../widgets/library_form/upi_qr_preview.dart';
import '../cubit/slot_management_cubit.dart';
import '../widgets/room_types/room_types_panel.dart';

/// Sectioned PG profile form for creating/updating the PG profile.
class LibraryFormScreen extends StatelessWidget {
  const LibraryFormScreen({
    super.key,
    required this.ownerId,
    this.ownerPhone,
    this.forceCreate = false,
    this.libraryId,
  });

  final String ownerId;
  final String? ownerPhone;

  /// When true, always starts a new PG (for multi-branch).
  final bool forceCreate;

  /// Specific branch to edit. When null, the owner's PG is loaded.
  final String? libraryId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<LibraryFormCubit>()
        ..loadLibrary(
          ownerId: ownerId,
          ownerPhone: ownerPhone,
          forceCreate: forceCreate,
          libraryId: libraryId,
        ),
      child: const _LibraryFormView(),
    );
  }
}

/// Step metadata (PG vocabulary) aligned with LibraryFormState sections.
class _StepInfo {
  const _StepInfo(this.label, this.icon);
  final String label;
  final IconData icon;
}

const List<_StepInfo> _steps = [
  _StepInfo('Basics', Icons.apartment_rounded),
  _StepInfo('Location', Icons.location_on_outlined),
  _StepInfo('Amenities', Icons.star_outline_rounded),
  _StepInfo('Payments', Icons.account_balance_rounded),
  _StepInfo('Room Types & Beds', Icons.bed_outlined),
  _StepInfo('Photos', Icons.photo_library_outlined),
];

void _toast(BuildContext context, String message, {required bool good}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppUIConstants.surfaceMuted,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
        side: BorderSide(
          color: (good ? AppUIConstants.success : AppUIConstants.error)
              .withValues(alpha: 0.5),
        ),
      ),
      content: Row(
        children: [
          Icon(
            good ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            color: good ? AppUIConstants.success : AppUIConstants.error,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppUIConstants.textPrimary),
            ),
          ),
        ],
      ),
    ),
  );
}

InputDecoration _fieldDecoration({
  required String label,
  String? hint,
  required IconData icon,
  String? helper,
}) {
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
    borderSide: BorderSide(color: c, width: w),
  );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helper,
    helperMaxLines: 2,
    prefixIcon: Icon(icon, color: AppUIConstants.textSecondary, size: 20),
    filled: true,
    fillColor: AppUIConstants.surfaceMuted,
    labelStyle: const TextStyle(color: AppUIConstants.textSecondary),
    hintStyle: const TextStyle(color: AppUIConstants.textTertiary),
    helperStyle: const TextStyle(color: AppUIConstants.textTertiary),
    border: border(AppUIConstants.border),
    enabledBorder: border(AppUIConstants.border),
    focusedBorder: border(AppUIConstants.primaryLight, 1.6),
  );
}

class _LibraryFormView extends StatelessWidget {
  const _LibraryFormView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LibraryFormCubit, LibraryFormState>(
      listener: (context, state) {
        if (state.isSuccess) {
          _toast(
            context,
            state.isEditing
                ? 'PG profile updated successfully!'
                : 'PG profile created successfully!',
            good: true,
          );
          Navigator.of(context).pop(true);
        } else if (state.isError && state.errorMessage != null) {
          _toast(context, state.errorMessage!, good: false);
        }
      },
      builder: (context, state) {
        if (state.isLoading) {
          return const Scaffold(
            backgroundColor: AppUIConstants.background,
            body: _FormSkeleton(),
          );
        }

        return Scaffold(
          backgroundColor: AppUIConstants.background,
          body: Column(
            children: [
              _ProgressHeader(state: state),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  switchInCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.06, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
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

/// Pulsing placeholder shown while the profile loads.
class _FormSkeleton extends StatefulWidget {
  const _FormSkeleton();

  @override
  State<_FormSkeleton> createState() => _FormSkeletonState();
}

class _FormSkeletonState extends State<_FormSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Widget _box(double h, {double? w, double r = AppUIConstants.radiusMd}) {
    return Container(
      height: h,
      width: w,
      decoration: BoxDecoration(
        color: AppUIConstants.surfaceMuted,
        borderRadius: BorderRadius.circular(r),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_pulse),
      child: Column(
        children: [
          PremiumHero(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _box(24, w: 160, r: 8),
                const SizedBox(height: 12),
                _box(8, r: 4),
                const SizedBox(height: 16),
                Row(
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      _box(34, w: 90, r: 20),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _box(88, r: AppUIConstants.radiusLg),
                const SizedBox(height: 16),
                _box(160, r: AppUIConstants.radiusLg),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressHeader extends StatefulWidget {
  const _ProgressHeader({required this.state});

  final LibraryFormState state;

  @override
  State<_ProgressHeader> createState() => _ProgressHeaderState();
}

class _ProgressHeaderState extends State<_ProgressHeader> {
  final List<GlobalKey> _chipKeys = List.generate(
    LibraryFormState.totalSections,
    (_) => GlobalKey(),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
  }

  @override
  void didUpdateWidget(covariant _ProgressHeader old) {
    super.didUpdateWidget(old);
    if (old.state.currentSection != widget.state.currentSection) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    }
  }

  void _reveal() {
    final ctx = _chipKeys[widget.state.currentSection].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        alignment: 0.5,
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final cubit = context.read<LibraryFormCubit>();
    final total = LibraryFormState.totalSections;

    return PremiumHero(
      padding: const EdgeInsets.fromLTRB(8, 4, 0, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppUIConstants.textPrimary,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.isEditing ? 'Edit PG Profile' : 'Set up your PG',
                      style: AppUIConstants.headingLg,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Step ${state.currentSection + 1} of $total  ·  '
                      '${_steps[state.currentSection.clamp(0, total - 1)].label}',
                      style: const TextStyle(
                        color: AppUIConstants.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (state.isSaving)
                const Padding(
                  padding: EdgeInsets.only(right: 20),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppUIConstants.primary,
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 20, 0),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: state.progress),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  backgroundColor: AppUIConstants.surfaceMuted,
                  valueColor: const AlwaysStoppedAnimation(
                    AppUIConstants.primaryLight,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 12, right: 20),
            child: Row(
              children: [
                for (var i = 0; i < total; i++)
                  Padding(
                    key: _chipKeys[i],
                    padding: const EdgeInsets.only(right: 8),
                    child: _StepChip(
                      info: _steps[i],
                      active: i == state.currentSection,
                      done: i < state.currentSection,
                      onTap: state.isSaving ? null : () => cubit.goToSection(i),
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

class _StepChip extends StatelessWidget {
  const _StepChip({
    required this.info,
    required this.active,
    required this.done,
    required this.onTap,
  });

  final _StepInfo info;
  final bool active;
  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = active
        ? AppUIConstants.primary
        : (done ? AppUIConstants.primarySoft : AppUIConstants.surfaceMuted);
    final fg = active
        ? Colors.white
        : (done ? AppUIConstants.primary : AppUIConstants.textSecondary);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              done ? Icons.check_circle_rounded : info.icon,
              size: 16,
              color: fg,
            ),
            const SizedBox(width: 6),
            Text(
              info.label,
              style: TextStyle(
                color: fg,
                fontSize: 12.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sticky bottom CTA bar (safe-area aware, shows saving state).
class _NavigationBar extends StatelessWidget {
  const _NavigationBar({required this.state});

  final LibraryFormState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LibraryFormCubit>();

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
          child: Row(
            children: [
              if (!state.isFirstSection) ...[
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: state.isSaving ? null : cubit.previousSection,
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Back'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppUIConstants.textPrimary,
                      side: BorderSide(color: AppUIConstants.border),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppUIConstants.radiusMd,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: state.isLastSection
                      ? ElevatedButton.icon(
                          onPressed: state.isSaving ? null : cubit.saveLibrary,
                          icon: state.isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_rounded),
                          label: Text(
                            state.isSaving ? 'Saving...' : 'Save PG profile',
                          ),
                          style: _ctaStyle(AppUIConstants.primaryLight),
                        )
                      : ElevatedButton.icon(
                          onPressed: state.isSaving ? null : cubit.nextSection,
                          icon: const Icon(Icons.arrow_forward_rounded),
                          iconAlignment: IconAlignment.end,
                          label: Text(
                            'Next: ${_steps[(state.currentSection + 1).clamp(0, _steps.length - 1)].label}',
                          ),
                          style: _ctaStyle(AppUIConstants.primary),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ButtonStyle _ctaStyle(Color color) => ElevatedButton.styleFrom(
    backgroundColor: color,
    foregroundColor: Colors.white,
    disabledBackgroundColor: color.withValues(alpha: 0.4),
    disabledForegroundColor: Colors.white70,
    elevation: 0,
    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
    ),
  );
}

// === SHARED SECTION CHROME ===

/// Scrollable section page: icon-well header card + body cards.
class _SectionScaffold extends StatelessWidget {
  const _SectionScaffold({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(icon: icon, title: title, subtitle: subtitle),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

/// Small hint banner (info / warning).
class _HintBanner extends StatelessWidget {
  const _HintBanner({
    required this.text,
    this.icon = Icons.lightbulb_outline_rounded,
    this.color = AppUIConstants.primaryLight,
  });

  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppUIConstants.textSecondary,
                fontSize: 12.5,
                height: 1.35,
              ),
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
    return _SectionScaffold(
      icon: Icons.info_outline,
      title: 'Basic Information',
      subtitle: 'Enter your PG or hostel name and basic details',
      children: [
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                initialValue: library?.name,
                style: const TextStyle(color: AppUIConstants.textPrimary),
                decoration: _fieldDecoration(
                  label: 'PG / Hostel Name *',
                  hint: 'e.g., Green Stay PG',
                  icon: Icons.apartment,
                ),
                textCapitalization: TextCapitalization.words,
                onChanged: context.read<LibraryFormCubit>().updateName,
              ),
              const SizedBox(height: 14),
              const _HintBanner(
                text:
                    'This is the name residents see in your listing. Use the '
                    'name printed on your board so people recognise it.',
              ),
            ],
          ),
        ),
      ],
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
  @override
  Widget build(BuildContext context) {
    return _SectionScaffold(
      icon: Icons.location_on_outlined,
      title: 'Location Details',
      subtitle: 'Help residents find your PG or hostel',
      children: [
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
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
                  foregroundColor: AppUIConstants.primaryLight,
                  side: BorderSide(
                    color: AppUIConstants.primaryLight.withValues(alpha: 0.5),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppUIConstants.radiusMd,
                    ),
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                child: _locationError == null
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: _HintBanner(
                          text: _locationError!,
                          icon: Icons.error_outline_rounded,
                          color: AppUIConstants.error,
                        ),
                      ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _areaController,
                style: const TextStyle(color: AppUIConstants.textPrimary),
                decoration: _fieldDecoration(
                  label: 'Area / Locality *',
                  hint: 'e.g., Andheri West',
                  icon: Icons.location_city,
                ),
                textCapitalization: TextCapitalization.words,
                onChanged: context.read<LibraryFormCubit>().updateArea,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                style: const TextStyle(color: AppUIConstants.textPrimary),
                decoration: _fieldDecoration(
                  label: 'Full Address *',
                  hint: 'Complete address with landmarks',
                  icon: Icons.home,
                  helper:
                      'Add a nearby landmark, metro or college to help '
                      'residents find you',
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                onChanged: context.read<LibraryFormCubit>().updateFullAddress,
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                child:
                    (widget.library?.latitude != null &&
                        widget.library?.longitude != null)
                    ? const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: _HintBanner(
                          text: 'Location coordinates saved',
                          icon: Icons.check_circle_rounded,
                          color: AppUIConstants.success,
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// === SECTION 3: FACILITIES ===

class _FacilitiesSection extends StatelessWidget {
  const _FacilitiesSection({super.key, required this.library});

  final Library? library;

  @override
  Widget build(BuildContext context) {
    final enabledCount = [
      library?.hasWifi ?? false,
      library?.hasAC ?? false,
      library?.hasPowerBackup ?? false,
      library?.hasWashroom ?? false,
      library?.hasDrinkingWater ?? false,
      library?.hasCCTV ?? false,
    ].where((e) => e).length;

    return _SectionScaffold(
      icon: Icons.star_outline,
      title: 'Amenities',
      subtitle: 'What does your PG offer to residents?',
      children: [
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Tap to switch on what you provide',
                      style: AppUIConstants.bodySm,
                    ),
                  ),
                  PremiumStatusPill(
                    '$enabledCount of 6 selected',
                    color: enabledCount == 0
                        ? AppUIConstants.textSecondary
                        : AppUIConstants.primaryLight,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _FacilityGrid(library: library),
            ],
          ),
        ),
      ],
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
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.3,
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
    final radius = BorderRadius.circular(AppUIConstants.radiusMd);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.read<LibraryFormCubit>().toggleFacility(facility),
        borderRadius: radius,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isEnabled
                ? AppUIConstants.primarySoft
                : AppUIConstants.surfaceMuted,
            borderRadius: radius,
            border: Border.all(
              color: isEnabled
                  ? AppUIConstants.primaryLight
                  : AppUIConstants.border,
              width: isEnabled ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isEnabled
                    ? AppUIConstants.primaryLight
                    : AppUIConstants.textTertiary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  facility.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isEnabled ? FontWeight.w700 : FontWeight.w500,
                    color: isEnabled
                        ? AppUIConstants.textPrimary
                        : AppUIConstants.textSecondary,
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isEnabled
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  key: ValueKey(isEnabled),
                  size: 20,
                  color: isEnabled
                      ? AppUIConstants.primaryLight
                      : AppUIConstants.disabled,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
    final upi = widget.library?.ownerUpiId;
    final showUpiWarning = upi != null && upi.isNotEmpty && !_isValidUpiId(upi);

    return _SectionScaffold(
      icon: Icons.account_balance_rounded,
      title: 'Payment Settings',
      subtitle: 'Configure UPI to collect rent directly',
      children: [
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _HintBanner(
                text:
                    'Add your UPI ID or QR code so residents can pay rent directly. No gateway fees.',
                icon: Icons.info_outline,
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: widget.library?.ownerUpiId,
                style: const TextStyle(color: AppUIConstants.textPrimary),
                decoration: _fieldDecoration(
                  label: 'UPI ID (Optional)',
                  hint: 'e.g., yourname@upi',
                  icon: Icons.account_balance_rounded,
                  helper: 'Tenants can pay rent directly to this UPI ID',
                ),
                keyboardType: TextInputType.emailAddress,
                onChanged: (value) {
                  context.read<LibraryFormCubit>().updateOwnerUpiId(
                    value.trim().isEmpty ? null : value.trim(),
                  );
                },
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                child: showUpiWarning
                    ? const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: _HintBanner(
                          text:
                              'UPI ID format seems incorrect. Expected format: name@upi',
                          icon: Icons.warning_amber_rounded,
                          color: AppUIConstants.warning,
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        BlocProvider(
          create: (_) => sl<LibraryUpiQrCubit>(),
          child: _UpiQrCard(library: widget.library),
        ),
        const PremiumSectionHeader('How rent via UPI works'),
        const PremiumCard(
          child: Column(
            children: [
              _UpiStepCard(
                step: '1',
                title: 'Tenant selects UPI',
                description:
                    'They see your UPI ID and QR code on the payment screen',
              ),
              _UpiStepCard(
                step: '2',
                title: 'Direct payment',
                description:
                    'Tenant pays via any UPI app (GPay, PhonePe, etc.)',
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
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _isValidUpiId(String upiId) {
    // Basic UPI ID validation: should contain @
    return upiId.contains('@') && upiId.indexOf('@') > 0;
  }
}

/// Upload / replace / remove the owner's UPI QR code (same flow as Library
/// Manager). While onboarding (PG not saved yet) the image is uploaded and
/// the URL kept in the form, then saved with the profile at the last step.
class _UpiQrCard extends StatefulWidget {
  const _UpiQrCard({required this.library});

  final Library? library;

  @override
  State<_UpiQrCard> createState() => _UpiQrCardState();
}

class _UpiQrCardState extends State<_UpiQrCard> {
  final ImagePicker _imagePicker = ImagePicker();

  bool get _persist => context.read<LibraryFormCubit>().state.isEditing;

  Future<void> _pickQrImage() async {
    final library = widget.library;
    if (library == null) return;
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 1080,
      );
      if (picked == null || !mounted) return;
      await context.read<LibraryUpiQrCubit>().uploadQr(
        library: library,
        qrImage: File(picked.path),
        persist: _persist,
      );
    } catch (e) {
      if (mounted) _toast(context, 'Failed to pick image: $e', good: false);
    }
  }

  Future<void> _removeQr() async {
    final library = widget.library;
    if (library == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove QR code'),
        content: const Text(
          'Are you sure you want to remove your UPI QR code?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppUIConstants.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<LibraryUpiQrCubit>().removeQr(
        library: library,
        persist: _persist,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LibraryUpiQrCubit, LibraryUpiQrState>(
      listener: (context, state) {
        if (state.isSuccess && state.library != null) {
          context.read<LibraryFormCubit>().updateOwnerUpiQrUrl(
            state.library!.ownerUpiQrUrl,
          );
          _toast(context, 'UPI QR code updated', good: true);
        } else if (state.isError && state.errorMessage != null) {
          _toast(context, state.errorMessage!, good: false);
        }
      },
      builder: (context, qrState) {
        final qrUrl = widget.library?.ownerUpiQrUrl;
        final hasQr = qrUrl != null && qrUrl.isNotEmpty;
        final isBusy = qrState.isUploading || qrState.isRemoving;

        return PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'UPI QR code (optional)',
                style: AppUIConstants.headingSm,
              ),
              const SizedBox(height: 4),
              const Text(
                'Residents can scan it to pay rent instantly',
                style: AppUIConstants.bodySm,
              ),
              const SizedBox(height: 12),
              if (hasQr)
                UpiQrPreview(
                  imageUrl: qrUrl,
                  isBusy: isBusy,
                  onReplace: _pickQrImage,
                  onRemove: _removeQr,
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isBusy ? null : _pickQrImage,
                    icon: isBusy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.qr_code_scanner_rounded, size: 18),
                    label: Text(isBusy ? 'Uploading...' : 'Add QR code image'),
                    style: AppUIConstants.secondaryButtonStyle,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _UpiStepCard extends StatelessWidget {
  const _UpiStepCard({
    required this.step,
    required this.title,
    required this.description,
    this.isLast = false,
  });

  final String step;
  final String title;
  final String description;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppUIConstants.primarySoft,
              borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
            ),
            child: Center(
              child: Text(
                step,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppUIConstants.primaryLight,
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
                Text(title, style: AppUIConstants.bodyLg),
                const SizedBox(height: 2),
                Text(description, style: AppUIConstants.bodySm),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Icon-well header shown at the top of every section.
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
            color: AppUIConstants.primarySoft,
            borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
            border: Border.all(
              color: AppUIConstants.primaryLight.withValues(alpha: 0.3),
            ),
          ),
          child: Icon(icon, color: AppUIConstants.primaryLight),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppUIConstants.headingMd),
              const SizedBox(height: 2),
              Text(subtitle, style: AppUIConstants.bodyMd),
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppUIConstants.primarySoft,
                ),
                child: const Icon(
                  Icons.bed_outlined,
                  size: 40,
                  color: AppUIConstants.primaryLight,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Save basic info first',
                style: AppUIConstants.headingMd,
              ),
              const SizedBox(height: 6),
              const Text(
                'Please save basic info first before adding room types and beds.',
                textAlign: TextAlign.center,
                style: AppUIConstants.bodyMd,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () =>
                    context.read<LibraryFormCubit>().goToSection(0),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Go to Basics'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppUIConstants.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppUIConstants.radiusMd,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Same editor as the Room Types screen. During first-time setup the PG
    // isn't saved yet, so the total-beds value goes into the form and is
    // saved with the profile (writing it directly would fail).
    final formCubit = context.read<LibraryFormCubit>();
    final isEditing = formCubit.state.isEditing;
    return BlocProvider(
      create: (_) => sl<SlotManagementCubit>()..loadSlots(library!.id),
      child: Builder(
        builder: (context) => RoomTypesPanel(
          initialTotalBeds: library!.totalSeatCapacity,
          onTotalBedsChanged: (total) {
            formCubit.updateTotalSeatCapacity(total);
            if (isEditing) {
              context.read<SlotManagementCubit>().updateTotalSeatCapacity(
                library!,
                total,
              );
            }
          },
          header: const Padding(
            padding: EdgeInsets.only(bottom: 20),
            child: Column(
              children: [
                _SectionTitle(
                  icon: Icons.bed_outlined,
                  title: 'Room Types & Beds',
                  subtitle: 'Add each room type with its rent and beds',
                ),
                SizedBox(height: 12),
                _HintBanner(
                  text:
                      'Set a bed prefix (like A or R1) so each bed gets a '
                      'clear number such as A01, A02.',
                ),
              ],
            ),
          ),
        ),
      ),
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

  /// The PG doc only exists once the profile is saved; until then photo
  /// changes stay in the form and are written with the profile.
  bool get _persist => context.read<LibraryFormCubit>().state.isEditing;

  /// Latest library (form state holds photos added since this widget built).
  Library get _currentLibrary =>
      context.read<LibraryFormCubit>().state.library ?? widget.library!;

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
        _toast(context, 'Maximum 5 photos allowed', good: false);
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
          _toast(
            context,
            'You can only add $allowedCount more photo(s)',
            good: false,
          );
        }
        return;
      }

      setState(() {
        _selectedFiles.addAll(files);
      });
    } catch (e) {
      if (mounted) {
        _toast(context, 'Failed to pick images: ${e.toString()}', good: false);
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
      library: _currentLibrary,
      photoFiles: _selectedFiles,
      persist: _persist,
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
            child: const Text(
              'Delete',
              style: TextStyle(color: AppUIConstants.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final cubit = context.read<LibraryPhotosCubit>();
      await cubit.deletePhoto(
        library: _currentLibrary,
        photoUrl: photoUrl,
        persist: _persist,
      );
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
          _toast(context, 'Photos updated successfully!', good: true);
        } else if (state.isError && state.errorMessage != null) {
          _toast(context, state.errorMessage!, good: false);
        }
      },
      child: BlocBuilder<LibraryPhotosCubit, LibraryPhotosState>(
        builder: (context, photosState) {
          final currentPhotos =
              photosState.library?.photos ?? widget.library?.photos ?? [];
          final totalPhotos = currentPhotos.length + _selectedFiles.length;
          final canAddMore = totalPhotos < 5;

          return _SectionScaffold(
            icon: Icons.photo_library_outlined,
            title: 'PG Photos',
            subtitle: 'Upload up to 5 photos of your PG or hostel',
            children: [
              const _HintBanner(
                text:
                    'Residents will see these photos when viewing your PG. '
                    'Bright photos of rooms, common areas and the entrance '
                    'work best.',
              ),
              const SizedBox(height: 16),
              if (totalPhotos == 0)
                PremiumCard(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppUIConstants.primarySoft,
                        ),
                        child: const Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 34,
                          color: AppUIConstants.primaryLight,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'No photos yet',
                        style: AppUIConstants.headingSm,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'A listing with photos gets far more enquiries.',
                        textAlign: TextAlign.center,
                        style: AppUIConstants.bodySm,
                      ),
                    ],
                  ),
                ),
              // Current photos grid
              if (currentPhotos.isNotEmpty)
                PremiumCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Current photos',
                              style: AppUIConstants.headingSm,
                            ),
                          ),
                          PremiumStatusPill(
                            '${currentPhotos.length}/5',
                            color: AppUIConstants.primaryLight,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
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
                    ],
                  ),
                ),

              // Selected files (pending upload)
              if (_selectedFiles.isNotEmpty) ...[
                const SizedBox(height: 16),
                PremiumCard(
                  glow: AppUIConstants.primaryLight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Ready to upload',
                              style: AppUIConstants.headingSm,
                            ),
                          ),
                          PremiumStatusPill(
                            '${_selectedFiles.length} new',
                            color: AppUIConstants.primaryLight,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
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
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: photosState.isUploading
                              ? null
                              : _uploadPhotos,
                          icon: photosState.isUploading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.cloud_upload),
                          label: Text(
                            photosState.isUploading
                                ? 'Uploading...'
                                : 'Upload Photos',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppUIConstants.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppUIConstants.primaryLight
                                .withValues(alpha: 0.4),
                            disabledForegroundColor: Colors.white70,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppUIConstants.radiusMd,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Add photos button
              if (canAddMore) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: Text(
                    currentPhotos.isEmpty
                        ? 'Add Photos (${5 - totalPhotos} remaining)'
                        : 'Add More Photos (${5 - totalPhotos} remaining)',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppUIConstants.primaryLight,
                    side: BorderSide(
                      color: AppUIConstants.primaryLight.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppUIConstants.radiusMd,
                      ),
                    ),
                  ),
                ),
              ],
            ],
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
          borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
          child: imageFile != null
              ? Image.file(imageFile!, fit: BoxFit.cover)
              : Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: AppUIConstants.surfaceMuted,
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppUIConstants.primaryLight,
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
                      color: AppUIConstants.surfaceMuted,
                      child: const Icon(
                        Icons.broken_image,
                        color: AppUIConstants.textTertiary,
                      ),
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
