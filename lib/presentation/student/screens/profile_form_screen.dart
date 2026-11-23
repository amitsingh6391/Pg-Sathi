import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../domain/entities/user.dart';
import '../../core/app_ui_constants.dart';
import '../../core/widgets/premium_kit.dart';
import '../cubit/profile_cubit.dart';
import '../cubit/profile_state.dart';

/// Unified form screen for both profile completion and editing.
/// Handles initial profile setup and subsequent updates.
class ProfileFormScreen extends StatefulWidget {
  const ProfileFormScreen({
    super.key,
    required this.user,
    this.isInitialSetup = false,
  });

  final User user;
  final bool isInitialSetup;

  @override
  State<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends State<ProfileFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    _nameController.text = widget.user.isProfileComplete
        ? widget.user.name
        : '';
    _addressController.text = widget.user.address ?? '';

    final cubit = context.read<ProfileCubit>();
    cubit.loadUser(widget.user);

    if (widget.user.isProfileComplete) cubit.updateName(widget.user.name);
    if (widget.user.address != null) cubit.updateAddress(widget.user.address);
    if (widget.user.gender != null) cubit.updateGender(widget.user.gender);
    cubit.updateAccessCardIssued(widget.user.isAccessCardIssued);
  }

  Future<void> _pickProfilePicture() async {
    if (kIsWeb) return; // Skip image picker on web for now

    final picker = ImagePicker();
    try {
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 800,
      );

      if (image != null && mounted) {
        final file = File(image.path);
        await context.read<ProfileCubit>().uploadProfilePicture(file);
        if (mounted) await context.read<ProfileCubit>().saveProfile();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to pick image: ${e.toString()}', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? AppUIConstants.error
            : AppUIConstants.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Future<void> _fetchCurrentLocation() async {
    if (kIsWeb) return;

    setState(() => _isLoadingLocation = true);

    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          _showSnackBar(
            'Location services are disabled. Please enable them.',
            isError: true,
          );
        }
        return;
      }

      // Check permission
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            _showSnackBar('Location permission denied', isError: true);
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showSnackBar(
            'Location permission permanently denied. Please enable from settings.',
            isError: true,
          );
        }
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

      if (placemarks.isNotEmpty && mounted) {
        final place = placemarks.first;

        // Build full address
        final fullAddress = [
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
          place.postalCode,
        ].where((s) => s != null && s.isNotEmpty).join(', ');

        setState(() {
          _addressController.text = fullAddress;
        });

        // Update cubit
        context.read<ProfileCubit>().updateAddress(fullAddress);
        _showSnackBar('Address fetched successfully!');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          'Failed to fetch location: ${e.toString()}',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProfileCubit, ProfileState>(
      listener: _handleStateChange,
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppUIConstants.background,
          body: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusScope.of(context).unfocus(),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.zero,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  _buildHero(context, state),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _StepHeader(
                          step: 1,
                          title: 'About you',
                          subtitle: 'How your PG will know you',
                        ),
                        PremiumCard(
                          child: Column(
                            children: [
                              _buildTextField(
                                controller: _nameController,
                                label: 'Full Name',
                                hint: 'Enter your full name',
                                icon: Icons.person_outline_rounded,
                                enabled: !state.isSaving,
                                required: true,
                                onChanged: (value) => context
                                    .read<ProfileCubit>()
                                    .updateName(value),
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                initialValue: widget.user.phone,
                                label: 'Phone Number',
                                icon: Icons.phone_rounded,
                                enabled: false,
                                helperText: 'Phone number cannot be changed',
                                suffixIcon: Container(
                                  margin: const EdgeInsets.all(8),
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppUIConstants.success.withValues(
                                      alpha: 0.14,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.lock_rounded,
                                    size: 18,
                                    color: AppUIConstants.success,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.user.role != UserRole.owner) ...[
                          const _StepHeader(
                            step: 2,
                            title: 'Stay details',
                            subtitle: 'Optional, but helps with check-in',
                          ),
                          PremiumCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTextField(
                                  controller: _addressController,
                                  label: 'Home Address (Optional)',
                                  hint: 'Enter your address',
                                  icon: Icons.location_on_outlined,
                                  enabled:
                                      !state.isSaving && !_isLoadingLocation,
                                  maxLines: 2,
                                  onChanged: (value) => context
                                      .read<ProfileCubit>()
                                      .updateAddress(
                                        value.isEmpty ? null : value,
                                      ),
                                  suffixIcon: _isLoadingLocation
                                      ? Container(
                                          margin: const EdgeInsets.all(12),
                                          width: 20,
                                          height: 20,
                                          child:
                                              const CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color:
                                                    AppUIConstants.primaryLight,
                                              ),
                                        )
                                      : IconButton(
                                          onPressed: state.isSaving
                                              ? null
                                              : _fetchCurrentLocation,
                                          icon: const Icon(
                                            Icons.my_location_rounded,
                                            color: AppUIConstants.primaryLight,
                                          ),
                                          tooltip: 'Fetch current location',
                                        ),
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  'Gender (Optional)',
                                  style: AppUIConstants.labelMd,
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    for (final g in const [
                                      'Male',
                                      'Female',
                                    ]) ...[
                                      Expanded(
                                        child: _ChoicePill(
                                          label: g,
                                          icon: g == 'Male'
                                              ? Icons.male_rounded
                                              : Icons.female_rounded,
                                          selected: state.gender == g,
                                          onTap: state.isSaving
                                              ? null
                                              : () => context
                                                    .read<ProfileCubit>()
                                                    .updateGender(g),
                                        ),
                                      ),
                                      if (g == 'Male')
                                        const SizedBox(width: 12),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 20),
                                _buildAccessCardToggle(context, state),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: _buildSaveBar(context, state),
        );
      },
    );
  }

  void _handleStateChange(BuildContext context, ProfileState state) {
    if (state.isSuccess) {
      _showSnackBar('Profile updated successfully!');
      Navigator.of(context).pop(state.user);
    } else if (state.isError) {
      _showSnackBar(
        state.errorMessage ?? 'Failed to update profile',
        isError: true,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Hero with avatar
  // ---------------------------------------------------------------------------

  Widget _buildHero(BuildContext context, ProfileState state) {
    final filled = [
      state.isNameValid,
      state.avatarUrl != null,
      if (widget.user.role != UserRole.owner) ...[
        (state.address ?? '').isNotEmpty,
        state.gender != null,
      ],
    ];
    final progress = filled.where((f) => f).length / filled.length;

    return PremiumHero(
      padding: const EdgeInsets.fromLTRB(12, 4, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppUIConstants.textPrimary,
                ),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  widget.isInitialSetup ? 'Welcome to your PG' : 'Edit Profile',
                  style: const TextStyle(
                    color: AppUIConstants.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: kIsWeb
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          _pickProfilePicture();
                        },
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              AppUIConstants.primaryLight,
                              AppUIConstants.primaryLight,
                            ],
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 44,
                          backgroundColor: AppUIConstants.surface,
                          backgroundImage: state.avatarUrl != null
                              ? NetworkImage(state.avatarUrl!)
                              : null,
                          child: state.avatarUrl == null
                              ? Text(
                                  widget.user.initials,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: AppUIConstants.primaryLight,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      if (!kIsWeb)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppUIConstants.primaryLight,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppUIConstants.background,
                                width: 3,
                              ),
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isInitialSetup
                            ? "Let's set up your profile"
                            : 'Keep your details fresh',
                        style: const TextStyle(
                          color: AppUIConstants.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        kIsWeb
                            ? 'This helps PG owners identify you'
                            : 'Tap the photo to change it',
                        style: const TextStyle(
                          color: AppUIConstants.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: progress),
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutCubic,
                        builder: (context, v, _) => ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: v,
                            minHeight: 6,
                            backgroundColor: AppUIConstants.surfaceMuted,
                            valueColor: const AlwaysStoppedAnimation(
                              AppUIConstants.primaryLight,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${(progress * 100).round()}% filled',
                        style: const TextStyle(
                          color: AppUIConstants.textTertiary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Fields
  // ---------------------------------------------------------------------------

  Widget _buildTextField({
    TextEditingController? controller,
    String? initialValue,
    required String label,
    String? hint,
    String? helperText,
    required IconData icon,
    bool enabled = true,
    bool required = false,
    int maxLines = 1,
    Widget? suffixIcon,
    void Function(String)? onChanged,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
          borderSide: BorderSide(color: color, width: width),
        );

    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      style: AppUIConstants.bodyLg.copyWith(
        color: enabled
            ? AppUIConstants.textPrimary
            : AppUIConstants.textSecondary,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppUIConstants.textSecondary),
        hintText: hint,
        hintStyle: const TextStyle(color: AppUIConstants.textTertiary),
        helperText: helperText,
        helperStyle: const TextStyle(color: AppUIConstants.textTertiary),
        prefixIcon: Icon(icon, color: AppUIConstants.textSecondary),
        suffixIcon: suffixIcon,
        border: border(AppUIConstants.border),
        enabledBorder: border(AppUIConstants.border),
        disabledBorder: border(AppUIConstants.divider),
        focusedBorder: border(AppUIConstants.primaryLight, 1.6),
        errorBorder: border(AppUIConstants.error),
        focusedErrorBorder: border(AppUIConstants.error, 1.6),
        filled: true,
        fillColor: AppUIConstants.surfaceMuted,
      ),
      textCapitalization: TextCapitalization.words,
      enabled: enabled,
      maxLines: maxLines,
      onChanged: onChanged,
      validator: required
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return '$label is required';
              }
              if (value.trim().length < 2) {
                return '$label must be at least 2 characters';
              }
              return null;
            }
          : null,
      autovalidateMode: required ? AutovalidateMode.onUserInteraction : null,
    );
  }

  Widget _buildAccessCardToggle(BuildContext context, ProfileState state) {
    final on = state.isAccessCardIssued;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: on ? AppUIConstants.primarySoft : AppUIConstants.surfaceMuted,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(
          color: on ? AppUIConstants.primaryLight : AppUIConstants.border,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        onTap: state.isSaving
            ? null
            : () {
                HapticFeedback.selectionClick();
                context.read<ProfileCubit>().updateAccessCardIssued(!on);
              },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            children: [
              Icon(
                Icons.credit_card_rounded,
                color: on
                    ? AppUIConstants.primaryLight
                    : AppUIConstants.textSecondary,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Access Card Issued?', style: AppUIConstants.bodyLg),
                    SizedBox(height: 2),
                    Text(
                      'Turn on if you already hold a PG entry card',
                      style: AppUIConstants.bodySm,
                    ),
                  ],
                ),
              ),
              Switch(
                value: on,
                onChanged: state.isSaving
                    ? null
                    : (v) => context
                          .read<ProfileCubit>()
                          .updateAccessCardIssued(v),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sticky save bar
  // ---------------------------------------------------------------------------

  Widget _buildSaveBar(BuildContext context, ProfileState state) {
    final saveChild = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: state.isSaving
          ? const SizedBox(
              key: ValueKey('saving'),
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Row(
              key: const ValueKey('idle'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_rounded, size: 20),
                const SizedBox(width: 8),
                Text(widget.isInitialSetup ? 'Save Profile' : 'Save Changes'),
              ],
            ),
    );

    return Container(
      decoration: const BoxDecoration(
        color: AppUIConstants.surface,
        border: Border(top: BorderSide(color: AppUIConstants.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              if (!widget.isInitialSetup) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: state.isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppUIConstants.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppUIConstants.radiusMd,
                        ),
                      ),
                      side: const BorderSide(color: AppUIConstants.border),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: state.isSaving ? null : _onSave,
                  style: AppUIConstants.accentButtonStyle.copyWith(
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                  child: saveChild,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onSave() {
    if (_formKey.currentState?.validate() ?? false) {
      HapticFeedback.mediumImpact();
      context.read<ProfileCubit>().saveProfile();
    }
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.step,
    required this.title,
    required this.subtitle,
  });

  final int step;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppUIConstants.surfaceMuted,
              shape: BoxShape.circle,
              border: Border.all(color: AppUIConstants.border),
            ),
            child: Text(
              '$step',
              style: const TextStyle(
                color: AppUIConstants.primaryLight,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppUIConstants.headingSm),
                Text(subtitle, style: AppUIConstants.bodySm),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: selected
            ? AppUIConstants.primarySoft
            : AppUIConstants.surfaceMuted,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(
          color: selected ? AppUIConstants.primaryLight : AppUIConstants.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected
                    ? AppUIConstants.primaryLight
                    : AppUIConstants.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? AppUIConstants.textPrimary
                      : AppUIConstants.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
