import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/router/app_router.dart';
import '../../../domain/entities/user.dart';
import '../../admin/screens/admin_intelligence_screen.dart';
import '../../admin/screens/admin_login_screen.dart';
import '../cubit/phone_auth_cubit.dart';
import '../cubit/phone_auth_state.dart';

/// Phone authentication screen with OTP verification.
class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  /// India country code - fixed prefix for all phone numbers.
  static const _countryCode = '+91';

  /// Counter for hidden admin login trigger.
  int _logoTapCount = 0;
  DateTime? _lastLogoTap;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<PhoneAuthCubit>().checkAuthStatus();
      }
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  /// Validates that phone number is exactly 10 digits.
  String? _validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your phone number';
    }
    if (value.length != 10) {
      return 'Phone number must be exactly 10 digits';
    }
    if (!RegExp(r'^\d{10}$').hasMatch(value)) {
      return 'Phone number must contain only digits';
    }
    return null;
  }

  /// Formats phone number with country code for Firebase.
  String _formatPhoneNumber(String rawNumber) {
    return '$_countryCode$rawNumber';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PG Sathi'),
        automaticallyImplyLeading: false,
      ),
      body: BlocConsumer<PhoneAuthCubit, PhoneAuthState>(
        listener: (context, state) {
          state.mapOrNull(
            error: (errorState) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    errorState.failure.message ?? 'An error occurred',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            },
            authenticated: (authState) {
              _navigateBasedOnRole(context, authState.user);
            },
            signedOut: (_) {
              // Stay on this screen after sign out
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Signed out successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
          );
        },
        builder: (context, state) {
          return state.map(
            initial: (s) => _buildPhoneInput(context, s.selectedRole),
            sendingOtp: (s) => _buildLoading('Sending OTP...'),
            otpSent: (s) => _buildOtpInput(context, s),
            verifyingOtp: (s) => _buildLoading('Verifying OTP...'),
            checkingAuth: (_) => _buildLoading('Checking authentication...'),
            authenticated: (s) => _buildLoading('Redirecting...'),
            signingOut: (_) => _buildLoading('Signing out...'),
            signedOut: (_) => _buildPhoneInput(context, UserRole.owner),
            error: (s) => _buildPhoneInput(context, s.selectedRole),
          );
        },
      ),
    );
  }

  Widget _buildLoading(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(message),
        ],
      ),
    );
  }

  Widget _buildPhoneInput(BuildContext context, UserRole selectedRole) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            GestureDetector(
              onTap: _handleLogoTap,
              child: CircleAvatar(
                radius: 48,
                backgroundColor: Colors.white,
                backgroundImage: const AssetImage(
                  'assets/images/app_logo.png',
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome to PG Sathi',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in to manage your PG, hostel, or tenant stay',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                hintText: '10-digit mobile number',
                prefixIcon: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.phone_outlined),
                      const SizedBox(width: 8),
                      Text(
                        _countryCode,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        height: 24,
                        width: 1,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        color: Colors.grey[400],
                      ),
                    ],
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 0),
              ),
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              validator: _validatePhoneNumber,
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
            const SizedBox(height: 24),
            Text(
              'Continue as:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _RoleCard(
                    role: UserRole.student,
                    icon: Icons.person_outline_rounded,
                    label: 'Tenant',
                    isSelected: selectedRole == UserRole.student,
                    onTap: () => context.read<PhoneAuthCubit>().setRole(
                      UserRole.student,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _RoleCard(
                    role: UserRole.owner,
                    icon: Icons.apartment_rounded,
                    label: 'PG Owner',
                    isSelected: selectedRole == UserRole.owner,
                    onTap: () =>
                        context.read<PhoneAuthCubit>().setRole(UserRole.owner),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                if (_formKey.currentState?.validate() ?? false) {
                  final rawPhone = _phoneController.text.trim();
                  final formattedPhone = _formatPhoneNumber(rawPhone);
                  context.read<PhoneAuthCubit>().sendOtp(formattedPhone);
                }
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text('Send OTP'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpInput(BuildContext context, PhoneAuthOtpSent state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Icon(
            Icons.apartment_rounded,
            size: 80,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Enter OTP',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the 6-digit code sent to\n${state.phoneNumber}',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          TextField(
            controller: _otpController,
            decoration: InputDecoration(
              labelText: 'OTP Code',
              hintText: '123456',
              hintStyle: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 24,
                letterSpacing: 8,
                fontWeight: FontWeight.normal,
              ),
              prefixIcon: const Icon(Icons.lock_outline),
            ),
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              letterSpacing: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              final otp = _otpController.text.trim();
              if (otp.length == 6) {
                context.read<PhoneAuthCubit>().verifyOtp(otp);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter 6-digit OTP')),
                );
              }
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text('Verify OTP'),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () {
                  _otpController.clear();
                  context.read<PhoneAuthCubit>().goBackToPhoneInput();
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Change Number'),
              ),
              TextButton(
                onPressed: () => context.read<PhoneAuthCubit>().resendOtp(),
                child: const Text('Resend OTP'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _navigateBasedOnRole(BuildContext context, User user) {
    switch (user.role) {
      case UserRole.admin:
        // Admin users go to admin intelligence screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminIntelligenceScreen()),
        );
        break;
      case UserRole.owner:
        context.goToOwnerDashboard();
        break;
      case UserRole.student:
        context.goToStudentHome(userId: user.id);
        break;
    }
  }

  /// Handles logo tap for hidden admin login.
  /// Tapping 7 times within 3 seconds opens admin login.
  void _handleLogoTap() {
    final now = DateTime.now();

    // Reset counter if more than 3 seconds since last tap
    if (_lastLogoTap != null && now.difference(_lastLogoTap!).inSeconds > 3) {
      _logoTapCount = 0;
    }

    _lastLogoTap = now;
    _logoTapCount++;

    if (_logoTapCount >= 7) {
      _logoTapCount = 0;
      _navigateToAdminLogin();
    }
  }

  /// Navigates to hidden admin login screen.
  void _navigateToAdminLogin() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AdminLoginScreen()));
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final UserRole role;
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.3)
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey[600],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
