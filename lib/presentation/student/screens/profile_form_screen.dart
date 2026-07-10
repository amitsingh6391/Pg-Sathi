// Radio deprecation: RadioGroup migration requires significant refactor
// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../domain/entities/user.dart';
import '../../core/app_ui_constants.dart';
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
  final _examController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    _nameController.text = widget.user.isProfileComplete ? widget.user.name : '';
    _examController.text = widget.user.examPreparingFor ?? '';
    _addressController.text = widget.user.address ?? '';
    
    final cubit = context.read<ProfileCubit>();
    cubit.loadUser(widget.user);
    
    if (widget.user.isProfileComplete) cubit.updateName(widget.user.name);
    if (widget.user.examPreparingFor != null) {
      cubit.updateExamPreparingFor(widget.user.examPreparingFor);
    }
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
        backgroundColor: isError ? Colors.red.shade600 : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        _showSnackBar('Failed to fetch location: ${e.toString()}', isError: true);
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
    _examController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.isInitialSetup ? 'Complete Your Profile' : 'Edit Profile'),
        backgroundColor: AppUIConstants.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: BlocConsumer<ProfileCubit, ProfileState>(
        listener: _handleStateChange,
        builder: (context, state) => _buildForm(context, state),
      ),
    );
  }

  void _handleStateChange(BuildContext context, ProfileState state) {
    if (state.isSuccess) {
      _showSnackBar('Profile updated successfully!');
      Navigator.of(context).pop(state.user);
    } else if (state.isError) {
      _showSnackBar(state.errorMessage ?? 'Failed to update profile', isError: true);
    }
  }

  Widget _buildForm(BuildContext context, ProfileState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            if (widget.isInitialSetup) _buildWelcomeHeader(context),
            _buildAvatarSection(context, state),
            const SizedBox(height: 24),
            _buildFormFields(context, state),
            const SizedBox(height: 32),
            _buildActionButtons(context, state),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader(BuildContext context) {
    return Column(
      children: [
        Text(
          'Let\'s set up your profile',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'This helps library owners identify you',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildAvatarSection(BuildContext context, ProfileState state) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: kIsWeb ? null : _pickProfilePicture,
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppUIConstants.primary,
                        AppUIConstants.primaryLight,
                      ],
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    backgroundImage: state.avatarUrl != null
                        ? NetworkImage(state.avatarUrl!)
                        : null,
                    child: state.avatarUrl == null
                        ? Text(
                            widget.user.initials,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppUIConstants.primary,
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
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppUIConstants.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (!kIsWeb) ...[
            const SizedBox(height: 12),
            Text(
              'Tap to change profile photo',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFormFields(BuildContext context, ProfileState state) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Personal Details',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _nameController,
            label: 'Full Name',
            hint: 'Enter your full name',
            icon: Icons.person_outline_rounded,
            enabled: !state.isSaving,
            required: true,
            onChanged: (value) => context.read<ProfileCubit>().updateName(value),
          ),
          const SizedBox(height: 20),
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
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.lock_rounded,
                size: 18,
                color: Color(0xFF10B981),
              ),
            ),
          ),
          // Student-only fields
          if (widget.user.role != UserRole.owner) ...[
            const SizedBox(height: 20),
            _buildTextField(
              controller: _examController,
              label: 'Exam Preparing For (Optional)',
              hint: 'e.g., UPSC, NEET, JEE',
              icon: Icons.school_outlined,
              enabled: !state.isSaving,
              onChanged: (value) => context.read<ProfileCubit>().updateExamPreparingFor(
                value.isEmpty ? null : value,
              ),
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _addressController,
              label: 'Address (Optional)',
              hint: 'Enter your address',
              icon: Icons.location_on_outlined,
              enabled: !state.isSaving && !_isLoadingLocation,
              maxLines: 2,
              onChanged: (value) => context.read<ProfileCubit>().updateAddress(
                value.isEmpty ? null : value,
              ),
              suffixIcon: _isLoadingLocation
                  ? Container(
                      margin: const EdgeInsets.all(12),
                      width: 20,
                      height: 20,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppUIConstants.primary,
                      ),
                    )
                  : IconButton(
                      onPressed: state.isSaving ? null : _fetchCurrentLocation,
                      icon: const Icon(
                        Icons.my_location_rounded,
                        color: AppUIConstants.primary,
                      ),
                      tooltip: 'Fetch current location',
                    ),
            ),
            const SizedBox(height: 20),
            _buildGenderSelection(context, state),
            const SizedBox(height: 20),
            _buildAccessCardSelection(context, state),
          ],
        ],
      ),
    );
  }

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
    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        helperStyle: TextStyle(color: Colors.grey.shade500),
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppUIConstants.primary,
            width: 2,
          ),
        ),
        filled: true,
        fillColor: enabled ? Colors.grey.shade50 : Colors.grey.shade100,
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

  Widget _buildGenderSelection(BuildContext context, ProfileState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gender (Optional)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: const Text('Male'),
                value: 'Male',
                groupValue: state.gender,
                onChanged: state.isSaving
                    ? null
                    : (value) => context.read<ProfileCubit>().updateGender(value),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: const Text('Female'),
                value: 'Female',
                groupValue: state.gender,
                onChanged: state.isSaving
                    ? null
                    : (value) => context.read<ProfileCubit>().updateGender(value),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAccessCardSelection(BuildContext context, ProfileState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Access Card Issued?',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: RadioListTile<bool>(
                title: const Text('Yes'),
                value: true,
                groupValue: state.isAccessCardIssued,
                onChanged: state.isSaving
                    ? null
                    : (value) => context
                        .read<ProfileCubit>()
                        .updateAccessCardIssued(value ?? false),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
            Expanded(
              child: RadioListTile<bool>(
                title: const Text('No'),
                value: false,
                groupValue: state.isAccessCardIssued,
                onChanged: state.isSaving
                    ? null
                    : (value) => context
                        .read<ProfileCubit>()
                        .updateAccessCardIssued(value ?? false),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, ProfileState state) {
    if (widget.isInitialSetup) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: state.isSaving ? null : _onSave,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: state.isSaving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Save Profile'),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: state.isSaving ? null : () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: state.isSaving ? null : _onSave,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: state.isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_rounded),
                      SizedBox(width: 8),
                      Text('Save Changes'),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  void _onSave() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<ProfileCubit>().saveProfile();
    }
  }
}
